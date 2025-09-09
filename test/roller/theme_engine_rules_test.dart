import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

Paint p(String id, double l, double c, double h) => Paint.fromJson({
  'hex': '#000000',
  'lab': [l, 0.0, 0.0],
  'lch': [l, c, h],
  'rgb': [0,0,0],
  'brandName': 'B',
  'brandId': 'B'
}, id);

ThemeSpec dummySpec() => ThemeSpec(
  id: 'dummy',
  label: 'Dummy',
  weights: const {},
);

void main() {
  group('ThemeEngine.validatePaletteRules', () {
    test('value extremes: missing very light or very dark is invalid', () {
      final spec = dummySpec();
      expect(ThemeEngine.validatePaletteRules([p('a', 10, 5, 0), p('b', 40, 5, 0), p('c', 55, 5, 0)], spec), equals('no_very_light'));
      expect(ThemeEngine.validatePaletteRules([p('a', 80, 5, 0), p('b', 60, 5, 0), p('c', 55, 5, 0)], spec), equals('no_very_dark'));
    });

    test('spacing: tight cluster (<5 L) invalid', () {
      // include a very light and a very dark so extremes are satisfied
      final res = ThemeEngine.validatePaletteRules([
        p('x', 85, 5, 0), p('d', 10, 5, 0), p('a', 50, 5, 0), p('b', 52, 5, 0), p('c', 54, 5, 0)
      ], dummySpec());
      expect(res, equals('values_too_close'));
    });

    test('undertone cohesion: warm+cool without neutral bridge invalid', () {
      final spec = dummySpec(); // for neutral C max
      // Ensure extremes exist to reach bridge check
      final res = ThemeEngine.validatePaletteRules([
        p('light', 85, 5, 0),
        p('w', 40, 30, 10), // warm accent
        p('c', 50, 30, 120), // cool accent
        p('dark', 10, 5, 0),
      ], spec);
      expect(res, equals('no_bridge_for_warm_cool_mix'));
    });
  });

  group('ThemeEngine.temperatureBalance', () {
  test('80/20 mix scores high; 50/50 penalized', () {
      final warmHeavy = [
        p('light', 85, 5, 0), p('dark', 10, 5, 0), p('bridge', 52, 5, 0), // extremes + neutral bridge
        p('w1', 42, 20, 10), p('w2', 58, 20, 15), p('w3', 66, 20, 20), p('c', 28, 20, 120),
      ];
      final coolHeavy = [
        p('light', 85, 5, 0), p('dark', 10, 5, 0), p('bridge', 52, 5, 0),
        p('c1', 44, 20, 120), p('c2', 60, 20, 140), p('c3', 68, 20, 160), p('w', 26, 20, 10),
      ];
      final even = [
        p('light', 85, 5, 0), p('dark', 10, 5, 0), p('bridge', 52, 5, 0),
        p('w1', 42, 20, 10), p('c1', 68, 20, 140),
      ];
      // Use private method via score terms: we can approximate by calling scorePalette with only temperatureBalance weight
  final warmScore = ThemeEngine.scorePalette(warmHeavy, ThemeSpec(id: 't', label: 't', weights: const {'temperatureBalance': 1.0}));
  final coolScore = ThemeEngine.scorePalette(coolHeavy, ThemeSpec(id: 't', label: 't', weights: const {'temperatureBalance': 1.0}));
  final evenScore = ThemeEngine.scorePalette(even, ThemeSpec(id: 't', label: 't', weights: const {'temperatureBalance': 1.0}));
      expect(warmScore, greaterThan(0.8));
      expect(coolScore, greaterThan(0.8));
      expect(evenScore, lessThan(0.5));
    });
  });
}
