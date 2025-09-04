// lib/services/journey/journey_models.dart
import 'package:flutter/foundation.dart';

enum StepType { questionnaire, tool, review, generate, educate, export }

@immutable
class TransitionRule {
  final String condition; // simple DSL; we evaluate a subset in code
  final String toStepId;
  const TransitionRule({required this.condition, required this.toStepId});
}

@immutable
class JourneyStep {
  final String id;
  final String title;
  final StepType type;
  final String? screenRoute;  // e.g., '/roller' (we use widget navigation directly too)
  final Map<String, dynamic>? params;
  final List<String> requires;      // required artifact keys
  final List<TransitionRule> next;  // branching

  const JourneyStep({
    required this.id,
    required this.title,
    required this.type,
    this.screenRoute,
    this.params,
    this.requires = const [],
    this.next = const [],
  });
}

typedef ArtifactMap = Map<String, dynamic>;

@immutable
class JourneyState {
  final String journeyId;
  final String? projectId;
  final String? currentStepId;
  final List<String> completedStepIds;
  final ArtifactMap artifacts;

  const JourneyState({
    required this.journeyId,
    required this.projectId,
    required this.currentStepId,
    required this.completedStepIds,
    required this.artifacts,
  });

  JourneyState copyWith({
    String? journeyId,
    String? projectId,
    String? currentStepId,
    List<String>? completedStepIds,
    ArtifactMap? artifacts,
  }) {
    return JourneyState(
      journeyId: journeyId ?? this.journeyId,
      projectId: projectId ?? this.projectId,
      currentStepId: currentStepId ?? this.currentStepId,
      completedStepIds: completedStepIds ?? this.completedStepIds,
      artifacts: artifacts ?? this.artifacts,
    );
  }

  Map<String, dynamic> toJson() => {
    'journeyId': journeyId,
    'projectId': projectId,
    'currentStepId': currentStepId,
    'completedStepIds': completedStepIds,
    'artifacts': artifacts,
  };

  static JourneyState fromJson(Map<String, dynamic> json) {
    return JourneyState(
      journeyId: json['journeyId'] as String? ?? 'default_color_story_v1',
      projectId: json['projectId'] as String?,
      currentStepId: json['currentStepId'] as String?,
      completedStepIds: (json['completedStepIds'] as List?)?.cast<String>() ?? const [],
      artifacts: (json['artifacts'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }
}