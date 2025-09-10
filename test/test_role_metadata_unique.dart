import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';

// Minimal fake Paint data for test; adjust fields as needed to satisfy constructors.
Paint fakePaint(String id, double l, {String brand = 'B', double c = 20, double h = 100}) {
  // Approximate LAB/LCH with provided L and simple placeholders
  final lab = [l, c / 2, c / 2];
  final lch = [l, c, h];
  return Paint(
    id: id,
    brandId: brand.toLowerCase(),
    brandName: brand,
    name: 'P$id',
    code: id,
    hex: '#FFFFFF',
    rgb: const [255, 255, 255],
    lab: lab,
    lch: lch,
    collection: 'Test',
    finish: 'matte',
  );
}

void main() {
  test('9-slot palette assigns distinct role metadata', () async {
    final service = PaletteService();
    // Create a broad pool across L range
    final paints = [
      for (int i = 0; i < 400; i++)
        fakePaint('P$i', (i % 100).toDouble(), c: 10 + (i % 30), h: (i * 7) % 360),
    ];

    // Generate with 9 anchors (all null) so size=9
    final anchors = List<Paint?>.filled(9, null);
    final rolled = await service.generate(
      available: paints,
      anchors: anchors,
      diversifyBrands: true,
      mode: HarmonyMode.colrvia,
    );

    expect(rolled.length, 9);
    final roles = [
      for (final p in rolled) (p.metadata?['role'] as String? ?? '')
    ];
    // Expect all roles non-empty
    expect(roles.any((r) => r.isEmpty), isFalse);
    // Expect uniqueness (Support Neutral A/B/C are distinct names)
    expect(roles.toSet().length, roles.length);
  });
}
