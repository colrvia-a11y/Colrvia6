import 'package:cloud_firestore/cloud_firestore.dart';

class ColorMetricsService {
  final _db = FirebaseFirestore.instance;

  Future<double?> lrvOf(String colorId) async {
    final doc = await _db.collection('paints').doc(colorId).get();
    final data = doc.data();
    final lab = (data?['lab'] as List?)?.cast<num>();
    return lab != null && lab.isNotEmpty ? lab[0].toDouble() : null;
  }

  Future<double> deltaLrv(String a, String b) async {
    final l1 = await lrvOf(a) ?? 0;
    final l2 = await lrvOf(b) ?? 0;
    return (l1 - l2).abs();
  }

  Future<bool> undertoneConflict(String a, String b) async {
    final docA = await _db.collection('paints').doc(a).get();
    final docB = await _db.collection('paints').doc(b).get();
    final labA = (docA.data()?['lab'] as List?)?.cast<num>().toList();
    final labB = (docB.data()?['lab'] as List?)?.cast<num>().toList();
    if (labA == null || labB == null) return false;
    final conflictA = (labA[1] * labB[1]) < 0 && (labA[1] - labB[1]).abs() > 20;
    final conflictB = (labA[2] * labB[2]) < 0 && (labA[2] - labB[2]).abs() > 20;
    return conflictA || conflictB;
  }
}
