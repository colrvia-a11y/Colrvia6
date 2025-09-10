import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';

// Helper to build vivid and muted paints with specific chroma.
Paint paint(String id, double l, double c, double h) => Paint.fromJson({
  'hex': '#000000',
  'lab': [l, 0.0, 0.0],
  'lch': [l, c, h],
  'rgb': [0,0,0],
  'lrv': l, // ensure computedLrv reflects intended lightness band
  'brandName': 'Test',
  'brandId': 'T'
}, id);

void main() {
  group('Chromatic cohesion - pop accent limitation', () {
    test('Validation fails when >1 pops present (hard gate)', () {
      final vivid = [
        paint('dark', 8, 5, 0),          // very dark extreme (neutral hue)
        paint('light', 85, 4, 0),        // very light extreme (neutral hue)
        paint('p1', 50, 30, 10),         // warm pop 1
        paint('p2', 55, 26, 20),         // warm pop 2
        paint('p3', 60, 28, 30),         // warm pop 3
      ];
      final spec = ThemeSpec(
        id: 'pop-limit-fail',
        label: 'Pop Limit Fail',
        varietyControls: const VarietyControls(
          minColors: 5,
          maxColors: 5,
          popChromaMin: 18.0,
          maxPops: 1,
          mustIncludeNeutral: false,
          mustIncludeAccent: false,
          mutedPalettePrefersMutedPop: true,
        ),
      );
      final validation = ThemeEngine.validatePaletteRules(vivid, spec);
      expect(validation, equals('too_many_pops'));
    });

    test('Validation passes when <=1 pop retained', () {
      final acceptable = [
        paint('dark', 8, 5, 0),          // very dark extreme
        paint('light', 85, 4, 0),        // very light extreme
        paint('pop', 50, 30, 15),        // single warm pop
        paint('n1', 55, 12, 10),         // muted warm below threshold
        paint('n2', 60, 10, 25),         // muted warm below threshold
      ];
      final spec = ThemeSpec(
        id: 'pop-limit-pass',
        label: 'Pop Limit Pass',
        varietyControls: const VarietyControls(
          minColors: 5,
          maxColors: 5,
          popChromaMin: 18.0,
          maxPops: 1,
          mustIncludeNeutral: false,
          mustIncludeAccent: false,
          mutedPalettePrefersMutedPop: true,
        ),
      );
      final validation = ThemeEngine.validatePaletteRules(acceptable, spec);
      expect(validation, isNull);
      final popThreshold = 18.0;
      final popCount = acceptable.where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) >= popThreshold).length;
      expect(popCount, lessThanOrEqualTo(1));
    });
  });
}
