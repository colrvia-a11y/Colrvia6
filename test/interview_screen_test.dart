import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/screens/interview_screen.dart'; // Subject under test
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/services/journey/journey_models.dart';

void main() {
  testWidgets('interview screen loads', (tester) async {
    final j = JourneyService.instance;
    j.state.value = JourneyState(
      journeyId: defaultColorStoryJourneyId,
      projectId: null,
      currentStepId: 'interview.basic',
      completedStepIds: const [],
      artifacts: const {},
    );

    await tester.pumpWidget(const MaterialApp(home: InterviewScreen()));
    expect(find.text('Interview'), findsOneWidget);
  }, skip: true); // Requires platform plugins for voice/STT.
}
