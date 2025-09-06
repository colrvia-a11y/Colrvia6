import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import 'package:color_canvas/utils/permissions.dart';
import 'package:color_canvas/services/errors.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:color_canvas/services/live_talk_types.dart';
import 'package:color_canvas/services/live_talk_config.dart';

/// WebSocket fallback for environments where WebRTC is blocked.
/// This implementation sets up the Realtime WS, sends session.update and
/// parses text deltas. Audio input/output streaming are scaffolds only and
/// may require additional platform support to capture PCM16.
class LiveTalkServiceWs {
  LiveTalkServiceWs._();
  static final LiveTalkServiceWs instance = LiveTalkServiceWs._();

  final ValueNotifier<String> mode = ValueNotifier<String>('ws-fallback');
  final ValueNotifier<LiveTalkConnectionState> connectionState =
      ValueNotifier<LiveTalkConnectionState>(LiveTalkConnectionState.disconnected);
  final ValueNotifier<bool> assistantSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> reconnecting = ValueNotifier<bool>(false);
  final ValueNotifier<LiveTalkError?> lastError = ValueNotifier<LiveTalkError?>(null);
  final StreamController<String> partialText = StreamController<String>.broadcast();
  final StreamController<String> finalText = StreamController<String>.broadcast();

  WebSocket? _ws;
  String _acc = '';
  String? _ephemeralKey;
  Uri? _lastTokenEndpoint;
  String? _lastModel;
  String? _lastVoice;
  String? _lastPersona;
  Map<String, dynamic>? _lastContext;

  // Provide a renderer for API parity; not used in WS mode
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

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
      final ok = await ensureMicPermission();
      if (!ok) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.micPermission);
        throw Exception('Microphone permission denied');
      }

      // Mint ephemeral key via your callable/gateway
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.notSignedIn);
        throw Exception('Not signed in');
      }
      final sessionIdLocal = sessionId ?? const Uuid().v4();
      _lastTokenEndpoint = tokenEndpoint;
      _lastModel = model;
      _lastVoice = voice;
      _lastPersona = persona;
      _lastContext = context;
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

      // Connect WS to Realtime
      final uri = LiveTalkConfig.wsRealtimeUrl(model: model);
      debugPrint('LiveTalkServiceWs: dialing WS URL: $uri');
      _ws = await WebSocket.connect(
        uri.toString(),
        headers: {
          'Authorization': 'Bearer $_ephemeralKey',
          'OpenAI-Beta': 'realtime=v1',
        },
      );
      _ws!.listen(_onMessage, onError: (e) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.wsClosed);
        connectionState.value = LiveTalkConnectionState.error;
      }, onDone: () async {
        lastError.value = LiveTalkError(LiveTalkErrorCode.wsClosed);
        connectionState.value = LiveTalkConnectionState.disconnected;
        // Try a single automatic reconnect
        final te = _lastTokenEndpoint;
        if (te != null) {
          reconnecting.value = true;
          try {
            await connect(
              tokenEndpoint: te,
              model: _lastModel ?? 'gpt-realtime-nano',
              voice: _lastVoice ?? 'alloy',
              persona: _lastPersona,
              context: _lastContext,
            );
          } catch (_) {
            // Keep disconnected; user can retry
          } finally {
            reconnecting.value = false;
          }
        }
      });

      // Send session.update
      final instructions = _buildInstructions(persona: persona, context: context);
      _sendJson({
        'type': 'session.update',
        'session': {
          'instructions': instructions,
          'turn_detection': {'type': 'server_vad'},
        }
      });

      connectionState.value = LiveTalkConnectionState.connected;

      // TODO: Capture PCM16 frames and stream as input_audio_buffer.append over WS.
      // This requires a mic capture plugin exposing PCM on Dart side.
    } catch (e, st) {
      debugPrint('LiveTalkServiceWs connect error (${e.runtimeType}): $e\n$st');
      connectionState.value = LiveTalkConnectionState.error;
      if (e is TimeoutException) {
        lastError.value = LiveTalkError(LiveTalkErrorCode.network);
      } else {
        lastError.value = lastError.value ?? LiveTalkError(LiveTalkErrorCode.unknown);
      }
      rethrow;
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

  void _onMessage(dynamic data) {
    try {
      final m = jsonDecode(data as String) as Map<String, dynamic>;
      final type = m['type'] as String?;
      if (type == null) return;

      if (type == 'response.delta') {
        assistantSpeaking.value = true;
        final delta = m['delta'] as Map<String, dynamic>?;
        final text = (delta?['text'] ?? delta?['output_text'] ?? delta?['content'] ?? '') as String?;
        if (text != null && text.isNotEmpty) {
          _acc += text;
          partialText.add(_acc);
        }
      } else if (type == 'response.completed') {
        if (_acc.isNotEmpty) finalText.add(_acc);
        _acc = '';
        partialText.add('');
        assistantSpeaking.value = false;
      }

      // TODO: handle audio chunks when available
    } catch (_) {}
  }

  void _sendJson(Map<String, dynamic> m) {
    try { _ws?.add(jsonEncode(m)); } catch (_) {}
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

  Future<void> disconnect() async {
    try { await _ws?.close(); } catch (_) {}
    _ws = null; _acc = ''; _ephemeralKey = null;
    connectionState.value = LiveTalkConnectionState.disconnected;
    muted.value = false;
    reconnecting.value = false;
  }
}

// Uses shared LiveTalkConnectionState from live_talk_types.dart
