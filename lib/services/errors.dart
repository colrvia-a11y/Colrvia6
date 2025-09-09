/// Error codes representing common voice session failures.
enum LiveTalkErrorCode {
  micPermission,
  tokenEndpoint,
  invalidToken,
  negotiationTimeout,
  webrtcFailure,
  wsClosed,
  network,
  notSignedIn,
  unknown,
}

/// Container for last error with optional details payload.
class LiveTalkError {
  LiveTalkError(this.code, {this.details});
  final LiveTalkErrorCode code;
  final Object? details;
}

class LiveTalkErrorMessages {
  /// Short, user‑friendly title for UI surfaces.
  static String title(LiveTalkError e) {
    switch (e.code) {
      case LiveTalkErrorCode.micPermission:
        return 'Microphone access is blocked';
      case LiveTalkErrorCode.tokenEndpoint:
      case LiveTalkErrorCode.invalidToken:
        return 'Couldn\'t start the voice session';
      case LiveTalkErrorCode.negotiationTimeout:
        return 'We\'re having trouble connecting';
      case LiveTalkErrorCode.webrtcFailure:
        return 'Voice call failed to start';
      case LiveTalkErrorCode.wsClosed:
        return 'Connection dropped';
      case LiveTalkErrorCode.network:
        return 'Network issue';
      case LiveTalkErrorCode.notSignedIn:
        return 'Please sign in to continue';
      case LiveTalkErrorCode.unknown:
        return 'Something went wrong';
    }
  }

  /// Supportive, actionable description for the user.
  static String description(LiveTalkError e) {
    switch (e.code) {
      case LiveTalkErrorCode.micPermission:
        return 'Via needs access to your microphone. Enable mic permission and try again.';
      case LiveTalkErrorCode.tokenEndpoint:
      case LiveTalkErrorCode.invalidToken:
        return 'Our token service didn\'t respond. Please try again in a moment.';
      case LiveTalkErrorCode.negotiationTimeout:
        return 'We\'ll retry and can fall back to a more compatible connection.';
      case LiveTalkErrorCode.webrtcFailure:
        return 'WebRTC failed. We\'ll try a fallback connection automatically.';
      case LiveTalkErrorCode.wsClosed:
        return 'We\'re reconnecting. You can also retry now.';
      case LiveTalkErrorCode.network:
        return 'Looks like a network hiccup. Check your connection and retry.';
      case LiveTalkErrorCode.notSignedIn:
        return 'Sign in again, then retry starting the call.';
      case LiveTalkErrorCode.unknown:
        return 'Please retry. If this keeps happening, try again later.';
    }
  }

  /// Whether showing an extra action to open app settings makes sense.
  static bool showOpenSettings(LiveTalkError e) =>
      e.code == LiveTalkErrorCode.micPermission;
}
