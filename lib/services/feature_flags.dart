import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

class FeatureFlags {
  FeatureFlags._();
  static final FeatureFlags instance = FeatureFlags._();

  static const viaMvp = 'via_mvp';
  static const voiceInterview = 'voiceInterview';
  static const lightingProfiles = 'lighting_profiles';
  static const fixedElementAssist = 'fixed_element_assist';
  static const maskAssist = 'mask_assist';

  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;
  final Map<String, bool> _cache = {};

  Future<void> init() async {
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _rc.setDefaults({
        viaMvp: kDebugMode,
        voiceInterview: kDebugMode, // default true on dev, can be disabled in prod
        lightingProfiles: kDebugMode,
        fixedElementAssist: kDebugMode,
        maskAssist: kDebugMode,
      });
      await _rc.fetchAndActivate();
    } catch (_) {
      // Use defaults on failure
    }
    _updateCache();
    _logStates();
    _rc.onConfigUpdated.listen((_) async {
      await _rc.activate();
      _updateCache();
      _logStates();
    });
  }

  bool isEnabled(String key) => _cache[key] ?? kDebugMode;

  Map<String, bool> get flagStates => Map.unmodifiable(_cache);

  void _updateCache() {
    for (final key in [viaMvp, voiceInterview, lightingProfiles, fixedElementAssist, maskAssist]) {
      _cache[key] = _rc.getBool(key);
    }
  }

  void _logStates() {
    _cache.forEach((flag, enabled) {
      AnalyticsService.instance.featureFlagState(flag, enabled);
    });
  }
}
