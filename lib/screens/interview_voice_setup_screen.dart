import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:color_canvas/services/audio_service.dart';
import 'package:color_canvas/services/live_talk_service.dart';
import 'package:color_canvas/utils/permissions.dart';
import 'package:color_canvas/services/user_prefs_service.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/utils/voice_token_endpoint.dart';

class InterviewVoiceSetupScreen extends StatefulWidget {
  const InterviewVoiceSetupScreen({super.key});

  @override
  State<InterviewVoiceSetupScreen> createState() => _InterviewVoiceSetupScreenState();
}

class _InterviewVoiceSetupScreenState extends State<InterviewVoiceSetupScreen> {
  // Token minting Function URL (derived from Firebase project configuration).
  // See README > "Live Talk (Via) Quickstart" and docs/voice_testing.md for setup and QA steps.
  bool micGranted = false;
  double micLevel = 0.0;
  String micStatusText = 'Mic permission required.';
  StreamSubscription<double>? _micSubscription;

  @override
  void initState() {
    super.initState();
    _initMic();
  }

  Future<void> _initMic() async {
    final status = await Permission.microphone.request();
    setState(() {
      micGranted = status.isGranted;
      micStatusText =
          micGranted ? 'Listening...' : 'Mic permission required.';
    });

    if (micGranted) {
      _startListening();
    }
  }

  void _startListening() {
    AudioService().start();
    _micSubscription =
        AudioService().micLevelStream.listen((level) {
      setState(() => micLevel = level);
    });
  }

  @override
  void dispose() {
    _micSubscription?.cancel();
    AudioService().stop();
    super.dispose();
  }

  // Build a concise persona/context using recent interview answers if available.
  // For now this returns a minimal placeholder; can be extended to pull from
  // InterviewEngine/Journey state or Firestore.
  Future<(String, Map<String, dynamic>)> _buildPersonaAndContext() async {
    final persona = 'Friendly, practical color coach with great follow-up questions.';
    final ctx = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'screen': 'interview_voice_setup',
      // TODO: populate from recent answers (roomType, style, constraints, last 2 answers)
      // This would require integration with InterviewEngine/Journey state or Firestore
      'placeholders': {
        'roomType': null,
        'style': null,
        'constraints': null,
        'recentAnswers': <String>[],
      }
    };
    return (persona, ctx);
  }

  Future<bool> _checkDailyCap() async {
    try {
      final prefs = await UserPrefsService.fetch();
      final capMin = prefs.voiceDailyCapMinutes;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return true;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final q = await FirebaseFirestore.instance
          .collection('interviewSessions')
          .where('userId', isEqualTo: uid)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      int totalSec = 0;
      for (final d in q.docs) {
        final m = d.data();
        final sec = (m['durationSec'] as int?) ?? 0;
        totalSec += sec;
      }
      final usedMin = (totalSec / 60).floor();
      return usedMin < capMin;
    } catch (_) {
      return true; // fail-open
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Enable your mic',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Via needs mic access to hear your answers. You can always switch to text mode.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            _MicLevelBar(level: micLevel),
            const SizedBox(height: 12),
            Text(micStatusText),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('Continue with Voice'),
              onPressed: micGranted
                  ? () async {
                      // Store context before async operations
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      
                      // Ensure permission again and start realtime connect
                      final ok = await ensureMicPermission();
                      if (!ok) {
                        if (!mounted) return;
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Microphone permission is required')),
                        );
                        return;
                      }

                      final personaAndCtx = await _buildPersonaAndContext();
                      // Soft cap check
                      final okMinutes = await _checkDailyCap();
                      if (!okMinutes) {
                        if (!mounted) return;
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Daily Live Talk limit reached. Please try again tomorrow.')),
                        );
                        return;
                      }

                      final prefs = await UserPrefsService.fetch();
                      try {
                        await LiveTalkService.instance.connect(
                          tokenEndpoint: VoiceTokenEndpoint.issueVoiceGatewayToken(),
                          persona: personaAndCtx.$1,
                          context: personaAndCtx.$2,
                          voice: prefs.voiceVoice,
                          model: prefs.voiceModel,
                        );
                        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
                        final path = LiveTalkService.instance.mode.value;
                        await AnalyticsService.instance.voiceSessionStart(
                          uid: uid,
                          model: prefs.voiceModel,
                          voice: prefs.voiceVoice,
                          path: path,
                        );
                        if (!mounted) return;
                        navigator.pushNamed('/interview/voice');
                      } catch (e) {
                        if (!mounted) return;
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Failed to start voice session: $e')),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/interview/text');
              },
              child: const Text('Switch to typing instead'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicLevelBar extends StatelessWidget {
  const _MicLevelBar({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * level.clamp(0.0, 1.0);
        return Container(
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade300,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}
