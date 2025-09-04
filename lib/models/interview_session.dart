// lib/models/interview_session.dart
import 'interview_turn.dart';

class InterviewSession {
  final String id;
  final String userId;
  final List<InterviewTurn> turns;
  final DateTime startedAt;
  final DateTime updatedAt;

  InterviewSession({
    required this.id,
    required this.userId,
    required this.turns,
    required this.startedAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'turns': turns.map((t) => t.toJson()).toList(),
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InterviewSession.fromJson(Map<String, dynamic> json) {
    return InterviewSession(
      id: json['id'],
      userId: json['userId'],
      turns: (json['turns'] as List)
          .map((t) => InterviewTurn.fromJson(t))
          .toList(),
      startedAt: DateTime.parse(json['startedAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

