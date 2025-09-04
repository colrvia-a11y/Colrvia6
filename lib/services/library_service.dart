import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';

class LibraryService {
  LibraryService._();

  static Future<bool> isSaved(String paintId) async {
    final user = FirebaseService.currentUser;
    if (user == null) return false;
    return FirebaseService.isPaintFavorited(paintId, user.uid);
  }

  static Future<void> saveColor(Paint paint) async {
    final user = FirebaseService.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    await FirebaseService.addFavoritePaintWithData(user.uid, paint);
  }

  static Future<void> removeColor(String paintId) async {
    final user = FirebaseService.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    // Use the variant that infers current user from FirebaseService
    await FirebaseService.removeFavoritePaint(paintId);
  }
}
