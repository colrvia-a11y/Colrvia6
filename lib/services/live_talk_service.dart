import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:color_canvas/utils/permissions.dart';
import 'package:color_canvas/services/errors.dart';
import 'package:color_canvas/services/live_talk_service_ws.dart';
import 'package:color_canvas/services/live_talk_types.dart';
import 'package:color_canvas/services/live_talk_config.dart';

/// LiveTalkService connects to OpenAI Realtime over WebRTC using an ephemeral key
/// minted by your token endpoint so the client never sees OPENAI_API_KEY.
class LiveTalkService {
  LiveTalkService._();
  static final LiveTalkService instance = LiveTalkService._();

  final ValueNotifier<String> mode = ValueNotifier<String>('webrtc');
  final ValueNotifier<LiveTalkConnectionState> connectionState =
      ValueNotifier<LiveTalkConnectionState>(LiveTalkConnectionState.disconnected);
  final ValueNotifier<bool> assistantSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> reconnecting = ValueNotifier<bool>(false);
  final ValueNotifier<LiveTalkError?> lastError = ValueNotifier<LiveTalkError?>(null);
  final StreamController<String> partialText = StreamController<String>.broadcast();
  final StreamController<String> finalText = StreamController<String>.broadcast();
  final StreamController<String> userUtterance = StreamController<String>.broadcast();

  RTCPeerConnection? _pc;
  MediaStream? _mic;
  RTCDataChannel? _dc;
  String _accumulator = '';
  String? _ephemeralKey;
  String? _model;
  String? _voice;
  DateTime? _startedAt;
  String? _sessionDocId; // For immediate tool-call saves
  // Remember last successful/attempted connect args for retry
  Uri? _lastTokenEndpoint;
  String? _lastModel;
  String? _lastVoice;
  String? _lastPersona;
  Map<String, dynamic>? _lastContext;

  // Audio output renderer for remote audio track
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _rendererInit = false;

  Future<void> _ensureRenderer() async {
    if (!_rendererInit) {
      await remoteRenderer.initialize();
      _rendererInit = true;
    }
  }

