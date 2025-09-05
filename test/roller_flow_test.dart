import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/roller_screen.dart';

void main() {
  testWidgets('Roller locks color through swipes', (WidgetTester tester) async {
    final paint1 = Paint(
      id: 'p1',
      brandId: 'b',
      brandName: 'Brand',
      name: 'Red',
      code: 'R1',
      hex: '#FF0000',
      rgb: const [255, 0, 0],
      lab: const [53.2, 80.1, 67.2],
      lch: const [53.2, 104.0, 40.0],
    );
    final paint2 = Paint(
      id: 'p2',
      brandId: 'b',
      brandName: 'Brand',
      name: 'Green',
      code: 'G1',
      hex: '#00FF00',
      rgb: const [0, 255, 0],
      lab: const [87.7, -86.2, 83.2],
      lch: const [87.7, 119.8, 136.0],
    );

    await tester.pumpWidget(MaterialApp(
      home: RollerScreen(initialPaints: [paint1, paint2]),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsNothing);

    await tester.tap(find.byKey(const ValueKey('p1')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsOneWidget);
  });
}

