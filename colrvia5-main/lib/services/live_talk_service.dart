import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveTalkService {
  LiveTalkService._();
  static final instance = LiveTalkService._();

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  RTCPeerConnection? _pc;
  MediaStream? _mic;
  MediaStream? _remote;
  RTCDataChannel? _dc;

  Stream<DocumentSnapshot<Map<String, dynamic>>> sessionStream(String sessionId) =>
      FirebaseFirestore.instance.doc('talkSessions/$sessionId').snapshots();

  Future<String> createSession({Map<String, dynamic>? answers, DateTime? when}) async {
    final res = await _functions.httpsCallable('createTalkSession').call({
      if (answers != null) 'answers': answers,
      if (when != null) 'scheduledAt': when.toIso8601String(),
    });
    return (res.data as Map)['sessionId'] as String;
  }

  Future<void> _ensureMic() async {
    final p = await Permission.microphone.request();
    if (!p.isGranted) throw Exception('Microphone permission is required');
    _mic ??= await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
  }

  Future<_GatewayAuth> _issueToken(String sessionId) async {
    final res = await _functions.httpsCallable('issueVoiceGatewayToken').call({'sessionId': sessionId});
    final m = (res.data as Map).cast<String, dynamic>();
    return _GatewayAuth(token: m['token'] as String);
  }

  Future<void> connect({required String sessionId, required Uri gatewayWss}) async {
    await _ensureMic();

    final auth = await _issueToken(sessionId);

    final config = {
      'sdpSemantics': 'unified-plan',
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };
    _pc = await createPeerConnection(config);

    // Mic → pc
    if (_mic != null) {
      for (var track in _mic!.getTracks()) {
        await _pc!.addTrack(track, _mic!);
      }
    }

    // Remote audio
    _remote = await createLocalMediaStream('remote');
    _pc!.onTrack = (RTCTrackEvent ev) {
      if (ev.streams.isNotEmpty) {
        _remote = ev.streams.first;
      }
    };

    // Data channel (events)
    _dc = await _pc!.createDataChannel('events', RTCDataChannelInit()..ordered = true);

    // Create offer
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    // Send SDP over WebSocket to gateway
    final ws = await _WebSocketClient.connect(gatewayWss);
    ws.send(jsonEncode({
      'type': 'auth',
      'token': auth.token,
      'sessionId': sessionId,
    }));
    ws.send(jsonEncode({ 'type': 'offer', 'sdp': offer.sdp, 'sessionId': sessionId }));

    ws.onMessage = (String data) async {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'answer':
          final ans = RTCSessionDescription(msg['sdp'] as String, 'answer');
          await _pc!.setRemoteDescription(ans);
          break;
        case 'ice':
          await _pc!.addCandidate(RTCIceCandidate(msg['candidate'], msg['sdpMid'], msg['sdpMLineIndex']));
          break;
        case 'event':
          // Pass through to UI via data channel as needed
          _dc?.send(RTCDataChannelMessage(jsonEncode(msg['payload'])));
          break;
      }
    };

    // Handle local ICE
    _pc!.onIceCandidate = (c) => ws.send(jsonEncode({'type': 'ice', 'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex}));
  }

  MediaStream? get remoteStream => _remote;

  Future<void> hangup() async {
    try { await _dc?.close(); } catch (_) {}
    try { await _pc?.close(); } catch (_) {}
    try { await _mic?.dispose(); } catch (_) {}
    _dc = null; _pc = null; _mic = null; _remote = null;
  }
}

class _GatewayAuth { final String token; _GatewayAuth({required this.token}); }

// Minimal WS client (platform channel or dart:html alternative). In Flutter mobile, use WebSocket from dart:io
import 'dart:io';
class _WebSocketClient {
  WebSocket _ws; void Function(String data)? onMessage;
  _WebSocketClient._(this._ws) { _ws.listen((d) { if (d is String) onMessage?.call(d); }); }
  static Future<_WebSocketClient> connect(Uri uri) async { final ws = await WebSocket.connect(uri.toString()); return _WebSocketClient._(ws); }
  void send(String s) => _ws.add(s);
  Future<void> close() => _ws.close();
}
