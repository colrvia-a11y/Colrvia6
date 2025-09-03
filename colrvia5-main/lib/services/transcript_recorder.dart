// lib/services/transcript_recorder.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:color_canvas/services/auth_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';

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
  Map<String, dynamic> toJson() =>
      {'type': type, 'text': text, 'promptId': promptId, 'at': at.toIso8601String()};
}

class TranscriptRecorder {
  final List<TranscriptEvent> _events = [];
  void add(TranscriptEvent e) => _events.add(e);
  List<TranscriptEvent> get events => List.unmodifiable(_events);

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

  String toJsonLines() =>
      _events.map((e) => jsonEncode(e.toJson())).join('\n');

  Future<String> uploadJson({String? sessionId}) async {
    final uid = AuthService.instance.uid ?? 'anon';
    final id = sessionId ??
        (JourneyService.instance.state.value?.artifacts['interviewId'] as String? ??
            'adhoc');
    final ref = FirebaseStorage.instance
        .ref('users/$uid/transcripts/$id.json');
    final data = toJsonLines();
    await ref.putString(data,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'application/json'));
    return ref.getDownloadURL();
  }
}
