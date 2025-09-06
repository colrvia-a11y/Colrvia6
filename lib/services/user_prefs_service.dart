import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Value class for stored user preferences.
class UserPrefs {
  final bool firstRunCompleted;
  final String? lastOpenedProjectId;
  final String? lastVisitedScreen;
  final bool rollerHintShown;
  // Voice & labs
  final String voiceModel; // e.g., gpt-realtime-nano
  final String voiceVoice; // e.g., alloy
  final int voiceDailyCapMinutes; // e.g., 60
  final bool featureVoiceInterview; // user toggle to show/hide voice UI

  UserPrefs({
    required this.firstRunCompleted,
    this.lastOpenedProjectId,
    this.lastVisitedScreen,
    this.rollerHintShown = false,
    this.voiceModel = 'gpt-realtime-nano',
    this.voiceVoice = 'alloy',
    this.voiceDailyCapMinutes = 60,
    this.featureVoiceInterview = true,
  });

  factory UserPrefs.fromMap(Map<String, dynamic>? data) {
    return UserPrefs(
      firstRunCompleted: data?['firstRunCompleted'] == true,
      lastOpenedProjectId: data?['lastOpenedProjectId'] as String?,
      lastVisitedScreen: data?['lastVisitedScreen'] as String?,
      rollerHintShown: data?['rollerHintShown'] == true,
      voiceModel: (data?['voice']?['model'] as String?) ?? 'gpt-realtime-nano',
      voiceVoice: (data?['voice']?['voice'] as String?) ?? 'alloy',
      voiceDailyCapMinutes: (data?['voice']?['dailyCapMinutes'] as int?) ?? 60,
      featureVoiceInterview: (data?['features']?['voiceInterview'] as bool?) ?? true,
    );
  }
}

/// Service to persist user-level preferences like onboarding state and last visited project.
class UserPrefsService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('meta').doc('prefs');
  }

  /// Fetch the current user's preferences. Returns default values if none exist.
  static Future<UserPrefs> fetch() async {
    final doc = await _doc?.get();
    return UserPrefs.fromMap(doc?.data());
  }

  /// Persist the last opened project and screen, marking onboarding as complete.
  static Future<void> setLastProject(String projectId, String screen) async {
    final doc = _doc;
    if (doc != null) {
      await doc.set({
        'firstRunCompleted': true,
        'lastOpenedProjectId': projectId,
        'lastVisitedScreen': screen,
      }, SetOptions(merge: true));
    }
  }

  /// Mark onboarding as completed without updating project info.
  static Future<void> markFirstRunCompleted() async {
    final doc = _doc;
    if (doc != null) {
      await doc.set({'firstRunCompleted': true}, SetOptions(merge: true));
    }
  }

  /// Mark the Roller hint as shown so it won't appear again.
  static Future<void> markRollerHintShown() async {
    final doc = _doc;
    if (doc != null) {
      await doc.set({'rollerHintShown': true}, SetOptions(merge: true));
    }
  }

  // Convenience static mutators used by Labs UI (and elsewhere)
  static Future<void> setVoicePrefs({String? model, String? voice, int? dailyCapMinutes}) async {
    final doc = _doc;
    if (doc != null) {
      await doc.set({
        'voice': {
          if (model != null) 'model': model,
          if (voice != null) 'voice': voice,
          if (dailyCapMinutes != null) 'dailyCapMinutes': dailyCapMinutes,
        }
      }, SetOptions(merge: true));
    }
  }

  static Future<void> setFeatureVoiceInterview(bool enabled) async {
    final doc = _doc;
    if (doc != null) {
      await doc.set({
        'features': {'voiceInterview': enabled}
      }, SetOptions(merge: true));
    }
  }
}

extension UserPrefsMutators on UserPrefsService {
  static Future<void> setVoicePrefs({String? model, String? voice, int? dailyCapMinutes}) async {
    final doc = UserPrefsService._doc;
    if (doc != null) {
      await doc.set({
        'voice': {
          if (model != null) 'model': model,
          if (voice != null) 'voice': voice,
          if (dailyCapMinutes != null) 'dailyCapMinutes': dailyCapMinutes,
        }
      }, SetOptions(merge: true));
    }
  }

  static Future<void> setFeatureVoiceInterview(bool enabled) async {
    final doc = UserPrefsService._doc;
    if (doc != null) {
      await doc.set({
        'features': {'voiceInterview': enabled}
      }, SetOptions(merge: true));
    }
  }
}

