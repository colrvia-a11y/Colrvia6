import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/color_plan.dart';
import 'analytics_service.dart';
import 'lighting_service.dart';
import '../models/fixed_elements.dart';
import 'fixed_element_service.dart';
import '../services/feature_flags.dart';
import 'sync_queue_service.dart';
import 'diagnostics_service.dart';
import 'notifications_service.dart';

/// Service for managing color plans in Firestore and generating new ones via Cloud Functions.
class ColorPlanService {
  static final _instance = ColorPlanService._();
  factory ColorPlanService() => _instance;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  ColorPlanService._() {
    SyncQueueService.instance.registerHandler('createPlan', (payload) async {
      await createPlan(
        projectId: payload['projectId'] as String,
        paletteColorIds: List<String>.from(payload['paletteColorIds'] as List),
        vibe: payload['vibe'] as String?,
        context: payload['context'] as Map<String, dynamic>?,
      );
    });
  }

  CollectionReference<Map<String, dynamic>> _plansCol(
          String uid, String projectId) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('projects')
          .doc(projectId)
          .collection('colorPlans');

  // REGION: CODEX-ADD color-plan-service
  /// Creates a new color plan by invoking the generateColorPlanV2 cloud function
  /// and storing the result in Firestore.
  Future<ColorPlan> createPlan({
    required String projectId,
    required List<String> paletteColorIds,
    String? vibe,
    Map<String, dynamic>? context,
    List<FixedElement>? fixedElements,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to create a color plan');
    }

    final doc = _plansCol(uid, projectId).doc();
    final now = DateTime.now();

    try {
      final profile =
          FeatureFlags.instance.isEnabled(FeatureFlags.lightingProfiles)
              ? await LightingService().getProfile(projectId)
              : null;

      final elements =
          FeatureFlags.instance.isEnabled(FeatureFlags.fixedElementAssist)
              ? (fixedElements ??
                  await FixedElementService().listElements(projectId))
              : <FixedElement>[];

      final callable = _functions.httpsCallable('generateColorPlanV2');
      final resp = await callable.call({
        'projectId': projectId,
        'paletteColorIds': paletteColorIds,
        'vibe': vibe,
        'context': {
          if (profile != null) 'lightingProfile': profile.name,
          if (elements.isNotEmpty)
            'fixedElements': elements.map((e) => e.toJson()).toList(),
          ...?context,
        },
      });

      final data = Map<String, dynamic>.from(resp.data as Map);
      final plan = ColorPlan.fromJson(doc.id, {
        ...data,
        'projectId': projectId,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      await doc.set(plan.toJson());
      AnalyticsService.instance.planGenerated(projectId, doc.id);
      DiagnosticsService.instance.logBreadcrumb('plan_generated:${doc.id}');
      NotificationsService.instance.scheduleNudge(
          'resume_project',
          'Resume your project',
          'Jump back into your project',
          const Duration(days: 3));
      return plan;
    } catch (e) {
      await SyncQueueService.instance.enqueue('createPlan', {
        'projectId': projectId,
        'paletteColorIds': paletteColorIds,
        'vibe': vibe,
        'context': context,
      });
      final fallback = ColorPlan(
        id: doc.id,
        projectId: projectId,
        name: 'Quick Plan',
        vibe: vibe ?? '',
        paletteColorIds: paletteColorIds,
        placementMap: const [],
        cohesionTips: const [],
        accentRules: const [],
        doDont: const [],
        sampleSequence: const [],
        roomPlaybook: const [],
        createdAt: now,
        updatedAt: now,
        isFallback: true,
      );
      await doc.set(fallback.toJson());
      AnalyticsService.instance.planFallbackCreated();
      return fallback;
    }
  }

  /// Lists all color plans for a project, ordered by creation date descending.
  Future<List<ColorPlan>> listPlans(String projectId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to list color plans');
    }

    final snap = await _plansCol(uid, projectId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ColorPlan.fromJson(d.id, d.data())).toList();
  }

  /// Gets a specific color plan by ID.
  Future<ColorPlan?> getPlan(String projectId, String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to get a color plan');
    }

    final doc = await _plansCol(uid, projectId).doc(planId).get();
    if (!doc.exists) return null;
    return ColorPlan.fromJson(doc.id, doc.data()!);
  }

  /// Updates specific fields of a color plan.
  Future<void> updatePlan(
      String projectId, String planId, Map<String, dynamic> patch) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to update a color plan');
    }

    patch['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _plansCol(uid, projectId).doc(planId).update(patch);
  }

  /// Deletes a color plan.
  Future<void> deletePlan(String projectId, String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to delete a color plan');
    }

    await _plansCol(uid, projectId).doc(planId).delete();
  }
  // END REGION: CODEX-ADD color-plan-service
}
