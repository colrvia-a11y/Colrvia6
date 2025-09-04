import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:color_canvas/services/audio_service.dart';

class InterviewVoiceSetupScreen extends StatefulWidget {
  const InterviewVoiceSetupScreen({super.key});

  @override
  State<InterviewVoiceSetupScreen> createState() => _InterviewVoiceSetupScreenState();
}

class _InterviewVoiceSetupScreenState extends State<InterviewVoiceSetupScreen> {
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
                  ? () {
                      Navigator.pushNamed(context, '/interview/voice');
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
