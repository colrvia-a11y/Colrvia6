// lib/screens/interview_voice_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:color_canvas/services/interview_voice_engine.dart';
import 'package:color_canvas/widgets/via_orb.dart';

class InterviewVoiceScreen extends StatefulWidget {
  const InterviewVoiceScreen({super.key});

  @override
  State<InterviewVoiceScreen> createState() => _InterviewVoiceScreenState();
}

class _InterviewVoiceScreenState extends State<InterviewVoiceScreen> {
  final InterviewVoiceEngine _engine = InterviewVoiceEngine();
  StreamSubscription<String?>? _subscription;
  String? liveTranscript;

  String get currentPrompt => _engine.currentPrompt;
  bool get isListening => _engine.isListening;

  @override
  void initState() {
    super.initState();
    _engine.startVoiceMode();
    _subscription = _engine.liveTranscriptStream.listen((text) {
      setState(() => liveTranscript = text);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _engine.endSession();
    super.dispose();
  }

  void pauseInterview() {
    _engine.pause();
    setState(() {});
  }

  Future<void> showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Interview?'),
        content: const Text('Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (shouldExit == true) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Via Interview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => showExitDialog(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              currentPrompt,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(child: ViaOrb(isListening: isListening)),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                liveTranscript ?? 'Listening...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  onPressed: pauseInterview,
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/interview/text');
                  },
                  child: const Text('Switch to typing'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
