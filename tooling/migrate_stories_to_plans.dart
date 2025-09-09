import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:color_canvas/models/color_plan.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;
  int migrated = 0;
  final users = await db.collection('users').get();
  for (final u in users.docs) {
    final projects = await u.reference.collection('projects').get();
    for (final p in projects.docs) {
      final stories = await p.reference.collection('colorStories').get();
      for (final s in stories.docs) {
        // Use a compound key to avoid ID conflicts: "${p.id}_${s.id}"
        final planRef =
            p.reference.collection('colorPlans').doc('${p.id}_${s.id}');
        final exists = await planRef.get();
        if (exists.exists) continue;

        final data = s.data();
        final plan = ColorPlan.fromJson(planRef.id, {
          'projectId': p.id,
          'name': data['name'] ?? data['title'] ?? 'Plan',
          'vibe': data['vibe'] ?? '',
          'paletteColorIds':
              (data['paletteColorIds'] ?? data['palette'] ?? []).cast<String>(),
          'placementMap': (data['placementMap'] ?? data['placements'] ?? []),
          'cohesionTips': (data['cohesionTips'] ?? data['tips'] ?? []),
          'accentRules': (data['accentRules'] ?? data['accents'] ?? []),
          'doDont': (data['doDont'] ?? []),
          'sampleSequence': (data['sampleSequence'] ?? data['sequence'] ?? []),
          'roomPlaybook': (data['roomPlaybook'] ?? data['rooms'] ?? []),
          'createdAt': data['createdAt'] ?? Timestamp.now(),
          'updatedAt': data['updatedAt'] ?? Timestamp.now(),
        });
        await planRef.set(plan.toJson());
        migrated++;
        debugPrint('Migrated story ${s.id} -> plan ${planRef.id}');
      }
    }
  }
  debugPrint('Total migrated plans: $migrated');
}
