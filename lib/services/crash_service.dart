// lib/services/crash_service.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashService {
  CrashService._();
  static final instance = CrashService._();
  final _c = FirebaseCrashlytics.instance;

  Future<void> setUser(String? uid) async {
    if (uid != null) await _c.setUserIdentifier(uid);
  }

  Future<void> breadcrumb(String msg) async {
    await _c.log(msg);
  }

  Future<void> recordError(Object e, StackTrace s, {bool fatal = false}) async {
    await _c.recordError(e, s, fatal: fatal);
  }
}
