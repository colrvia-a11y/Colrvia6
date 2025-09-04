import 'dart:async';
import 'dart:math';

/// Simple audio service that exposes a microphone level stream.
///
/// This implementation simulates microphone input by emitting random
/// levels between 0 and 1. Replace with real audio processing as needed.
class AudioService {
  AudioService._internal();
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final _controller = StreamController<double>.broadcast();
  Stream<double> get micLevelStream => _controller.stream;

  Timer? _timer;
  final _rand = Random();

  /// Start generating microphone level updates.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _controller.add(_rand.nextDouble());
    });
  }

  /// Stop generating microphone level updates.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
