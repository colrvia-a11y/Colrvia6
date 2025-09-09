import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';
import 'package:color_canvas/utils/palette_isolate.dart';

void main() {
  testWidgets('Roller locks color through swipes', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const RollerScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsNothing);

    await tester.tap(find.byKey(const ValueKey('p1')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsOneWidget);
  },
      skip:
          true); // Skipped: depends on Firebase.initializeApp() which isn't available in tests

  test('rollPaletteInIsolate with coastal theme returns palette', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await ThemeService.instance.loadFromAssetIfNeeded();
    final coastal = ThemeService.instance.byId('coastal');
    expect(coastal, isNotNull);

    final available = [
      {
        'id': 'a',
        'hex': '#f6f7f8',
        'lab': [92, 0, 0],
        'lch': [92, 1, 200],
        'rgb': [246, 247, 248]
      },
      {
        'id': 'b',
        'hex': '#d0e8ee',
        'lab': [80, 2, 180],
        'lch': [80, 6, 190],
        'rgb': [208, 232, 238]
      },
      {
        'id': 'c',
        'hex': '#004488',
        'lab': [30, 40, 20],
        'lch': [30, 45, 210],
        'rgb': [0, 68, 136]
      },
    ];

    final args = {
      'available': available,
      'anchors': [null, null, null],
      'modeIndex': 0,
      'diversify': false,
      'slotLrvHints': null,
      'fixedUndertones': <String>[],
      'themeSpec': coastal!.toJson(),
      'themeThreshold': 0.6,
      'attempts': 5,
    };

    final result = await rollPaletteInIsolate(args);
    expect(result, isNotNull);
    expect(result, isA<List>());
    expect((result as List).isNotEmpty, true);
  });
}
