// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  Future<User> ensureSignedIn() async {
    final cur = _auth.currentUser;
    if (cur != null) return cur;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  String? get uid => _auth.currentUser?.uid;
}
