import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

void main() {
  // Build a tiny fake paint pool covering LRV spectrum
  List<Paint> pool() => [
        // Generate grayscale paints so LRV (via hex) spans dark->light
        for (int i = 0; i < 300; i++)
          (() {
            final v = (i / 299.0 * 255).round().clamp(0, 255);
            final hexComponent = v.toRadixString(16).padLeft(2, '0');
            final hex = 'FF$hexComponent$hexComponent$hexComponent';
            final l = (v / 255.0 * 100.0);
            return Paint(
              id: 'p$i',
              brandId: 'b',
              brandName: 'Brand',
              name: 'N$i',
              code: 'C$i',
              hex: hex,
              rgb: [v, v, v],
              lab: [l, 0.0, 0.0],
              lch: [l, 0.0, 0.0],
            );
          })(),
      ];

  test('ColrVia supports sizes 1..9 with anchors length driving size', () {
    final paints = pool();
    for (int n = 1; n <= 9; n++) {
      final out = PaletteGenerator.rollPalette(
        availablePaints: paints,
        anchors: List<Paint?>.filled(n, null),
        mode: HarmonyMode.colrvia,
      );
      expect(out.length, n);
    }
  });

  test(
      'ColrVia tends to include value extremes (very light and very dark) when size >= 3',
      () {
    final paints = pool();
    final out = PaletteGenerator.rollPalette(
      availablePaints: paints,
      anchors: List<Paint?>.filled(5, null),
      mode: HarmonyMode.colrvia,
    );
    final lrvs = out.map((p) => p.computedLrv).toList()..sort();
    // Debug: print chosen LRVs
    print('chosen lrvs: ${lrvs.map((v) => v.toStringAsFixed(1)).toList()}');
    expect(lrvs.first <= 15, true); // anchor-ish
    expect(lrvs.last >= 72, true); // off-white or bright
  });
}
