// lib/models/interview_turn.dart
class InterviewTurn {
  final String text;
  final bool isUser;
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
}
