// lib/services/transcript_recorder.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:color_canvas/services/auth_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/models/interview_turn.dart';

class TranscriptEvent {
  final String type; // 'question'|'partial'|'user'|'answer'|'note'
  final String text;
  final String? promptId;
  final DateTime at;
  TranscriptEvent({
    required this.type,
    required this.text,
    this.promptId,
    DateTime? at,
  }) : at = at ?? DateTime.now();
  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        'promptId': promptId,
        'at': at.toIso8601String()
      };
}

class TranscriptRecorder {
  TranscriptRecorder._();
  static final TranscriptRecorder instance = TranscriptRecorder._();
  factory TranscriptRecorder() => instance;

  final List<TranscriptEvent> _events = [];
  void add(TranscriptEvent e) => _events.add(e);
  List<TranscriptEvent> get events => List.unmodifiable(_events);

  void clear() => _events.clear();

  // Convenience helpers used by live voice/text flows
  void addAssistant(String text, {String? promptId}) =>
      add(TranscriptEvent(type: 'assistant', text: text, promptId: promptId));
  void addUser(String text, {String? promptId}) =>
      add(TranscriptEvent(type: 'user', text: text, promptId: promptId));
  void addPartial(String text, {String? promptId}) =>
      add(TranscriptEvent(type: 'partial', text: text, promptId: promptId));

  String toSrt() {
    final b = StringBuffer();
    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      final t = DateFormat('HH:mm:ss,SSS').format(e.at);
      b.writeln(i + 1);
      b.writeln('$t --> $t');
      b.writeln('[${e.type}] ${e.text}');
      b.writeln();
    }
    return b.toString();
  }

  String toJsonLines() => _events.map((e) => jsonEncode(e.toJson())).join('\n');

  Future<String> uploadJson({String? sessionId}) async {
    final uid = AuthService.instance.uid ?? 'anon';
    final id = sessionId ??
        (JourneyService.instance.state.value?.artifacts['interviewId']
                as String? ??
            'adhoc');
    final ref = FirebaseStorage.instance.ref('users/$uid/transcripts/$id.json');
    final data = toJsonLines();
    await ref.putString(data,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'application/json'));
    return ref.getDownloadURL();
  }

  /// Convert recorded events to canonical InterviewTurns (assistant/user only),
  /// filtering out partials and notes. Consecutive partials are ignored.
  List<InterviewTurn> toInterviewTurns() {
    final out = <InterviewTurn>[];
    for (final e in _events) {
      if (e.type == 'assistant' || e.type == 'question' || e.type == 'answer') {
        if (e.text.trim().isEmpty) continue;
        out.add(InterviewTurn(text: e.text.trim(), isUser: false));
      } else if (e.type == 'user') {
        if (e.text.trim().isEmpty) continue;
        out.add(InterviewTurn(text: e.text.trim(), isUser: true));
      } else {
        // ignore 'partial' and other types for final transcript
      }
    }
    return out;
  }
}
