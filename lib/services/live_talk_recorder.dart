import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/services/live_talk_service.dart';
import 'package:color_canvas/services/transcript_recorder.dart';
import 'package:color_canvas/services/interview_shared_engine.dart' as shared;

/// Adapts LiveTalkService streams into a buffered transcript and persists
/// a session record to Firestore when stopped.
class LiveTalkTranscriptAdapter {
  LiveTalkTranscriptAdapter(this._talk);

  final LiveTalkService _talk;
  final List<_Turn> _turns = <_Turn>[];
  StreamSubscription<String>? _assistantSub;
  StreamSubscription<String>? _userSub;
  DateTime? _startedAt;

  void start() {
    _startedAt = _talk.sessionStartedAt ?? DateTime.now();
    // Assistant final text
    _assistantSub = _talk.finalText.stream.listen((t) {
      final text = t.trim();
      if (text.isEmpty) return;
      _turns.add(_Turn('assistant', text, DateTime.now()));
      TranscriptRecorder.instance.addAssistant(text);
    });
    // Optional user utterances (if emitted)
    _userSub = _talk.userUtterance.stream.listen((t) {
      final text = t.trim();
      if (text.isEmpty) return;
      _turns.add(_Turn('user', text, DateTime.now()));
      TranscriptRecorder.instance.addUser(text);
    });
  }

  Future<String> stopAndPersist() async {
    await _assistantSub?.cancel();
    await _userSub?.cancel();
    final endedAt = DateTime.now();
    final started = _startedAt ?? endedAt;

    final id = await shared.InterviewEngine.saveVoiceSession(
      model: _talk.selectedModel ?? 'gpt-realtime-nano',
      voice: _talk.selectedVoice ?? 'alloy',
      startedAt: started,
      endedAt: endedAt,
      turns: _turns.map((t) => t.toJson()).toList(),
      uploadJson: true,
    );
    return id;
  }
}

class _Turn {
  final String role; // 'assistant'|'user'
  final String text;
  final DateTime ts;
  _Turn(this.role, this.text, this.ts);
  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'ts': Timestamp.fromDate(ts),
      };
}
