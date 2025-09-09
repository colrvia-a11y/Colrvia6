// lib/models/interview_turn.dart
import 'package:flutter/foundation.dart';

@immutable
class InterviewTurn {
  final String text;
  final bool isUser;
  const InterviewTurn({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  factory InterviewTurn.fromJson(Map<String, dynamic> json) {
    return InterviewTurn(
      text: json['text'] as String? ?? '',
      isUser: (json['isUser'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'InterviewTurn(isUser: ${isUser ? 'true' : 'false'}, text: $text)';
}
