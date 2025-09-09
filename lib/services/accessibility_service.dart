import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_service.dart';

/// Service to detect platform accessibility settings like reduce motion
class AccessibilityService extends ChangeNotifier {
  static AccessibilityService? _instance;
  static AccessibilityService get instance =>
      _instance ??= AccessibilityService._internal();

  AccessibilityService._internal();

  /// Platform-specific method channel for accessibility detection
  static const MethodChannel _channel =
      MethodChannel('com.colorcanvas.accessibility');

  bool _reduceMotionCache = false;
  bool _hasQueriedReduceMotion = false;
  bool _reduceMotion = false;
  bool _cbFriendly = false;
  bool _loaded = false;

  /// Check if reduce motion is enabled at the OS level
  Future<bool> isReduceMotionEnabled() async {
    if (_hasQueriedReduceMotion) {
      return _reduceMotionCache;
    }

    try {
      // Try to get the OS-level reduce motion setting
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, we can check for reduce motion
        final result =
            await _channel.invokeMethod<bool>('isReduceMotionEnabled');
        _reduceMotionCache = result ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, check for animation scale settings
        final result = await _channel.invokeMethod<bool>('isAnimationDisabled');
        _reduceMotionCache = result ?? false;
      } else {
        // For web and other platforms, fall back to media query
        _reduceMotionCache = await _checkWebReduceMotion();
      }

      _hasQueriedReduceMotion = true;
      debugPrint('🎭 Reduce motion detected: $_reduceMotionCache');
    } catch (e) {
      // If platform channel fails, assume false
      debugPrint('🎭 Failed to detect reduce motion, defaulting to false: $e');
      _reduceMotionCache = false;
      _hasQueriedReduceMotion = true;
    }

    return _reduceMotionCache;
  }

  /// Check for reduce motion on web platforms using media query
  Future<bool> _checkWebReduceMotion() async {
    if (kIsWeb) {
      try {
        // Try to use the web-specific approach to detect prefers-reduced-motion
        // This would need to be implemented with dart:html or js interop
        return false; // Default to false for now
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Clear the cache to force a fresh check next time
  void clearCache() {
    _hasQueriedReduceMotion = false;
    _reduceMotionCache = false;
  }

  /// Check if animations should be reduced based on both OS and user preferences
  bool shouldReduceMotion({bool? userPreference}) {
    if (!_loaded) return userPreference ?? _reduceMotionCache;
    return userPreference ?? _reduceMotion;
  }

  bool get reduceMotion => _loaded ? _reduceMotion : _reduceMotionCache;
  bool get cbFriendlyEnabled => _cbFriendly;

  Future<void> load() async {
    if (_loaded) return;
    final osReduce = await isReduceMotionEnabled();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('a11y')
          .get();
      final data = doc.data();
      _reduceMotion = data?['reduceMotion'] ?? osReduce;
      _cbFriendly = data?['cbFriendly'] ?? false;
    } else {
      _reduceMotion = osReduce;
      _cbFriendly = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    _loaded = true;
    notifyListeners();
    await _persist();
    AnalyticsService.instance.logEvent(
        'accessibility_setting_changed', {'name': 'reduce_motion', 'value': value});
  }

  Future<void> setCbFriendly(bool value) async {
    _cbFriendly = value;
    _loaded = true;
    notifyListeners();
    await _persist();
    AnalyticsService.instance.logEvent(
        'accessibility_setting_changed', {'name': 'cb_friendly', 'value': value});
  }

  Future<void> _persist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('a11y')
        .set({
      'reduceMotion': _reduceMotion,
      'cbFriendly': _cbFriendly,
    }, SetOptions(merge: true));
  }
}
