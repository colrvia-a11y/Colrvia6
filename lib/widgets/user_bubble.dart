// lib/widgets/user_bubble.dart
import 'package:flutter/material.dart';

class UserBubble extends StatelessWidget {
  final String text;
  const UserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;
    return Align(
      alignment: Alignment.centerRight,
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
