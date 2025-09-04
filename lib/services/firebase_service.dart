import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';


import 'dart:async';
import '../models/color_story.dart' as model;
import '../firestore/firestore_data_schema.dart';
import '../data/sample_paints.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Stream<model.ColorStory> storyStream(String id) {
    debugPrint('🐛 FirebaseService: Creating story stream for ID = $id');
    debugPrint(
        '🐛 FirebaseService: TEMPORARILY BYPASSING AUTH STATE - making direct query');

    // TEMPORARILY BYPASS auth state waiting for debugging
    return _db.collection('colorStories').doc(id).snapshots().map((s) {
      debugPrint('🐛 FirebaseService: Story document exists = ${s.exists}');
      debugPrint(
          '🐛 FirebaseService: Current user at query time = ${currentUser?.uid}');

      if (s.exists) {
        final data = s.data() ?? {};
        debugPrint(
            '🐛 FirebaseService: Story document data keys = ${data.keys.toList()}');
        if (data.isNotEmpty) {
          debugPrint('🐛 FirebaseService: Story status = ${data['status']}');
          debugPrint(
              '🐛 FirebaseService: Story progress = ${data['progress']}');
          debugPrint(
              '🐛 FirebaseService: Story narration length = ${(data['narration'] ?? '').length}');
          debugPrint(
              '🐛 FirebaseService: Story ownerId = ${data['ownerId']}, current user = ${currentUser?.uid}');
          debugPrint('🐛 FirebaseService: Story access = ${data['access']}');
        }

        return model.ColorStory.fromSnap(s.id, data);
      } else {
        debugPrint('🐛 FirebaseService: Document not found');
        throw Exception('Story not found');
      }
    });
  }

  static Future<model.ColorStory?> getColorStory(String id) async {
    try {
      debugPrint('🐛 FirebaseService: Getting color story $id');
      debugPrint('🐛 FirebaseService: Current user = ${currentUser?.uid}');

      final doc = await _db.collection('colorStories').doc(id).get();
      debugPrint('🐛 FirebaseService: Document exists = ${doc.exists}');

      if (!doc.exists) return null;

      final data = doc.data() ?? {};
      debugPrint('🐛 FirebaseService: Document ownerId = ${data['ownerId']}');
      debugPrint('🐛 FirebaseService: Document access = ${data['access']}');

      return model.ColorStory.fromSnap(doc.id, data);
    } catch (e) {
      debugPrint('🐛 FirebaseService: Error loading color story $id: $e');
      return null;
    }
  }

  static Future<void> toggleColorStoryLike(String storyId, String uid) async {
    final likeId = '${storyId}_$uid';
    final likeRef = _db.collection('colorStoryLikes').doc(likeId);
    final snap = await likeRef.get();
    if (snap.exists) {
      await likeRef.delete();
      await _db
          .collection('colorStories')
          .doc(storyId)
          .update({'likeCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({
        'storyId': storyId,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp()
      });
      await _db
          .collection('colorStories')
          .doc(storyId)
          .update({'likeCount': FieldValue.increment(1)});
    }
  }

  static Future<bool> isColorStoryLiked(String storyId, String uid) async {
    final likeId = '${storyId}_$uid';
    final snap = await _db.collection('colorStoryLikes').doc(likeId).get();
    return snap.exists;
  }

  static Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(doc.data()!, uid);
  }

  static Future<DocumentSnapshot> getUserDocument(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }

  static Future<bool> checkAdminStatus(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  // Authentication methods
  static Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      debugPrint('🔐 FirebaseService: Attempting sign in for email: $email');
      debugPrint('🔐 FirebaseService: Auth instance app: ${_auth.app.name}');
      debugPrint('🔐 FirebaseService: Project ID: ${_auth.app.options.projectId}');
      
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      debugPrint('🔐 FirebaseService: Sign in successful for user: ${result.user?.uid}');
      FirebaseCrashlytics.instance
          .setUserIdentifier(result.user?.uid ?? '');
      return result;
    } catch (e) {
      debugPrint('🔐 FirebaseService: Sign in failed with error: $e');
      if (e.toString().contains('API key not valid')) {
        debugPrint('🔐 FirebaseService: API key issue detected. Check SHA-1 fingerprint in Firebase Console.');
        debugPrint('🔐 FirebaseService: Debug SHA-1: A4:DA:E3:7A:D1:EA:DA:3C:9C:E4:62:0F:53:CA:86:0A:E1:22:60:11');
      }
      rethrow;
    }
  }

  static Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      debugPrint('🔐 FirebaseService: Attempting user creation for email: $email');
      
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      debugPrint('🔐 FirebaseService: User creation successful for user: ${result.user?.uid}');
      FirebaseCrashlytics.instance
          .setUserIdentifier(result.user?.uid ?? '');
      
      return result;
    } catch (e) {
      debugPrint('🔐 FirebaseService: User creation failed with error: $e');
      if (e.toString().contains('API key not valid')) {
        debugPrint('🔐 FirebaseService: API key issue detected. Check SHA-1 fingerprint in Firebase Console.');
        debugPrint('🔐 FirebaseService: Debug SHA-1: A4:DA:E3:7A:D1:EA:DA:3C:9C:E4:62:0F:53:CA:86:0A:E1:22:60:11');
      }
      rethrow;
    }
  }

  static Future<void> createUserProfile(UserProfile profile) async {
    await _db.collection('users').doc(profile.id).set(profile.toJson());
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    return await checkAdminStatus(user.uid);
  }

  static Future<void> updateUserColorStoryPreferences({
    required String uid,
    required bool autoPlayStoryAudio,
    required bool reduceMotion,
    required bool wifiOnlyAssets,
    required String defaultStoryVisibility,
    String? ambientAudioMode,
  }) async {
    final updateData = <String, dynamic>{
      'autoPlayStoryAudio': autoPlayStoryAudio,
      'reduceMotion': reduceMotion,
      'wifiOnlyAssets': wifiOnlyAssets,
      'defaultStoryVisibility': defaultStoryVisibility,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add ambient audio mode if provided
    if (ambientAudioMode != null) {
      updateData['ambientAudioMode'] = ambientAudioMode;
    }

    await _db.collection('users').doc(uid).update(updateData);
  }

  static Future<void> updateAmbientAudioPreference({
    required String uid,
    required String ambientAudioMode,
  }) async {
    await _db.collection('users').doc(uid).update({
      'ambientAudioMode': ambientAudioMode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update color story visibility/access level
  static Future<void> updateColorStoryAccess({
    required String storyId,
    required String access, // 'private', 'unlisted', or 'public'
  }) async {
    await _db.collection('colorStories').doc(storyId).update({
      'access': access,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get spotlight color stories for featured rail
  static Future<List<model.ColorStory>> getSpotlightStories(
      {int limit = 12}) async {
    try {
      final snapshot = await _db
          .collection('colorStories')
          .where('spotlight', isEqualTo: true)
          .where('access', isEqualTo: 'public')
          .where('status', isEqualTo: 'complete')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => model.ColorStory.fromSnap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error loading spotlight stories: $e');
      return [];
    }
  }

  static Future<List<UserPalette>> getUserPalettes(String uid) async {
    final snapshot = await _db
        .collection('palettes')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => UserPalette.fromJson(doc.data(), doc.id))
        .toList();
  }

  static Future<Map<String, List<String>>> getTaxonomyOptions() async {
    try {
      final doc = await _db.collection('settings').doc('taxonomies').get();
      final data = doc.data() ?? {};
      return {
        'themes': List<String>.from(data['themes'] ?? []),
        'families': List<String>.from(data['families'] ?? []),
        'rooms': List<String>.from(data['rooms'] ?? []),
      };
    } catch (e) {
      // Return defaults if error
      return {
        'themes': [
          'coastal',
          'modern-farmhouse',
          'traditional',
          'contemporary'
        ],
        'families': ['neutrals', 'warm-neutrals', 'blues', 'greens'],
        'rooms': ['living', 'kitchen', 'bedroom', 'bathroom'],
      };
    }
  }

  // Additional methods called by other parts of the app
  static Future<List<Paint>> getAllPaints() async {
    final snapshot = await _db.collection('paints').get();
    return snapshot.docs
        .map((doc) => Paint.fromJson(doc.data(), doc.id))
        .toList();
  }

  static Future<List<Brand>> getAllBrands() async {
    final snapshot = await _db.collection('brands').get();
    return snapshot.docs
        .map((doc) => Brand.fromJson(doc.data(), doc.id))
        .toList();
  }

  static Future<List<Paint>> getPaintsByIds(List<String> paintIds) async {
    if (paintIds.isEmpty) return [];
    final snapshot = await _db
        .collection('paints')
        .where(FieldPath.documentId, whereIn: paintIds)
        .get();
    return snapshot.docs
        .map((doc) => Paint.fromJson(doc.data(), doc.id))
        .toList();
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<void> toggleAdminPrivileges(String uid, bool isAdmin) async {
    if (isAdmin) {
      await _db
          .collection('admins')
          .doc(uid)
          .set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _db.collection('admins').doc(uid).delete();
    }
  }

  static Future<void> enableOfflineSupport() async {
    try {
      // Enable offline persistence for Firestore (only on mobile platforms)
      if (!kIsWeb) {
        // On mobile platforms, persistence is enabled by default
        debugPrint('Firestore offline persistence is enabled by default on mobile');
      } else {
        debugPrint('Firestore offline persistence not available on web');
      }
    } catch (e) {
      // Persistence may already be enabled, or not supported on web
      debugPrint('Firestore persistence error (this is usually ok on web): $e');
    }
  }

  static Future<Map<String, dynamic>> getFirebaseStatus() async {
    final user = currentUser;
    final status = {
      'isAuthenticated': user != null,
      'userId': user?.uid,
      'userEmail': user?.email,
      'isFirestoreOnline': true, // Simplified - in real app would check connectivity
      'error': null,
      'projectId': _auth.app.options.projectId,
      'appId': _auth.app.options.appId,
      'apiKey': '${_auth.app.options.apiKey.substring(0, 20)}...',
    };

    // Test basic Firebase connectivity
    try {
      await _db.collection('_test').limit(1).get(const GetOptions(source: Source.server));
      status['firestoreConnected'] = true;
    } catch (e) {
      status['firestoreConnected'] = false;
      status['firestoreError'] = e.toString();
    }

    return status;
  }

  // Missing methods for library_screen.dart and palette_detail_screen.dart

  static Future<List<Paint>> getUserFavoriteColors(String uid) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('favoriteColors')
          .get();
      final paintIds = snapshot.docs.map((doc) => doc.id).toList();
      if (paintIds.isEmpty) return [];
      return await getPaintsByIds(paintIds);
    } catch (e) {
      return [];
    }
  }

  static Future<void> updatePalette(UserPalette palette) async {
    await _db.collection('palettes').doc(palette.id).update(palette.toJson());
  }

  static Future<void> removeFavoritePaint(String paintId) async {
    final user = currentUser;
    if (user != null) {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('favoriteColors')
          .doc(paintId)
          .delete();
    }
  }

  static Future<void> deletePalette(String paletteId) async {
    await _db.collection('palettes').doc(paletteId).delete();
  }

  static Future<UserPalette> savePalette({
    required String userId,
    required String name,
    required List<String> colors,
  }) async {
    final palette = UserPalette(
      id: '', // Will be set by Firestore
      userId: userId,
      name: name,
      colors: colors
          .asMap()
          .entries
          .map((entry) => PaletteColor(
                paintId: '',
                locked: false,
                position: entry.key,
                brand: '',
                name: 'Color ${entry.key + 1}',
                code: '',
                hex: entry.value,
              ))
          .toList(),
      tags: [],
      notes: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _db.collection('palettes').add(palette.toJson());
    return palette.copyWith(id: docRef.id);
  }

  static Future<Paint?> getPaintById(String paintId) async {
    try {
      final doc = await _db.collection('paints').doc(paintId).get();
      if (!doc.exists) return null;
      return Paint.fromJson(doc.data()!, doc.id);
    } catch (e) {
      return null;
    }
  }

  // Admin and search methods
  static Future<Map<String, dynamic>> getColorStoriesWithCursor({
    String? lastStoryId,
    int limit = 10,
  }) async {
    Query query =
        _db.collection('colorStories').orderBy('createdAt', descending: true);

    if (lastStoryId != null) {
      final lastDoc =
          await _db.collection('colorStories').doc(lastStoryId).get();
      if (lastDoc.exists) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    final snapshot = await query.limit(limit).get();
    final stories = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();

    return {
      'stories': stories,
      'lastId': stories.isNotEmpty ? stories.last['id'] : null,
      'hasMore': stories.length == limit,
    };
  }

  static Future<List<Map<String, dynamic>>>
      getAllColorStoriesForMaintenance() async {
    final snapshot = await _db.collection('colorStories').get();
    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  static Future<void> upgradeUserToPro(String uid) async {
    await _db.collection('users').doc(uid).update({
      'plan': 'pro',
      'upgradedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Paint>> searchPaints(String query) async {
    if (query.trim().isEmpty) return [];

    final lowercaseQuery = query.toLowerCase().trim();
    List<Paint> results = [];

    try {
      // Search by name (case insensitive prefix search)
      final nameSnapshot = await _db
          .collection('paints')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .limit(25)
          .get();

      results.addAll(
          nameSnapshot.docs.map((doc) => Paint.fromJson(doc.data(), doc.id)));

      // Search by brand name
      final brandSnapshot = await _db
          .collection('paints')
          .where('brandName', isGreaterThanOrEqualTo: query)
          .where('brandName', isLessThan: '${query}z')
          .limit(25)
          .get();

      results.addAll(
          brandSnapshot.docs.map((doc) => Paint.fromJson(doc.data(), doc.id)));

      // Search by color code
      final codeSnapshot = await _db
          .collection('paints')
          .where('code', isGreaterThanOrEqualTo: query.toUpperCase())
          .where('code', isLessThan: '${query.toUpperCase()}Z')
          .limit(25)
          .get();

      results.addAll(
          codeSnapshot.docs.map((doc) => Paint.fromJson(doc.data(), doc.id)));

      // Search by hex (if query looks like hex)
      if (query.startsWith('#') || RegExp(r'^[0-9A-Fa-f]+$').hasMatch(query)) {
        String hexQuery = query.startsWith('#')
            ? query.toUpperCase()
            : '#${query.toUpperCase()}';
        final hexSnapshot = await _db
            .collection('paints')
            .where('hex', isEqualTo: hexQuery)
            .limit(10)
            .get();

        results.addAll(
            hexSnapshot.docs.map((doc) => Paint.fromJson(doc.data(), doc.id)));
      }

      // Remove duplicates based on paint ID
      final seen = <String>{};
      results = results.where((paint) => seen.add(paint.id)).toList();

      // If no results from Firestore, search more broadly
      if (results.isEmpty) {
        // Try a broader name search with partial matching
        final broadSnapshot = await _db.collection('paints').limit(100).get();

        final allPaints =
            broadSnapshot.docs.map((doc) => Paint.fromJson(doc.data(), doc.id));
        results = allPaints
            .where((paint) {
              final name = paint.name.toLowerCase();
              final brand = paint.brandName.toLowerCase();
              final code = paint.code.toLowerCase();
              final hex = paint.hex.toLowerCase();

              return name.contains(lowercaseQuery) ||
                  brand.contains(lowercaseQuery) ||
                  code.contains(lowercaseQuery) ||
                  hex.contains(lowercaseQuery);
            })
            .take(50)
            .toList();
      }

      // If still no results from Firebase, fallback to local sample data
      if (results.isEmpty) {
        final samplePaints = await _searchSamplePaints(query);
        results = samplePaints;
      }

      return results.take(50).toList();
    } catch (e) {
      debugPrint('Firebase search error: $e, falling back to sample data');
      // Fallback to sample data search
      return await _searchSamplePaints(query);
    }
  }

  static Future<List<Paint>> _searchSamplePaints(String query) async {
    try {
      // Import here to avoid circular dependency
      final samplePaints = await SamplePaints.getAllPaints();
      final lowercaseQuery = query.toLowerCase().trim();

      return samplePaints
          .where((paint) {
            final name = paint.name.toLowerCase();
            final brand = paint.brandName.toLowerCase();
            final code = paint.code.toLowerCase();
            final hex = paint.hex.toLowerCase();

            return name.contains(lowercaseQuery) ||
                brand.contains(lowercaseQuery) ||
                code.contains(lowercaseQuery) ||
                hex.contains(lowercaseQuery);
          })
          .take(50)
          .toList();
    } catch (e) {
      debugPrint('Sample data search error: $e');
      return [];
    }
  }

  // Paint favorite methods
  static Future<bool> isPaintFavorited(String paintId, String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('favoriteColors')
        .doc(paintId)
        .get();
    return doc.exists;
  }

  static Future<void> addFavoritePaintWithData(String uid, Paint paint) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favoriteColors')
        .doc(paint.id)
        .set({
      'paintId': paint.id,
      'name': paint.name,
      'brandName': paint.brandName,
      'code': paint.code,
      'hex': paint.hex,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addFavoritePaint(String uid, String paintId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favoriteColors')
        .doc(paintId)
        .set({
      'paintId': paintId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // Note: use removeFavoritePaint(paintId) which infers the current user.

  static Future<void> addCopiedPaint(String uid, Paint paint) async {
    await _db.collection('users').doc(uid).collection('copiedPaints').add({
      'paintId': paint.id,
      'name': paint.name,
      'brandName': paint.brandName,
      'code': paint.code,
      'hex': paint.hex,
      'copiedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String> createPalette({
    required String userId,
    required String name,
    required List<PaletteColor> colors,
    List<String> tags = const [],
    String notes = '',
  }) async {
    final uid = (userId.isNotEmpty ? userId : currentUser?.uid) ?? '';
    if (uid.isEmpty) {
      throw Exception('Must be signed in to create a palette');
    }

    final now = DateTime.now();
    final doc = _db.collection('palettes').doc();
    await doc.set({
      'userId': uid,
      'name': name,
      'colors': colors.map((c) => c.toJson()).toList(),
      'tags': tags,
      'notes': notes,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return doc.id;
  }

  static Future<String> createColorStory(ColorStory story) async {
    final doc = _db.collection('colorStories').doc();
    await doc.set(story.toJson());
    return doc.id;
  }

  static Future<Map<String, dynamic>> backfillColorStoryFacets() async {
    try {
      final snapshot = await _db.collection('colorStories').get();
      final batch = _db.batch();

      int processedCount = 0;
      int updatedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final themes = List<String>.from(data['themes'] ?? []);
        final families = List<String>.from(data['families'] ?? []);
        final rooms = List<String>.from(data['rooms'] ?? []);

        final facets = ColorStory.buildFacets(
            themes: themes, families: families, rooms: rooms);

        batch.update(doc.reference, {'facets': facets});
        processedCount++;
        updatedCount++;
      }

      await batch.commit();

      return {
        'success': true,
        'processedCount': processedCount,
        'updatedCount': updatedCount,
        'errorCount': 0,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'processedCount': 0,
        'updatedCount': 0,
        'errorCount': 1,
      };
    }
  }

  static Future<void> swapColorStoryRoles(
      String storyId, String fromRole, String toRole) async {
    try {
      final storyRef = _db.collection('colorStories').doc(storyId);
      final storyDoc = await storyRef.get();

      if (!storyDoc.exists) {
        throw Exception('Color story not found');
      }

      final storyData = storyDoc.data() as Map<String, dynamic>;
      final palette =
          List<Map<String, dynamic>>.from(storyData['palette'] ?? []);

      // Find the palette items for both roles
      int fromIndex = -1, toIndex = -1;
      for (int i = 0; i < palette.length; i++) {
        if (palette[i]['role'] == fromRole) fromIndex = i;
        if (palette[i]['role'] == toRole) toIndex = i;
      }

      if (fromIndex == -1 || toIndex == -1) {
        throw Exception('One or both roles not found in palette');
      }

      // Swap the color data between roles
      final fromHex = palette[fromIndex]['hex'];
      final toHex = palette[toIndex]['hex'];
      final fromPaintId = palette[fromIndex]['paintId'];
      final toPaintId = palette[toIndex]['paintId'];
      final fromBrandName = palette[fromIndex]['brandName'];
      final toBrandName = palette[toIndex]['brandName'];
      final fromName = palette[fromIndex]['name'];
      final toName = palette[toIndex]['name'];
      final fromCode = palette[fromIndex]['code'];
      final toCode = palette[toIndex]['code'];

      palette[fromIndex]['hex'] = toHex;
      palette[fromIndex]['paintId'] = toPaintId;
      palette[fromIndex]['brandName'] = toBrandName;
      palette[fromIndex]['name'] = toName;
      palette[fromIndex]['code'] = toCode;

      palette[toIndex]['hex'] = fromHex;
      palette[toIndex]['paintId'] = fromPaintId;
      palette[toIndex]['brandName'] = fromBrandName;
      palette[toIndex]['name'] = fromName;
      palette[toIndex]['code'] = fromCode;

      // Update the story document
      await storyRef.update({
        'palette': palette,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to swap color story roles: $e');
    }
  }
}
