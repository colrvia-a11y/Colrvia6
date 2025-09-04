// lib/widgets/via_bubble.dart
import 'package:flutter/material.dart';

class ViaBubble extends StatelessWidget {
  final String text;
  const ViaBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = Theme.of(context).colorScheme.onSurface;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: TextStyle(color: fg)),
      ),
    );
  }
}
