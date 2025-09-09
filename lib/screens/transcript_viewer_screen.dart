// lib/screens/transcript_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:color_canvas/services/transcript_recorder.dart';

class TranscriptViewerScreen extends StatelessWidget {
  final List<TranscriptEvent> events;
  const TranscriptViewerScreen({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transcript')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = events[i];
          final color = switch (e.type) {
            'question' => Colors.blueGrey,
            'user' => Colors.black,
            'answer' => Colors.teal,
            _ => Colors.grey,
          };
          return ListTile(
            dense: true,
            title: Text(e.text),
            subtitle: Text(
                '${e.type}${e.promptId != null ? ' • ${e.promptId}' : ''}'),
            leading: Icon(
              switch (e.type) {
                'question' => Icons.help_outline,
                'user' => Icons.person,
                'answer' => Icons.check,
                _ => Icons.notes,
              },
              color: color,
            ),
          );
        },
      ),
    );
  }
}
