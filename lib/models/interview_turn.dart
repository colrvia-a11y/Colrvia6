// lib/models/interview_turn.dart
import 'package:flutter/foundation.dart';

@immutable
class InterviewTurn {
  final String text;
  final bool isUser;
  const InterviewTurn({required this.text, required this.isUser});
  @override
  String toString() => 'InterviewTurn(isUser: ${isUser ? 'true' : 'false'}, text: $text)';
}
