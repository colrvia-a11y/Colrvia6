import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/screens/interview_screen.dart'; // Subject under test
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/services/journey/journey_models.dart';

void main() {
  testWidgets('finishing interview saves answers and advances', (tester) async {
    final j = JourneyService.instance;
    j.state.value = JourneyState(
      journeyId: defaultColorStoryJourneyId,
      projectId: null,
      currentStepId: 'interview.basic',
      completedStepIds: const [],
      artifacts: const {},
    );

    await tester.pumpWidget(const MaterialApp(home: InterviewScreen()));

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(i == 4 ? 'Finish' : 'Next'));
      await tester.pumpAndSettle();
    }

    final state = j.state.value!;
    expect(state.artifacts['answers'], isNotNull);
    expect(state.completedStepIds.contains('interview.basic'), isTrue);
    expect(state.currentStepId, 'roller.build');
  });
}
