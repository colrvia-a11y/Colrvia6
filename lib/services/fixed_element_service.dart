// lib/services/fixed_element_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/fixed_elements.dart';
import 'analytics_service.dart';

/// Service to manage fixed elements for a project.
class FixedElementService {
  FixedElementService._();
  static final FixedElementService _instance = FixedElementService._();
  factory FixedElementService() => _instance;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid, String projectId) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('projects')
          .doc(projectId)
          .collection('fixedElements');

  Future<List<FixedElement>> listElements(String projectId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _col(uid, projectId).get();
    return snap.docs.map((d) => FixedElement.fromSnap(d)).toList();
  }

  Future<void> saveAll(String projectId, List<FixedElement> elements) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final col = _col(uid, projectId);
    final batch = _db.batch();

    final existing = await col.get();
    for (final doc in existing.docs) {
      if (!elements.any((e) => e.id == doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final e in elements) {
      batch.set(col.doc(e.id), e.toJson());
    }
    await batch.commit();
    AnalyticsService.instance.logEvent('fixed_elements_saved', {
      'project_id': projectId,
      'count': elements.length,
    });
  }

  Future<void> deleteElement(String projectId, String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _col(uid, projectId).doc(id).delete();
  }
}
