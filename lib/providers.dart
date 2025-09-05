import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/services/firebase_service.dart';

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseService.authStateChanges;
});
