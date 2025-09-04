// lib/services/project_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added this import
import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../services/analytics_service.dart';

class ProjectService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance; // Keep this
  static String? get _uid => _auth.currentUser?.uid; // Keep this
  static CollectionReference get _col => _db.collection('projects');



  static Stream<List<ProjectDoc>> myProjectsStream({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _col
        .where('ownerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
      // Log error but return empty stream to prevent crashes
      debugPrint('ProjectService: Error fetching projects: $error');
      return <QuerySnapshot>[];
    }).map((s) => s.docs.map((d) => ProjectDoc.fromSnap(d)).toList());
  }

  static Future<String> create({
    required String ownerId,
    String? title,
    String? activePaletteId,
    List<String> paletteIds = const [],
  }) async {
    final now = DateTime.now();
    final doc = _db.collection('projects').doc();
    final allPaletteIds = (paletteIds.isNotEmpty)
        ? paletteIds
        : (activePaletteId != null && activePaletteId.isNotEmpty ? [activePaletteId] : <String>[]);

    debugPrint('Creating project for ownerId=$ownerId at /projects/${doc.id}'); // Changed ref.id to doc.id
    await doc.set({
      'ownerId': ownerId,
      'title': title ?? 'My Color Story',
      'activePaletteId': activePaletteId ?? '',
      'paletteIds': allPaletteIds,
      'funnelStage': 'build',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return doc.id;
  }

  static Future<void> attachPalette(String projectId, String paletteId) async {
    await _db.collection('projects').doc(projectId).set({
      'activePaletteId': paletteId,
      'paletteIds': FieldValue.arrayUnion([paletteId]),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static Future<void> setFunnelStage(String projectId, FunnelStage stage) async {
    final stageStr = stage.toString().split('.').last; // build/story/visualize/share
    await _db.collection('projects').doc(projectId).set({
      'funnelStage': stageStr,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    // Track stage change
    AnalyticsService.instance.logProjectStageChanged(projectId, stage); // Keep this
  }

  static Future<ProjectDoc?> fetch(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ProjectDoc.fromSnap(snap);
  }

  static Future<void> addPaletteHistory(
      String projectId, String kind, List<String> palette) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Sign in required to update projects');
    }

    try {
      await _db.collection('projects').doc(projectId).collection('paletteHistory').add({
        'kind': kind,
        'palette': palette,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ProjectService: Failed to append palette history: $e');
    }
  }
}