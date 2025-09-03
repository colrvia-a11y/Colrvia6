// lib/services/photo_library_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/saved_photo.dart';
import '../utils/debug_logger.dart';

class PhotoLibraryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _photosCollection = 'saved_photos';
  static const String _storageFolder = 'user_photos';

  /// Save a new photo to the user's library
  static Future<String> savePhoto({
    required Uint8List imageData,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Generate unique ID for the photo
      final photoId = _firestore.collection(_photosCollection).doc().id;
      
      // Upload image to Firebase Storage
      final imageRef = _storage
          .ref()
          .child(_storageFolder)
          .child(user.uid)
          .child('$photoId.jpg');
      
      final uploadTask = await imageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save photo metadata to Firestore
      final photoData = {
        'id': photoId,
        'userId': user.uid,
        'imageUrl': downloadUrl,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      };

      await _firestore
          .collection(_photosCollection)
          .doc(photoId)
          .set(photoData);

      return photoId;
    } catch (e) {
      throw Exception('Failed to save photo: $e');
    }
  }

  /// Get all photos for the current user
  static Future<List<SavedPhoto>> getUserPhotos() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final querySnapshot = await _firestore
          .collection(_photosCollection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final photos = <SavedPhoto>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Download image data from storage
        final imageUrl = data['imageUrl'] as String?;
        if (imageUrl != null) {
          try {
            final imageRef = _storage.refFromURL(imageUrl);
            final imageData = await imageRef.getData();
            
            if (imageData != null) {
              final photo = SavedPhoto(
                id: data['id'] ?? doc.id,
                userId: data['userId'] ?? '',
                imageData: imageData,
                description: data['description'] ?? '',
                createdAt: data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now(),
                metadata: data['metadata'] as Map<String, dynamic>?,
              );
              
              photos.add(photo);
            }
          } catch (imageError) {
            Debug.error('PhotoLibraryService', 'getUserPhotos', 
                'Error loading image for photo ${doc.id}: $imageError');
            // Continue with other photos if one fails
          }
        }
      }

      return photos;
    } catch (e) {
      throw Exception('Failed to load photos: $e');
    }
  }

  /// Delete a specific photo
  static Future<void> deletePhoto(String photoId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get photo document to find the image URL
      final photoDoc = await _firestore
          .collection(_photosCollection)
          .doc(photoId)
          .get();

      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data()!;
      
      // Verify ownership
      if (data['userId'] != user.uid) {
        throw Exception('Unauthorized to delete this photo');
      }

      // Delete image from storage
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null) {
        try {
          final imageRef = _storage.refFromURL(imageUrl);
          await imageRef.delete();
        } catch (storageError) {
          Debug.error('PhotoLibraryService', 'deletePhoto', 
              'Error deleting image from storage: $storageError');
          // Continue with Firestore deletion even if storage fails
        }
      }

      // Delete document from Firestore
      await _firestore
          .collection(_photosCollection)
          .doc(photoId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete photo: $e');
    }
  }

  /// Clear all photos for the current user
  static Future<void> clearAllPhotos() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get all user photos
      final querySnapshot = await _firestore
          .collection(_photosCollection)
          .where('userId', isEqualTo: user.uid)
          .get();

      // Delete in batches
      final batch = _firestore.batch();
      final deleteFromStorage = <String>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        batch.delete(doc.reference);
        
        // Collect storage URLs for deletion
        final imageUrl = data['imageUrl'] as String?;
        if (imageUrl != null) {
          deleteFromStorage.add(imageUrl);
        }
      }

      // Commit batch delete from Firestore
      await batch.commit();

      // Delete images from storage
      for (final url in deleteFromStorage) {
        try {
          final imageRef = _storage.refFromURL(url);
          await imageRef.delete();
        } catch (storageError) {
          Debug.error('PhotoLibraryService', 'clearAllPhotos', 
              'Error deleting image from storage: $storageError');
          // Continue with other images if one fails
        }
      }
    } catch (e) {
      throw Exception('Failed to clear photos: $e');
    }
  }

  /// Get photo count for the current user
  static Future<int> getPhotoCount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return 0;
    }

    try {
      final querySnapshot = await _firestore
          .collection(_photosCollection)
          .where('userId', isEqualTo: user.uid)
          .count()
          .get();

      return querySnapshot.count ?? 0;
    } catch (e) {
      Debug.error('PhotoLibraryService', 'getPhotoCount', 
          'Error getting photo count: $e');
      return 0;
    }
  }

  /// Check if user has any photos
  static Future<bool> hasPhotos() async {
    final count = await getPhotoCount();
    return count > 0;
  }
}
