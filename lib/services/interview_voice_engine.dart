// lib/services/interview_voice_engine.dart
import 'dart:async';

import 'package:color_canvas/models/interview_turn.dart';

/// Placeholder interview engine supporting both voice and text modes.
class InterviewEngine {
  InterviewEngine._internal();
  static final InterviewEngine _instance = InterviewEngine._internal();
  factory InterviewEngine() => _instance;

  final _controller = StreamController<String?>.broadcast();
  Stream<String?> get liveTranscriptStream => _controller.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  final List<String> _prompts = [
    'Tell me about your space',
    'What mood are you hoping to create?',
    'Any colors you love or hate?'
  ];

  String currentPrompt = 'Tell me about your space';
  int _promptIndex = 0;

  Timer? _timer;

  /// Start listening for voice input.
  void startVoiceMode() {
    _isListening = true;
    _timer?.cancel();
    // Simulate transcript updates for demo purposes.
    _timer = Timer.periodic(const Duration(seconds: 3), (t) {
      _controller.add('Sample response ${t.tick}');
    });
  }

  /// Initialize text interview mode.
  void startTextMode() {
    _promptIndex = 0;
    currentPrompt = _prompts[_promptIndex];
  }

  /// Initial turns to seed the chat UI.
  List<InterviewTurn> get initialTurns =>
      [InterviewTurn(text: currentPrompt, isUser: false)];

  /// Submit a user answer and receive Via's next prompt.
  Future<String> submitTextAnswer(String answer) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _promptIndex++;
    if (_promptIndex < _prompts.length) {
      currentPrompt = _prompts[_promptIndex];
      return currentPrompt;
    }
    return 'Thanks for sharing!';
  }

  /// Pause voice capture.
  void pause() {
    _isListening = false;
    _timer?.cancel();
    _controller.add(null);
  }

  /// End the interview session and clean up.
  void endSession() {
    _timer?.cancel();
    _isListening = false;
    _controller.add(null);
  }
}
