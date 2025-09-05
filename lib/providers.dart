import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseService.authStateChanges;
});

final userPalettesProvider = FutureProvider<List<UserPalette>>((ref) async {
  final user = FirebaseService.currentUser;
  if (user == null) return [];
  return FirebaseService.getUserPalettes(user.uid);
});

final favoriteColorsProvider =
    FutureProvider<List<Paint>>((ref) async {
  final user = FirebaseService.currentUser;
  if (user == null) return [];
  return FirebaseService.getUserFavoriteColors(user.uid);
});
