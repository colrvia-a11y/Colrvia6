import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/widgets/save_palette_panel.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/services/journey/journey_models.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/user_prefs_service.dart';
import 'package:color_canvas/services/auth_guard.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  tearDown(() {
    createPaletteFn = FirebaseService.createPalette;
    createProjectFn = ProjectService.create;
    attachPaletteFn = ProjectService.attachPalette;
    setLastProjectFn = UserPrefsService.setLastProject;
    ensureSignedInFn = AuthGuard.ensureSignedIn;
    getUidFn = () => FirebaseAuth.instance.currentUser?.uid;
  });

  testWidgets('saving palette updates journey', (tester) async {
    createPaletteFn = ({
      required userId,
      required name,
      required List<PaletteColor> colors,
      List<String> tags = const [],
      String notes = '',
    }) async => 'pal1';
    createProjectFn = ({
      required ownerId,
      String? title,
      String? activePaletteId,
      List<String> paletteIds = const [],
    }) async => 'proj1';
    attachPaletteFn = (pid, paletteId) async {};
    setLastProjectFn = (pid, screen) async {};
    ensureSignedInFn = (_) async {};
    getUidFn = () => 'user1';

    final journey = JourneyService.instance;
    journey.state.value = JourneyState(
      journeyId: defaultColorStoryJourneyId,
      projectId: null,
      currentStepId: 'roller.build',
      completedStepIds: const ['interview.basic'],
      artifacts: const {},
    );

    final paints = [
      Paint(
        id: 'p1',
        brandId: 'b',
        name: 'Red',
        brandName: 'Brand',
        code: 'R1',
        hex: '#FF0000',
        rgb: const [255, 0, 0],
        lab: const [0, 0, 0],
        lch: const [0, 0, 0],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: SavePalettePanel(
        paints: paints,
        onSaved: () {},
        onCancel: () {},
      ),
    ));

    await tester.enterText(find.byType(TextField).first, 'My Palette');
    await tester.tap(find.text('Save Palette'));
    await tester.pumpAndSettle();

    final state = journey.state.value!;
    expect(state.artifacts['paletteId'], 'pal1');
    expect(state.currentStepId, 'review.contrast');
  }, skip: true);
}
