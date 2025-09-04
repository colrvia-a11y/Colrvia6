import 'package:flutter/foundation.dart';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  static DebugLogger get instance => _instance;

  // Track setState calls across the app
  final Map<String, int> _setStateCounts = {};
  final Map<String, DateTime> _lastSetStateTimes = {};

  // Track build calls
  final Map<String, int> _buildCounts = {};
  final Map<String, DateTime> _lastBuildTimes = {};

  // Track MediaQuery calls
  final Map<String, int> _mediaQueryCounts = {};

  // Track addPostFrameCallback calls
  final Map<String, int> _postFrameCallbackCounts = {};

  bool _enabled = kDebugMode;

  void enable() => _enabled = true;
  void disable() => _enabled = false;

  void logSetState(String widgetName, String location, {String? details}) {
    if (!_enabled) return;

    final key = '$widgetName:$location';
    final now = DateTime.now();

    _setStateCounts[key] = (_setStateCounts[key] ?? 0) + 1;
    final count = _setStateCounts[key]!;

    // Check for rapid setState calls
    if (_lastSetStateTimes[key] != null) {
      final timeDiff = now.difference(_lastSetStateTimes[key]!).inMilliseconds;
      if (timeDiff < 16 && count > 10) {
        debugPrint('🚨 RAPID SETSTATE DETECTED: $widgetName at $location');
        debugPrint('   Count: $count calls in ${timeDiff}ms');
        if (details != null) debugPrint('   Details: $details');
      }
    }

    _lastSetStateTimes[key] = now;

    // Log every 50th setState call
    if (count % 50 == 0) {
      debugPrint(
          '📊 setState Stats: $widgetName at $location has called setState $count times');
    }
  }

  void logBuild(String widgetName, String location, {String? details}) {
    if (!_enabled) return;

    final key = '$widgetName:$location';
    final now = DateTime.now();

    _buildCounts[key] = (_buildCounts[key] ?? 0) + 1;
    final count = _buildCounts[key]!;

    // Check for rapid builds
    if (_lastBuildTimes[key] != null) {
      final timeDiff = now.difference(_lastBuildTimes[key]!).inMilliseconds;
      if (timeDiff < 16 && count > 10) {
        debugPrint('🚨 RAPID BUILD DETECTED: $widgetName at $location');
        debugPrint('   Count: $count builds in ${timeDiff}ms');
        if (details != null) debugPrint('   Details: $details');
      }
    }

    _lastBuildTimes[key] = now;

    // Log every 100th build call
    if (count % 100 == 0) {
      debugPrint(
          '🔨 Build Stats: $widgetName at $location has built $count times');
    }
  }

  void logMediaQuery(String widgetName, String location, String property) {
    if (!_enabled) return;

    final key = '$widgetName:$location:$property';
    _mediaQueryCounts[key] = (_mediaQueryCounts[key] ?? 0) + 1;
    final count = _mediaQueryCounts[key]!;

    if (count > 100) {
      debugPrint(
          '📱 MediaQuery Overuse: $widgetName at $location accessing $property $count times');
    }
  }

  void logPostFrameCallback(String widgetName, String location,
      {String? details}) {
    if (!_enabled) return;

    final key = '$widgetName:$location';
    _postFrameCallbackCounts[key] = (_postFrameCallbackCounts[key] ?? 0) + 1;
    final count = _postFrameCallbackCounts[key]!;

    if (count > 50) {
      debugPrint(
          '⏰ PostFrameCallback Overuse: $widgetName at $location called $count times');
      if (details != null) debugPrint('   Details: $details');
    }
  }

  void logError(String widgetName, String location, String error,
      {String? stackTrace}) {
    if (!_enabled) return;

    debugPrint('❌ ERROR in $widgetName at $location: $error');
    if (stackTrace != null) {
      debugPrint('   Stack: ${stackTrace.split('\n').take(3).join(' -> ')}');
    }
  }

  void logWarning(String widgetName, String location, String warning) {
    if (!_enabled) return;

    debugPrint('⚠️  WARNING in $widgetName at $location: $warning');
  }

  void logInfo(String widgetName, String location, String info) {
    if (!_enabled) return;

    debugPrint('ℹ️  INFO in $widgetName at $location: $info');
  }

  void printSummary() {
    if (!_enabled) return;

    debugPrint('📈 DEBUG SUMMARY:');

    debugPrint('🔄 Top setState Callers:');
    final sortedSetState = _setStateCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedSetState.take(10)) {
      debugPrint('   ${entry.key}: ${entry.value} calls');
    }

    debugPrint('🔨 Top Build Callers:');
    final sortedBuilds = _buildCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedBuilds.take(10)) {
      debugPrint('   ${entry.key}: ${entry.value} builds');
    }

    debugPrint('📱 MediaQuery Usage:');
    final sortedMediaQuery = _mediaQueryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedMediaQuery.take(5)) {
      debugPrint('   ${entry.key}: ${entry.value} accesses');
    }
  }

  void reset() {
    _setStateCounts.clear();
    _lastSetStateTimes.clear();
    _buildCounts.clear();
    _lastBuildTimes.clear();
    _mediaQueryCounts.clear();
    _postFrameCallbackCounts.clear();
  }
}

// Convenient static methods
class Debug {
  static void setState(String widgetName, String location, {String? details}) {
    DebugLogger.instance.logSetState(widgetName, location, details: details);
  }

  static void build(String widgetName, String location, {String? details}) {
    DebugLogger.instance.logBuild(widgetName, location, details: details);
  }

  static void mediaQuery(String widgetName, String location, String property) {
    DebugLogger.instance.logMediaQuery(widgetName, location, property);
  }

  static void postFrameCallback(String widgetName, String location,
      {String? details}) {
    DebugLogger.instance
        .logPostFrameCallback(widgetName, location, details: details);
  }

  static void error(String widgetName, String location, String error,
      {String? stackTrace}) {
    DebugLogger.instance
        .logError(widgetName, location, error, stackTrace: stackTrace);
  }

  static void warning(String widgetName, String location, String warning) {
    DebugLogger.instance.logWarning(widgetName, location, warning);
  }

  static void info(String widgetName, String location, String info) {
    DebugLogger.instance.logInfo(widgetName, location, info);
  }

  static void summary() {
    DebugLogger.instance.printSummary();
  }

  static void reset() {
    DebugLogger.instance.reset();
  }
}
