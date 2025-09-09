import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/services/live_talk_service.dart';
import 'package:color_canvas/utils/voice_token_endpoint.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/interview_engine.dart';
import 'package:color_canvas/services/schema_interview_compiler.dart';
import 'package:color_canvas/screens/interview_review_screen.dart';

class LiveTalkCallScreen extends StatefulWidget {
  final String sessionId;
  const LiveTalkCallScreen({super.key, required this.sessionId});
  @override
  State<LiveTalkCallScreen> createState() => _LiveTalkCallScreenState();
}

class _LiveTalkCallScreenState extends State<LiveTalkCallScreen> {
  // Token minting Function URL (derived from Firebase project configuration).
  bool _connecting = true;
  double _progress = 0;
  String _question = 'Connecting…';
  String _partial = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    LiveTalkService.instance.disconnect();
    super.dispose();
  }

  Future<void> _init() async {
    // Listen to session doc
    FirebaseFirestore.instance
        .doc('talkSessions/${widget.sessionId}')
        .snapshots()
        .listen((doc) {
      final d = doc.data();
      if (d == null) return;
      setState(() {
        _progress = (d['progress'] as num? ?? 0).toDouble();
        _question = (d['lastQuestion'] as String?) ?? _question;
        _partial = (d['lastPartial'] as String?) ?? '';
      });
      if (d['status'] == 'ended') _onEnded();
    });

    // Connect using the ephemeral session minted by your token endpoint.
    await LiveTalkService.instance.connect(
      tokenEndpoint: VoiceTokenEndpoint.issueVoiceGatewayToken(),
      sessionId: widget.sessionId,
      // model/voice can be left as defaults or pulled from prefs
    );
    setState(() => _connecting = false);
  }

  void _onEnded() async {
    // After hangup, jump to Review with current answers
    if (!mounted) return;
    // Build an InterviewEngine from schema, seeded with JourneyService answers
    InterviewEngine engine;
    try {
      final compiler = await SchemaInterviewCompiler.loadFromAsset(
          'assets/schemas/single-room-color-intake.json');
      final prompts = compiler.compile();
      engine = InterviewEngine.fromPrompts(prompts);
    } catch (_) {
      engine = InterviewEngine.demo();
    }
    final seed = JourneyService.instance.state.value?.artifacts['answers']
        as Map<String, dynamic>?;
    engine.start(seedAnswers: seed);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => InterviewReviewScreen(engine: engine)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live AI Call'), actions: [
        if (_progress > 0)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(child: Text('${(_progress * 100).round()}%'))),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 12),
          Text(_question, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _partial.isEmpty ? 0.5 : 1,
              child: Text(_partial,
                  style: Theme.of(context).textTheme.bodyMedium)),
          // Hidden video view used to play remote audio (attached in service)
          const SizedBox(height: 2),
          SizedBox(
              height: 1,
              width: 1,
              child: RTCVideoView(LiveTalkService.instance.remoteRenderer)),
          const Spacer(),
          Row(children: [
            OutlinedButton.icon(
                onPressed: _connecting ? null : _hangup,
                icon: const Icon(Icons.call_end, color: Colors.red),
                label: const Text('Hang up')),
            const SizedBox(width: 8),
            TextButton(
                onPressed: _switchToText, child: const Text('Switch to text')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _hangup() async {
    await LiveTalkService.instance.disconnect();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _switchToText() {
    /* Pop back to InterviewScreen; engine already has current answers via gateway updates */ Navigator
            .of(context)
        .maybePop();
  }
}
