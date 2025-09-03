// lib/services/journey/journey_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/user_prefs_service.dart';
import 'package:color_canvas/models/project.dart';
import 'package:color_canvas/services/journey/journey_models.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/services/analytics_service.dart';

/// Thin orchestrator that persists step state into the project doc under `journey`.
class JourneyService {
  JourneyService._();
  static final JourneyService instance = JourneyService._();

  final ValueNotifier<JourneyState?> state = ValueNotifier<JourneyState?>(null);

  /// Use this to access the static journey definition.
  List<JourneyStep> get steps => defaultJourneySteps;

  JourneyStep? stepById(String? id) {
    if (id == null) return null;
    return steps.firstWhere((s) => s.id == id, orElse: () => steps.first);
  }

  JourneyStep get firstStep => steps.first;

  Future<void> loadForLastProject() async {
    final prefs = await UserPrefsService.fetch();
    final pid = prefs.lastOpenedProjectId;
    if (pid == null) {
      state.value = JourneyState(
        journeyId: defaultColorStoryJourneyId,
        projectId: null,
        currentStepId: firstStep.id,
        completedStepIds: const [],
        artifacts: const {},
      );
      return;
    }
    await loadForProject(pid);
  }

  Future<void> loadForProject(String projectId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = snap.data() ?? {};
      final journey = (data['journey'] as Map?)?.cast<String, dynamic>() ?? {};
      final current = JourneyState.fromJson({
        'journeyId': journey['journeyId'] ?? defaultColorStoryJourneyId,
        'projectId': projectId,
        'currentStepId': journey['currentStepId'] ?? firstStep.id,
        'completedStepIds': journey['completedStepIds'] ?? <String>[],
        'artifacts': journey['artifacts'] ?? <String, dynamic>{},
      });
      state.value = current;
    } catch (e) {
      debugPrint('JourneyService load failed: $e');
      // Fallback to a local default state tied to the project; do NOT persist
      state.value = JourneyState(
        journeyId: defaultColorStoryJourneyId,
        projectId: projectId,
        currentStepId: firstStep.id,
        completedStepIds: const [],
        artifacts: const {},
      );
    }
  }

  Future<void> _persist(JourneyState s) async {
    if (s.projectId == null) {
      // nothing to persist yet
      state.value = s;
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(s.projectId)
          .set({'journey': s.toJson()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('JourneyService persist failed: $e');
    }
    state.value = s;
  }

  /// Mark a step as complete and transition using the first satisfied rule.
  Future<void> completeCurrentStep({Map<String, dynamic>? artifacts}) async {
    final s = state.value;
    if (s == null) return;
    final step = stepById(s.currentStepId) ?? firstStep;
    final mergedArtifacts = Map<String, dynamic>.of(s.artifacts);
    if (artifacts != null) mergedArtifacts.addAll(artifacts);

    // Determine next step using very simple rule evaluator
    String? nextId;
    for (final rule in step.next) {
      if (_evaluate(rule.condition, mergedArtifacts)) {
        nextId = rule.toStepId;
        break;
      }
    }
    nextId ??= s.currentStepId; // fallback

    final updated = s.copyWith(
      completedStepIds: {...s.completedStepIds, step.id}.toList(),
      currentStepId: nextId,
      artifacts: mergedArtifacts,
    );

    // Also advance funnel stage heuristically
    final stage = _deriveFunnelStage(step.id);
    if (s.projectId != null && stage != null) {
      await ProjectService.setFunnelStage(s.projectId!, stage);
    }
    final analytics = AnalyticsService.instance;
    analytics.log('journey_step_complete', {
      'step_id': step.id,
      'next_step_id': nextId,
    });
    if (artifacts != null) {
      for (final key in artifacts.keys) {
        analytics.log('artifact_created', {'key': key});
      }
    }

    await _persist(updated);
  }

  Future<void> setArtifact(String key, dynamic value) async {
    final s = state.value;
    if (s == null) return;
    final art = Map<String, dynamic>.of(s.artifacts);
    art[key] = value;
    AnalyticsService.instance.log('artifact_created', {'key': key});
    await _persist(s.copyWith(artifacts: art));
  }

  JourneyStep? nextBestStep() {
    final s = state.value;
    if (s == null) return firstStep;
    // If current step has unmet requirements, return it; else move to next.
    final current = stepById(s.currentStepId) ?? firstStep;
    final unmet = current.requires.where((k) => !_hasArtifact(s.artifacts, k));
    if (unmet.isNotEmpty) return current;

    // else, propose the next rule's target or next uncompleted step
    for (final rule in current.next) {
      if (_evaluate(rule.condition, s.artifacts)) {
        return stepById(rule.toStepId) ?? current;
      }
    }
    // fallback to first incomplete
    for (final st in steps) {
      if (!s.completedStepIds.contains(st.id)) return st;
    }
    return current;
  }

  bool _hasArtifact(Map<String, dynamic> art, String key) {
    // allow dot paths like 'renderIds.length'
    if (key.contains('.')) {
      final head = key.split('.').first;
      return art.containsKey(head);
    }
    return art.containsKey(key);
  }

  bool _evaluate(String expr, Map<String, dynamic> art) {
    // Extremely tiny evaluator for expressions used in defaults
    expr = expr.trim();
    if (expr == 'true') return true;
    if (expr == 'false') return false;

    // handle "art.{key} != null" and "art.renderIds.length > 0"
    if (expr.startsWith('art.')) {
      final rest = expr.substring(4);
      if (rest.endsWith('!= null')) {
        final key = rest.replaceAll('!= null', '').trim();
        final val = _resolvePath(art, key);
        return val != null;
      }
      if (rest.endsWith('> 0') && rest.contains('.length')) {
        final key = rest.replaceAll('.length > 0', '').trim();
        final val = _resolvePath(art, key);
        if (val is Iterable) return val.isNotEmpty;
        if (val is List) return val.isNotEmpty;
        return false;
      }
    }
    return false;
  }

  dynamic _resolvePath(Map<String, dynamic> obj, String path) {
    final parts = path.split('.');
    dynamic cur = obj;
    for (final p in parts) {
      if (cur is Map<String, dynamic> && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  FunnelStage? _deriveFunnelStage(String stepId) {
    if (stepId.startsWith('roller.') || stepId.startsWith('build.') || stepId.startsWith('interview.')) {
      return FunnelStage.build;
    }
    if (stepId.startsWith('review.') || stepId.startsWith('plan.')) {
      return FunnelStage.story;
    }
    if (stepId.startsWith('visualizer.')) return FunnelStage.visualize;
    if (stepId.startsWith('guide.')) return FunnelStage.share;
    return null;
  }
}