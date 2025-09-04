// lib/services/interview_voice_engine.dart
import 'dart:async';

/// Placeholder voice interview engine that exposes a live transcript stream.
class InterviewEngine {
  InterviewEngine._internal();
  static final InterviewEngine _instance = InterviewEngine._internal();
  factory InterviewEngine() => _instance;

  final _controller = StreamController<String?>.broadcast();
  Stream<String?> get liveTranscriptStream => _controller.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  String currentPrompt = 'Tell me about your space';

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
