import 'package:flutter/material.dart';
import '../services/create_flow_progress.dart';
import '../services/journey/journey_service.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _completed = 0;
  final int _total = 10; // Example total lessons

  void _completeLesson() {
    if (_completed < _total) {
      setState(() => _completed++);
      CreateFlowProgress.instance.set('learn', _completed / _total);
    }
  }

  @override
  void dispose() {
    CreateFlowProgress.instance.clear('learn');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artifacts =
        JourneyService.instance.state.value?.artifacts ?? <String, dynamic>{};
    final tips = <Widget>[];
    if (artifacts['paletteId'] != null) {
      tips.add(const _TipCard(
        title: 'Palette Saved',
        body: 'Explore how contrast can enhance your colors.',
      ));
    }
    if (artifacts['answers'] != null) {
      tips.add(const _TipCard(
        title: 'Style Insights',
        body: 'See tips tailored to your questionnaire answers.',
      ));
    }
    if (tips.isEmpty) {
      tips.add(const Text('Complete steps to unlock tips.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Lessons completed: $_completed / $_total'),
          const SizedBox(height: 16),
          ...tips,
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _completeLesson,
            child: const Text('Complete Lesson'),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String body;
  const _TipCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}
