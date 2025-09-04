import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/services/live_talk_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/screens/interview_review_screen.dart';

class LiveTalkCallScreen extends StatefulWidget {
  final String sessionId;
  const LiveTalkCallScreen({super.key, required this.sessionId});
  @override State<LiveTalkCallScreen> createState() => _LiveTalkCallScreenState();
}

class _LiveTalkCallScreenState extends State<LiveTalkCallScreen> {
  final _renderer = RTCVideoRenderer();
  bool _connecting = true;
  double _progress = 0;
  String _question = 'Connecting…';
  String _partial = '';

  @override
  void initState() { super.initState(); _init(); }
  @override
  void dispose() { _renderer.dispose(); LiveTalkService.instance.hangup(); super.dispose(); }

  Future<void> _init() async {
    await _renderer.initialize();
    // Listen to session doc
    FirebaseFirestore.instance.doc('talkSessions/${widget.sessionId}').snapshots().listen((doc) {
      final d = doc.data(); if (d == null) return;
      setState(() {
        _progress = (d['progress'] as num? ?? 0).toDouble();
        _question = (d['lastQuestion'] as String?) ?? _question;
        _partial = (d['lastPartial'] as String?) ?? '';
      });
      if (d['status'] == 'ended') _onEnded();
    });

    final gateway = Uri.parse('wss://voice.colrvia.com/rtc'); // TODO: set real gateway
    await LiveTalkService.instance.connect(sessionId: widget.sessionId, gatewayWss: gateway);
    // Attach remote audio to renderer (audio-only). For audio, we don't display; attaching keeps lifecycle consistent.
    _renderer.srcObject = LiveTalkService.instance.remoteStream;
    setState(() => _connecting = false);
  }

  void _onEnded() async {
    // After hangup, jump to Review with current answers
    if (!mounted) return;
    final engineAnswers = JourneyService.instance.state.value?.artifacts['answers'] as Map<String, dynamic>?;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => InterviewReviewScreen(engine: /* reuse active engine or rebuild with answers */ throw UnimplementedError('Inject engine instance here'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live AI Call'), actions: [
        if (_progress > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Center(child: Text('${(_progress * 100).round()}%'))),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 12),
          Text(_question, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: _partial.isEmpty ? 0.5 : 1, child: Text(_partial, style: Theme.of(context).textTheme.bodyMedium)),
          const Spacer(),
          Row(children: [
            OutlinedButton.icon(onPressed: _connecting ? null : _hangup, icon: const Icon(Icons.call_end, color: Colors.red), label: const Text('Hang up')),
            const SizedBox(width: 8),
            TextButton(onPressed: _switchToText, child: const Text('Switch to text')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _hangup() async { await LiveTalkService.instance.hangup(); if (mounted) Navigator.of(context).maybePop(); }
  void _switchToText() { /* Pop back to InterviewScreen; engine already has current answers via gateway updates */ Navigator.of(context).maybePop(); }
}
