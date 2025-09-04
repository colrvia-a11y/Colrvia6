// lib/models/interview_turn.dart
import 'package:flutter/foundation.dart';

@immutable
class InterviewTurn {
  final String text;
  final bool isUser;
<<<<<<< HEAD
  const InterviewTurn({required this.text, required this.isUser});
  @override
  String toString() => 'InterviewTurn(isUser: ${isUser ? 'true' : 'false'}, text: $text)';
=======
  InterviewTurn({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  factory InterviewTurn.fromJson(Map<String, dynamic> json) {
    return InterviewTurn(
      text: json['text'],
      isUser: json['isUser'] ?? false,
    );
  }
>>>>>>> 7c8c5df8e4dc9e146147d804575b39da2880b37c
}