  /// Connect to OpenAI Realtime using an ephemeral session from [tokenEndpoint].
  /// tokenEndpoint should point to your callable/gateway that returns the JSON
  /// from POST https://api.openai.com/v1/realtime/sessions (containing client_secret.value).
  Future<void> connect({
    required Uri tokenEndpoint,
    String model = 'gpt-realtime-nano',
    String voice = 'alloy',
    String? persona,
    Map<String, dynamic>? context,
    String? sessionId,
  }) async {
    lastError.value = null;
    reconnecting.value = false;
    connectionState.value = LiveTalkConnectionState.connecting;
    try {
      _model = model;
      _voice = voice;
      _startedAt = DateTime.now();
      _lastTokenEndpoint = tokenEndpoint;
      _lastModel = model;
      _lastVoice = voice;
      _lastPersona = persona;
      _lastContext = context;
      // 1) Mic permission and capture
      final ok = await ensureMicPermission();
      if (!ok) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.micPermission);
        throw Exception('Microphone permission denied');
      }
      final mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };
      _mic = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      await _ensureRenderer();

      // 2) Get ephemeral session from token endpoint (callable/HTTPS)
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.notSignedIn);
        throw Exception('Not signed in');
      }
      final sessionIdLocal = sessionId ?? const Uuid().v4();
      final tok = await _issueEphemeralViaEndpoint(
        tokenEndpoint: tokenEndpoint,
        idToken: idToken,
        model: model,
        voice: voice,
        sessionId: sessionIdLocal,
      );
      _ephemeralKey = (tok['client_secret']?['value']) as String?;
      if (_ephemeralKey == null || _ephemeralKey!.isEmpty) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.invalidToken);
        throw Exception('Invalid token response: missing client_secret.value');
      }

      // 3) Create RTCPeerConnection
      final pcConfig = <String, dynamic>{
        'sdpSemantics': 'unified-plan',
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };
      _pc = await createPeerConnection(pcConfig);

      if (_mic != null) {
        for (final t in _mic!.getTracks()) {
          await _pc!.addTrack(t, _mic!);
        }
      }

      _pc!.onTrack = (RTCTrackEvent ev) async {
        if (ev.track.kind == 'audio' && ev.streams.isNotEmpty) {
          remoteRenderer.srcObject = ev.streams.first;
        }
      };

      // Data channel for events
      _dc = await _pc!.createDataChannel('oai-events', RTCDataChannelInit()..ordered = true);
      _dc!.onMessage = _onEventMessage;

      final offer = await _pc!.createOffer({});
      await _pc!.setLocalDescription(offer);

      final answerUrl = LiveTalkConfig.webrtcAnswerUrl(model: model);
      debugPrint('LiveTalkService: dialing WebRTC answer URL: $answerUrl');
      final answerResp = await http
          .post(
        answerUrl,
        headers: {
          'Authorization': 'Bearer $_ephemeralKey',
          'Content-Type': 'application/sdp',
          'OpenAI-Beta': 'realtime=v1',
        },
        body: offer.sdp,
      )
          .timeout(const Duration(seconds: 15));
      if (answerResp.statusCode < 200 || answerResp.statusCode >= 300) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.webrtcFailure, details: answerResp.body);
        throw Exception('OpenAI answer error: ${answerResp.statusCode} ${answerResp.body}');
      }
      try {
        await _pc!
            .setRemoteDescription(RTCSessionDescription(answerResp.body, 'answer'))
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        lastError.value = LiveTalkError(LiveTalkErrorCode.negotiationTimeout);
        rethrow;
      }

      // Send session.update to set persona/instructions + server VAD
      final instructions = _buildInstructions(persona: persona, context: context);
      final sessionUpdate = {
        'type': 'session.update',
        'session': {
          'instructions': instructions,
          'turn_detection': {'type': 'server_vad'},
        }
      };
      _dc!.send(RTCDataChannelMessage(jsonEncode(sessionUpdate)));

      connectionState.value = LiveTalkConnectionState.connected;
    } catch (e, st) {
      debugPrint('LiveTalkService WebRTC connect failed (${e.runtimeType}): $e\n$st');
      debugPrint('LiveTalkService: attempting WS fallback');
      // Mark webrtc failure unless specified already
      lastError.value = lastError.value ?? LiveTalkError(LiveTalkErrorCode.webrtcFailure);
      // Fallback to WS implementation
      try {
        final ws = _LiveTalkServiceWsBridge(this);
        await ws.connect(
          tokenEndpoint: tokenEndpoint,
          model: model,
          voice: voice,
          persona: persona,
          context: context,
        );
        mode.value = 'ws-fallback';
        connectionState.value = LiveTalkConnectionState.connected;
      } catch (e2, st2) {
        debugPrint('WS fallback failed: $e2\n$st2');
        connectionState.value = LiveTalkConnectionState.error;
        if (e2 is TimeoutException) {
          lastError.value = LiveTalkError(LiveTalkErrorCode.network);
        } else {
          lastError.value = lastError.value ?? LiveTalkError(LiveTalkErrorCode.unknown);
        }
        rethrow;
      }
    }
  }

  // Issues the ephemeral token by either calling a direct HTTPS gateway or a Firebase Callable.
  Future<Map<String, dynamic>> _issueEphemeralViaEndpoint({
    required Uri tokenEndpoint,
    required String idToken,
    required String model,
    required String voice,
    required String sessionId,
  }) async {
    // If pointing at Cloud Functions default domain, call via Firebase Functions SDK (callable)
    if (tokenEndpoint.host.endsWith('cloudfunctions.net')) {
      final hostParts = tokenEndpoint.host.split('-');
      final region = hostParts.isNotEmpty ? hostParts.first : 'us-central1';
      final fnName = tokenEndpoint.pathSegments.isNotEmpty
          ? tokenEndpoint.pathSegments.last
          : 'issueVoiceGatewayToken';
      final functions = FirebaseFunctions.instanceFor(region: region);
      final callable = functions.httpsCallable(fnName);
      final resp = await callable.call({
        'sessionId': sessionId,
        'model': model,
        'voice': voice,
      }).timeout(const Duration(seconds: 12));
      final data = resp.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception('Invalid token response payload');
    }

    // Otherwise, call a generic HTTPS endpoint with Bearer Firebase ID token
    final resp = await http
        .post(
      tokenEndpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'sessionId': sessionId,
        'model': model,
        'voice': voice,
      }))
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      lastError.value = LiveTalkError(LiveTalkErrorCode.tokenEndpoint, details: resp.body);
      throw Exception('Token endpoint error: ${resp.statusCode} ${resp.body}');
    }
    final tok = jsonDecode(resp.body) as Map<String, dynamic>;
    return tok;
  }

  void _onEventMessage(RTCDataChannelMessage msg) {
    try {
      final m = jsonDecode(msg.text) as Map<String, dynamic>;
      final type = m['type'] as String?;
      if (type == null) return;

      if (type == 'response.delta') {
        assistantSpeaking.value = true;
        final delta = m['delta'] as Map<String, dynamic>?;
        final text = (delta?['text'] ?? delta?['output_text'] ?? delta?['content'] ?? '') as String?;
        if (text != null && text.isNotEmpty) {
          _accumulator += text;
          partialText.add(_accumulator);
        }
      } else if (type == 'response.completed') {
        if (_accumulator.isNotEmpty) finalText.add(_accumulator);
        _accumulator = '';
        partialText.add('');
        assistantSpeaking.value = false;
      } else if (type == 'response.output_tool_call') {
        // Tool call with arguments
        final name = (m['name'] as String?) ?? (m['tool_name'] as String?) ?? '';
        dynamic args = m['arguments'];
        if (args is String) {
          try { args = jsonDecode(args); } catch (_) {}
        }
        final Map<String, dynamic> a = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        if (name == 'save_answer') {
          _handleSaveAnswer(a);
        } else if (name == 'next_prompt') {
          _handleNextPrompt(a);
        }
      }
    } catch (_) {}
  }

  Future<DocumentReference<Map<String, dynamic>>> _ensureSessionRef() async {
    if (_sessionDocId != null) {
      return FirebaseFirestore.instance
          .collection('interviewSessions')
          .doc(_sessionDocId!);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final started = _startedAt ?? DateTime.now();
    final DocumentReference<Map<String, dynamic>> doc =
        FirebaseFirestore.instance.collection('interviewSessions').doc();
    await doc.set({
      'userId': uid,
      'startedAt': Timestamp.fromDate(started),
      'model': _model ?? 'gpt-realtime-nano',
      'voice': _voice ?? 'alloy',
      'createdAt': FieldValue.serverTimestamp(),
      'mode': 'realtime',
      'status': 'active',
    }, SetOptions(merge: true));
    _sessionDocId = doc.id;
    return doc;
  }

  Future<void> _handleSaveAnswer(Map<String, dynamic> args) async {
    try {
      final questionId = (args['questionId'] as String?) ?? (args['id'] as String?) ?? '';
      final text = (args['text'] as String?) ?? '';
      if (text.trim().isEmpty) return;
      final ref = await _ensureSessionRef();
      await ref.collection('turns').add({
        'role': 'user',
        'text': text.trim(),
        'questionId': questionId,
        'ts': Timestamp.now(),
      });
      await ref.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _handleNextPrompt(Map<String, dynamic> args) {
    // Minimal implementation: send a light session.update to nudge model
    // We don't store a full history here; include a simple hint if provided
    final currentCtx = <String, dynamic>{
      if (args['hint'] is String) 'hint': args['hint'],
    };
    final instructions = _buildInstructions(persona: null, context: currentCtx);
    final update = {
      'type': 'session.update',
      'session': {
        'instructions': instructions,
        'turn_detection': {'type': 'server_vad'},
      }
    };
    try {
      _dc?.send(RTCDataChannelMessage(jsonEncode(update)));
    } catch (_) {}
  }

  String _buildInstructions({String? persona, Map<String, dynamic>? context}) {
    final base = 'You are Via, a warm, concise paint consultant. '
        'Ask one question at a time. Keep replies < 8 seconds. '
        'If user goes off-topic, gently steer back.';
    final buf = StringBuffer(base);
    if (persona != null && persona.trim().isNotEmpty) {
      buf.writeln('\nPersona: ${persona.trim()}');
    }
    if (context != null && context.isNotEmpty) {
      buf.writeln('\nContext:');
      var i = 0;
      for (final entry in context.entries) {
        if (i++ >= 6) break;
        buf.writeln('- ${entry.key}: ${entry.value}');
      }
    }
    return buf.toString();
  }

  // Legacy signature preserved for API stability; recommend using connect(tokenEndpoint: ...)
  Future<void> connectLegacy({required String sessionId, required Uri gatewayWss}) async {
    throw UnimplementedError('Use connect(tokenEndpoint: ..., model: ...)');
  }

  /// Create a server-tracked talk session document via Cloud Functions.
  /// Returns the created sessionId.
  Future<String> createSession({Map<String, dynamic>? answers, DateTime? when}) async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final callable = functions.httpsCallable('createTalkSession');
    final data = <String, dynamic>{
      if (answers != null) 'answers': answers,
      if (when != null) 'scheduledAt': when.toIso8601String(),
    };
    final resp = await callable.call(data);
    final m = Map<String, dynamic>.from(resp.data as Map);
    final id = m['sessionId'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('createTalkSession returned no sessionId');
    }
    return id;
  }

  Future<void> disconnect() async {
    try { await _dc?.close(); } catch (_) {}
    try { await _pc?.close(); } catch (_) {}
    try {
      final tracks = _mic?.getTracks() ?? const <MediaStreamTrack>[];
      for (final t in tracks) { try { await t.stop(); } catch (_) {} }
    } catch (_) {}
    try { await _mic?.dispose(); } catch (_) {}
    _dc = null; _pc = null; _mic = null; _accumulator = ''; _ephemeralKey = null;
    assistantSpeaking.value = false;
    muted.value = false;
    reconnecting.value = false;
    connectionState.value = LiveTalkConnectionState.disconnected;
  }

  /// Ask the model to produce a response immediately (yields the floor).
  void requestAssistantTurn() {
    try {
      _dc?.send(RTCDataChannelMessage(jsonEncode({'type': 'response.create'})));
    } catch (_) {}
  }

  /// Optional hook for when you detect end of a user utterance via VAD.
  void emitUserUtterance(String text) {
    if (text.trim().isEmpty) return;
    userUtterance.add(text.trim());
  }

  String? get selectedModel => _model;
  String? get selectedVoice => _voice;
  DateTime? get sessionStartedAt => _startedAt;

  // Press-to-talk / mute helpers
  void setMuted(bool value) {
    muted.value = value;
    try {
      final tracks = _mic?.getAudioTracks() ?? const <MediaStreamTrack>[];
      for (final t in tracks) {
        t.enabled = !value;
      }
    } catch (_) {}
  }

  void toggleMute() => setMuted(!muted.value);
  void holdToTalkStart() => setMuted(false);
  void holdToTalkEnd() => setMuted(true);

  // Retry with last known arguments
  Future<void> retry() async {
    final te = _lastTokenEndpoint;
    if (te == null) return;
    reconnecting.value = true;
    try {
      await connect(
        tokenEndpoint: te,
        model: _lastModel ?? 'gpt-realtime-nano',
        voice: _lastVoice ?? 'alloy',
        persona: _lastPersona,
        context: _lastContext,
      );
    } finally {
      reconnecting.value = false;
    }
  }
}

// Internal bridge used by LiveTalkService to fall back to WS while
// keeping the same observable streams and notifiers.
class _LiveTalkServiceWsBridge {
  _LiveTalkServiceWsBridge(this._parent);
  final LiveTalkService _parent;

  Future<void> connect({
    required Uri tokenEndpoint,
    required String model,
    required String voice,
    String? persona,
    Map<String, dynamic>? context,
    String? sessionId,
  }) async {
    // Use the WS fallback service and wire its streams to the parent service
    final ws = LiveTalkServiceWs.instance;
    ws.mode.addListener(() => _parent.mode.value = ws.mode.value);
    ws.connectionState.addListener(() => _parent.connectionState.value = ws.connectionState.value);
    ws.assistantSpeaking.addListener(() => _parent.assistantSpeaking.value = ws.assistantSpeaking.value);
    ws.muted.addListener(() => _parent.muted.value = ws.muted.value);
    ws.reconnecting.addListener(() => _parent.reconnecting.value = ws.reconnecting.value);
    ws.lastError.addListener(() => _parent.lastError.value = ws.lastError.value);
    ws.partialText.stream.listen(_parent.partialText.add);
    ws.finalText.stream.listen(_parent.finalText.add);
    await ws.connect(
      tokenEndpoint: tokenEndpoint,
      model: model,
      voice: voice,
      persona: persona,
      context: context,
      sessionId: sessionId,
    );
  }
}
