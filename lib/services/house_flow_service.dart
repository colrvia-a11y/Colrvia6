import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/house_flow.dart';

class HouseFlowService {
  final _db = FirebaseFirestore.instance;

  Future<HouseFlow?> getFlow(String projectId) async {
    final doc = await _db
        .collection('projects')
        .doc(projectId)
        .collection('meta')
        .doc('houseFlow')
        .get();
    final data = doc.data();
    if (data == null) return null;
    return HouseFlow.fromJson(data);
  }

  Future<void> setFlow(String projectId, HouseFlow flow) async {
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('meta')
        .doc('houseFlow')
        .set(flow.toJson());
  }
}
