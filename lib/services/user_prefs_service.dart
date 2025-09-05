import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Value class for stored user preferences.
class UserPrefs {
  final bool firstRunCompleted;
  final String? lastOpenedProjectId;
  final String? lastVisitedScreen;
  final bool rollerHintShown;

  UserPrefs({
    required this.firstRunCompleted,
    this.lastOpenedProjectId,
    this.lastVisitedScreen,
    this.rollerHintShown = false,
  });

  factory UserPrefs.fromMap(Map<String, dynamic>? data) {
    return UserPrefs(
      firstRunCompleted: data?['firstRunCompleted'] == true,
      lastOpenedProjectId: data?['lastOpenedProjectId'] as String?,
      lastVisitedScreen: data?['lastVisitedScreen'] as String?,
      rollerHintShown: data?['rollerHintShown'] == true,
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
}

