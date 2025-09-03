import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/journey_models.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';

void main() {
  test('paletteId advances to review.contrast', () async {
    final j = JourneyService.instance;
    j.state.value = JourneyState(
      journeyId: defaultColorStoryJourneyId,
      projectId: null,
      currentStepId: 'roller.build',
      completedStepIds: const [],
      artifacts: const {},
    );

    await j.completeCurrentStep(artifacts: {'paletteId': 'pal1'});
    final s = j.state.value!;
    expect(s.currentStepId, 'review.contrast');
    expect(s.artifacts['paletteId'], 'pal1');
  });

  test('renderIds triggers plan.create', () async {
    final j = JourneyService.instance;
    j.state.value = JourneyState(
      journeyId: defaultColorStoryJourneyId,
      projectId: null,
      currentStepId: 'visualizer.generate',
      completedStepIds: const [],
      artifacts: const {
        'paletteId': 'p1',
        'photoId': 'ph1',
      },
    );

    await j.completeCurrentStep(artifacts: {'renderIds': ['r1']});
    final s = j.state.value!;
    expect(s.currentStepId, 'plan.create');
    expect(s.artifacts['renderIds'], ['r1']);
  });
}
