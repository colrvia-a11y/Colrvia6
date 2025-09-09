import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/palette_detail_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';

void main() {
  testWidgets('Saved palette can be visualized', (WidgetTester tester) async {
    final palette = UserPalette(
      id: 'p1',
      userId: 'u1',
      name: 'Test Palette',
      colors: [
        PaletteColor(
          paintId: 'c1',
          locked: false,
          position: 0,
          brand: 'Brand',
          name: 'Red',
          code: 'R1',
          hex: '#FF0000',
        ),
        PaletteColor(
          paintId: 'c2',
          locked: false,
          position: 1,
          brand: 'Brand',
          name: 'Green',
          code: 'G1',
          hex: '#00FF00',
        ),
      ],
      tags: [],
      notes: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(
      home: PaletteDetailScreen(palette: palette),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Palette Details'), findsOneWidget);

    await tester.tap(find.byTooltip('Visualize'));
    await tester.pumpAndSettle();

    expect(find.byType(VisualizerScreen), findsOneWidget);
  });

  testWidgets(
    'ColorPlan opens Visualizer with initial palette',
    (WidgetTester tester) async {
      // Arrange a ColorPlan with some paletteColorIds and mock FirebaseService.getPaintsByIds
      // This test requires mocking a static method; keep as a placeholder for now.
      // Expect: pushing VisualizerScreen receives non-empty initialPalette
    },
    skip: true, // Needs mocking of FirebaseService.getPaintsByIds static call
  );
}
