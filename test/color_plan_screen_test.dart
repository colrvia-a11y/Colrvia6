import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/models/color_plan.dart';
import 'package:color_canvas/models/fixed_elements.dart';
import 'package:color_canvas/screens/color_plan_screen.dart';
import 'package:color_canvas/services/color_plan_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/journey_models.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/services/user_prefs_service.dart';

class _FakeColorPlanService implements ColorPlanService {
  @override
  Future<ColorPlan> createPlan({
    required String projectId,
    required List<String> paletteColorIds,
    String? vibe,
    Map<String, dynamic>? context,
    List<FixedElement>? fixedElements,
  }) async {
    return ColorPlan(
      id: 'plan1',
      projectId: projectId,
      name: 'Test',
      vibe: '',
      paletteColorIds: paletteColorIds,
      placementMap: const [],
      cohesionTips: const [],
      accentRules: const [],
      doDont: const [],
      sampleSequence: const [],
      roomPlaybook: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ColorPlan>> listPlans(String projectId) async => [];

  @override
  Future<ColorPlan?> getPlan(String projectId, String planId) async => null;

  @override
  Future<void> updatePlan(
      String projectId, String planId, Map<String, dynamic> patch) async {}

  @override
  Future<void> deletePlan(String projectId, String planId) async {}
}

void main() {
  tearDown(() {
    setLastProjectFn = UserPrefsService.setLastProject;
  });

  testWidgets('plan creation stores planId in journey', (tester) async {
    setLastProjectFn = (projectId, screen) async {};
    final j = JourneyService.instance;
    j.state.value = JourneyState(
      journeyId: defaultColorStoryJourneyId,
      projectId: null,
      currentStepId: 'plan.create',
      completedStepIds: const [],
      artifacts: const {'paletteId': 'pal1'},
    );

    await tester.pumpWidget(MaterialApp(
      home: ColorPlanScreen(
        projectId: 'proj1',
        paletteColorIds: const ['c1'],
        svc: _FakeColorPlanService(),
      ),
    ));
    await tester.pumpAndSettle();

    final s = j.state.value!;
    expect(s.artifacts['planId'], 'plan1');
    expect(s.completedStepIds.contains('plan.create'), isTrue);
  });
}
