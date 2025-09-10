import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/utils/palette_generator.dart';

// Helper to make a fake Paint with controllable L (LRV surrogate) and mild chroma spread.
Paint _fake(String id, double l, {double c = 12, double h = 30, String brand = 'B'}) {
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
    lrv: l, // Ensure computedLrv matches desired test L value
    finish: 'matte',
    collection: 'Test',
  );
}

// Build a broad pool across 0..100 L including guaranteed extreme values.
List<Paint> _buildPool() {
  final paints = <Paint>[];
  // Guarantee at least one very dark (<15) and one very light (>=70)
  paints.add(_fake('dark_anchor', 5, c: 8, h: 40, brand: 'BD')); // very dark neutral-ish
  paints.add(_fake('dark_anchor_b', 7, c: 9, h: 220, brand: 'BX')); // second dark different brand
  paints.add(_fake('light_anchor', 92, c: 10, h: 60, brand: 'BL')); // very light
  // Fill rest with a gradient of L values and varying hue/chroma for diversity
  for (int i = 0; i < 300; i++) {
    final l = (i % 100).toDouble();
    final c = 8 + (i % 24); // vary chroma a bit
    final h = (i * 11) % 360; // spread hues
    paints.add(_fake('P$i', l, c: c.toDouble(), h: h.toDouble(), brand: 'B${i % 5}'));
  }
  return paints;
}

// Minimal dummy ThemeSpec so validatePaletteRules can run without null roleTargets.
ThemeSpec _dummyThemeSpec() => ThemeSpec(
      id: 'dummy',
      label: 'Dummy',
      weights: const {},
    );


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Palette size role constraints 1..9', () {
    final pool = _buildPool();
    final service = PaletteService();
    final spec = _dummyThemeSpec();

  for (int size = 1; size <= 9; size++) {
      test('size=$size generation + role/value constraints', () async {
        final anchors = List<Paint?>.filled(size, null);
        List<Paint> rolled = const [];
        // Retry up to 5 attempts to account for stochastic generation
        for (int attempt = 0; attempt < 5; attempt++) {
          rolled = await service.generate(
            available: pool,
            anchors: anchors,
            diversifyBrands: true,
            mode: HarmonyMode.colrvia,
          );
          if (size == 1) break;
          final lValsA = rolled.map((p) => p.computedLrv).toList();
          final minA = lValsA.reduce((a,b)=>a<b?a:b);
          final maxA = lValsA.reduce((a,b)=>a>b?a:b);
            final hasExtremes = (size == 2)
              ? (minA < 15 && maxA >= 70)
              : (minA < 15 && maxA >= 70);
          if (hasExtremes) break;
        }

        expect(rolled.length, size, reason: 'Palette should have requested size');

        final lVals = rolled.map((p) => p.computedLrv).toList();
        final minL = lVals.reduce((a, b) => a < b ? a : b);
        final maxL = lVals.reduce((a, b) => a > b ? a : b);
  final sortedL = List.of(lVals)..sort();
  // ignore: avoid_print
  print('size=$size rolled LRVs: min=$minL max=$maxL all=$sortedL');

        if (size == 1) {
          expect(rolled.length, 1);
        } else if (size == 2) {
          expect(minL < 15, isTrue, reason: '2-color palette should include a very dark color (<15 LRV)');
          expect(maxL >= 70, isTrue, reason: '2-color palette should include a very light color (>=70 LRV)');
        } else { // size >=3
          expect(minL < 15, isTrue, reason: 'Palettes size>=3 must include very dark (<15)');
          expect(maxL >= 70, isTrue, reason: 'Palettes size>=3 must include very light (>=70)');
          final validation = ThemeEngine.validatePaletteRules(rolled, spec);
          expect(validation, isNot(anyOf('no_very_light', 'no_very_dark')));
        }
      }, timeout: const Timeout(Duration(seconds: 40)));
    }
  });
}
