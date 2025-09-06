import 'dart:io';
import 'package:flutter/services.dart';

/// Best-effort iOS audio session configuration for voice chat.
/// Safe no-op on non-iOS platforms or when the method channel is unimplemented.
Future<void> configureAudioSessionForVoiceChat() async {
  if (!Platform.isIOS) return;
  const channel = MethodChannel('audio_session');
  try {
    await channel.invokeMethod('configure', {
      'category': 'playAndRecord',
      'mode': 'voiceChat',
      'options': <String>['defaultToSpeaker', 'allowBluetooth'],
    });
  } catch (_) {
    // Ignore if platform side is not implemented; mic capture will still work.
  }
}

