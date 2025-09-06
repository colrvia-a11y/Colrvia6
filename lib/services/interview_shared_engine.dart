// lib/services/interview_shared_engine.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/models/interview_turn.dart';
import 'package:color_canvas/models/interview_session.dart';
import 'package:color_canvas/services/transcript_recorder.dart';

/// Shared Interview voice/text engine (singleton).
class InterviewEngine {
  InterviewEngine._internal();
  static final InterviewEngine _instance = InterviewEngine._internal();
  factory InterviewEngine() => _instance;

  // Optional analytics hook
  void Function(String event, Map<String, dynamic> props)? onAnalytics;

  final _turns = <InterviewTurn>[];
  final _liveTranscript = StreamController<String?>.broadcast();
  DateTime _startedAt = DateTime.now();

  // Voice state
  bool _isListening = false;
  StreamSubscription<String?>? _sub;

  // Exposed API
  List<InterviewTurn> get initialTurns => List.unmodifiable(_turns);
  Stream<String?> get liveTranscriptStream => _liveTranscript.stream;
  bool get isListening => _isListening;
  String get currentPrompt {
    for (var i = _turns.length - 1; i >= 0; i--) {
      final t = _turns[i];
      if (!t.isUser) return t.text;
    }
    return _getNextPrompt();
  }

  // Text mode
  void startTextMode() {
    _log('start_text_mode');
    _turns.clear();
    _startedAt = DateTime.now();
    final prompt = _getNextPrompt();
    _turns.add(InterviewTurn(text: prompt, isUser: false));
    TranscriptRecorder.instance.addAssistant(prompt);
  }

  Future<String> submitTextAnswer(String userText) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final response = _getNextPrompt();
    _turns.addAll([
      InterviewTurn(text: userText, isUser: true),
      InterviewTurn(text: response, isUser: false),
    ]);
    _log('submit_text_answer', {'chars': userText.length});
    TranscriptRecorder.instance
      ..addUser(userText)
      ..addAssistant(response);
    return response;
  }

  // Voice mode
  void startVoiceMode() {
    _log('start_voice_mode');
    _turns.clear();
    _startedAt = DateTime.now();
    final prompt = _getNextPrompt();
    _turns.add(InterviewTurn(text: prompt, isUser: false));
    TranscriptRecorder.instance.addAssistant(prompt);
    _isListening = true;
    _sub?.cancel();
    _sub = Stream.periodic(const Duration(milliseconds: 300), (i) => 'Partial response $i')
        .take(5)
        .map((s) => s as String?)
        .listen((text) {
          _liveTranscript.add(text);
          if (text != null && text.isNotEmpty) {
            TranscriptRecorder.instance.addPartial(text);
          }
        });
  }
  void pause() {
    if (!_isListening) return;
    _log('pause');
    _isListening = false;
    _cancelStream();
    _liveTranscript.add(null);
  }

  void resume() {
    if (_isListening) return;
    _log('resume');
    _isListening = true;
    _sub?.cancel();
    _sub = Stream.periodic(const Duration(milliseconds: 300), (i) => 'Partial response $i')
        .take(5)
        .map((s) => s as String?)
        .listen((text) => _liveTranscript.add(text));
  }

  void endSession() {
    _log('end_session');
    _cancelStream();
    _isListening = false;
    _turns.clear();
    _liveTranscript.add(null);
  }

  Future<void> saveSessionToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final session = InterviewSession(
      id: FirebaseFirestore.instance.collection('interviewSessions').doc().id,
      userId: uid,
      turns: _turns,
      startedAt: _startedAt,
      updatedAt: DateTime.now(),
    );
    await FirebaseFirestore.instance
        .collection('interviewSessions')
        .doc(session.id)
        .set(session.toJson());
  }

  /// Save a realtime voice session with meta and write each turn
  /// to a subcollection interviewSessions/{id}/turns/{autoId}.
  /// If [uploadJson] is true, also uploads a JSON transcript via TranscriptRecorder.
  static Future<String> saveVoiceSession({
    required String model,
    required String voice,
    required DateTime startedAt,
    required DateTime endedAt,
    required List<Map<String, dynamic>> turns, // { role, text, ts: DateTime }
    bool uploadJson = true,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final docRef = FirebaseFirestore.instance.collection('interviewSessions').doc();
    final dur = endedAt.difference(startedAt).inSeconds;
    await docRef.set({
      'userId': uid,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'durationSec': dur,
      'model': model,
      'voice': voice,
      'createdAt': FieldValue.serverTimestamp(),
      'mode': 'realtime',
    });

    final batch = FirebaseFirestore.instance.batch();
    final col = docRef.collection('turns');
    for (final t in turns) {
      final role = (t['role'] as String?) ?? 'assistant';
      final text = (t['text'] as String?) ?? '';
      final ts = (t['ts'] is DateTime)
          ? Timestamp.fromDate(t['ts'] as DateTime)
          : (t['ts'] is Timestamp ? t['ts'] as Timestamp : Timestamp.now());
      final doc = col.doc();
      batch.set(doc, {
        'role': role,
        'text': text,
        'ts': ts,
      });
    }
    await batch.commit();

    if (uploadJson) {
      try {
        // Reuse TranscriptRecorder if available; otherwise no-op
        // Import is at top of file in earlier patch
        // ignore: unnecessary_cast
        await TranscriptRecorder.instance.uploadJson(sessionId: docRef.id);
      } catch (_) {}
    }

    return docRef.id;
  }

  void dispose() {
    _cancelStream();
    _liveTranscript.close();
  }

  void _cancelStream() {
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
  }

  String _getNextPrompt() {
    const prompts = [
      'Tell me about your room.',
      'What time of day do you use it?',
      'Describe your style in 3 words.',
      'Any colors you dislike?',
    ];
    final asked = _turns.where((t) => !t.isUser).length;
    return prompts[asked % prompts.length];
  }

  void _log(String event, [Map<String, dynamic>? props]) {
    final fn = onAnalytics;
    if (fn != null) fn(event, props ?? const {});
  }
}
