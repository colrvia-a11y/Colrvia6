// lib/services/privacy_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class PrivacyPrefs {
  static const _kAnalytics = 'analytics_enabled';

  static Future<bool> analyticsEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAnalytics) ?? true;
  }

  static Future<void> setAnalytics(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAnalytics, enabled);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }
}
