// lib/services/voice_assistant.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// Simple voice layer that powers "AI Talk" mode: Listen → Think → Speak.
class VoiceAssistant extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _listening = false;
  bool get isListening => _listening;
  bool _speaking = false;
  bool get isSpeaking => _speaking;
  bool _available = false;
  bool get isAvailable => _available;

  Future<void> init() async {
    _available = await _speech.initialize(
      onStatus: (s) => debugPrint('STT status: $s'),
      onError: (e) => debugPrint('STT error: $e'),
    );

    await _tts.setSpeechRate(0.96);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    notifyListeners();
  }

  Future<String?> listenOnce({Duration timeout = const Duration(seconds: 8)}) async {
    if (!_available) return null;
    _listening = true; notifyListeners();

    final completer = Completer<String?>();
    String last = '';

    await _speech.listen(
      listenMode: stt.ListenMode.dictation,
      onResult: (res) {
        last = res.recognizedWords;
        if (res.finalResult) {
          completer.tryComplete(last.trim().isEmpty ? null : last.trim());
        }
      },
    );

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(last.trim().isEmpty ? null : last.trim());
      }
    });

    final text = await completer.future;
    await _speech.stop();
    _listening = false; notifyListeners();
    return text;
  }

  Future<void> speak(String text) async {
    _speaking = true; notifyListeners();
    await _tts.stop();
    await _tts.speak(text);
    await _tts.awaitSpeakCompletion(true);
    _speaking = false; notifyListeners();
  }

  Future<void> stop() async {
    await _speech.stop();
    await _tts.stop();
    _listening = false; _speaking = false; notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await stop();
    super.dispose();
  }
}
