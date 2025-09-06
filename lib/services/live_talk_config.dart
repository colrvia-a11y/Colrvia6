import 'package:flutter/foundation.dart';

/// Configuration for LiveTalk signaling endpoints.
/// Defaults to the OpenAI Realtime endpoints, but allows a dev override to a
/// local gateway (e.g., http/ws to 10.0.2.2) when building for development.
class LiveTalkConfig {
  // Compile-time toggles (set via --dart-define) or fall back to defaults.
  static const bool useLocalSignaling = bool.fromEnvironment('USE_LOCAL_SIGNALING', defaultValue: false);
  static const String localHost = String.fromEnvironment('LOCAL_SIGNALING_HOST', defaultValue: '10.0.2.2');
  static const int localPort = int.fromEnvironment('LOCAL_SIGNALING_PORT', defaultValue: 8080);

  // If you run a production reverse proxy (e.g., talk.colrvia.com), set this via dart-define.
  static const String prodHost = String.fromEnvironment('PROD_SIGNALING_HOST', defaultValue: 'api.openai.com');

  static Uri webrtcAnswerUrl({required String model}) {
    if (!kReleaseMode && useLocalSignaling) {
      return Uri.parse('http://$localHost:$localPort/v1/realtime?model=$model');
    }
    return Uri.parse('https://$prodHost/v1/realtime?model=$model');
  }

  static Uri wsRealtimeUrl({required String model}) {
    if (!kReleaseMode && useLocalSignaling) {
      return Uri.parse('ws://$localHost:$localPort/v1/realtime?model=$model');
    }
    return Uri.parse('wss://$prodHost/v1/realtime?model=$model');
  }
}

