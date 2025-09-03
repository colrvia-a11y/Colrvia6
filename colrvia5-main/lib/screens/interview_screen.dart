import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import '../services/create_flow_progress.dart';
import 'package:color_canvas/services/analytics_service.dart';

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5; // Example total steps
  final Map<String, dynamic> _answers = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log('journey_step_view', {
      'step_id': JourneyService.instance.state.value?.currentStepId ?? 'interview.basic',
    });
  }

  void _onStepChanged(int step, int total) {
    CreateFlowProgress.instance.set('interview', step / total);
  }

  Future<void> _finishInterview() async {
    // Update the guided journey
    final j = JourneyService.instance;
    // If you have real answers, pass them here; otherwise, at least a marker
    final payload = _answers.isNotEmpty ? _answers : {'completed': true};
    await j.setArtifact('answers', payload);
    await j.completeCurrentStep(); // interview.basic -> roller.build
    if (mounted) Navigator.of(context).maybePop(); // return to Create Hub
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _onStepChanged(_currentStep, _totalSteps);
    } else {
      _finishInterview();
    }
  }

  @override
  void dispose() {
    CreateFlowProgress.instance.clear('interview');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interview')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Step ${_currentStep + 1} of $_totalSteps'),
            ElevatedButton(
              onPressed: _nextStep,
              child: Text(_currentStep == _totalSteps - 1 ? 'Finish' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}
