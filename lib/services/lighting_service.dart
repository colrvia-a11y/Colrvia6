import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/lighting_profile.dart';
import 'analytics_service.dart';

/// Service for persisting lighting profile settings per project.
class LightingService {
  static final LightingService _instance = LightingService._();
  factory LightingService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  LightingService._();

  DocumentReference<Map<String, dynamic>> _settingsDoc(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('meta')
      .doc('settings');

  /// Reads the lighting profile for the given project. Defaults to [LightingProfile.mixed].
  Future<LightingProfile> getProfile(String projectId) async {
    try {
      final snap = await _settingsDoc(projectId).get();
      final value = snap.data()?['lightingProfile'] as String?;
      return lightingProfileFromString(value);
    } catch (_) {
      return LightingProfile.mixed;
    }
  }

  /// Persists the lighting profile and logs telemetry.
  Future<void> setProfile(String projectId, LightingProfile profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return; // fail silently if not signed in
    await _settingsDoc(projectId)
        .set({'lightingProfile': profile.name}, SetOptions(merge: true));
    AnalyticsService.instance
        .logEvent('lighting_profile_selected', {'profile': profile.name});
  }
}
