// lib/services/interview_shared_engine.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/models/interview_turn.dart';
import 'package:color_canvas/models/interview_session.dart';

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
    _turns.add(InterviewTurn(text: _getNextPrompt(), isUser: false));
  }

  Future<String> submitTextAnswer(String userText) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final response = _getNextPrompt();
    _turns.addAll([
      InterviewTurn(text: userText, isUser: true),
      InterviewTurn(text: response, isUser: false),
    ]);
    _log('submit_text_answer', {'chars': userText.length});
    return response;
  }

  // Voice mode
  void startVoiceMode() {
    _log('start_voice_mode');
    _turns.clear();
    _startedAt = DateTime.now();
    _turns.add(InterviewTurn(text: _getNextPrompt(), isUser: false));
    _isListening = true;
    _sub?.cancel();
    _sub = Stream.periodic(const Duration(milliseconds: 300), (i) => 'Partial response $i')
        .take(5)
        .map((s) => s as String?)
        .listen((text) => _liveTranscript.add(text));
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
