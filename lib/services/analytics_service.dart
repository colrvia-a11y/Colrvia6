import 'dart:developer' as dev;

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    try {
      dev.log('analytics:$name', name: 'analytics', error: null, stackTrace: null, sequenceNumber: null, time: DateTime.now(), zone: null);
      // Hook real analytics here later (Firebase, Segment, etc.)
    } catch (_) {
      // swallow
    }
  }
}

