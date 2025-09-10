import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';

// This test verifies that when the palette contains both warm and cool high-chroma
// accents, the pipeline injects (or preserves) a neutral mid-LRV low-chroma bridge
// so that ThemeEngine.validatePaletteRules does not return 'no_bridge_for_warm_cool_mix'.
// It also double-checks via manual classification of warm/cool/bridge roles.
void main() {
  group('Undertone consistency warm/cool mix', () {
    // Helper hue classification aligned with ThemeEngine._isWarmHue/_isCoolHue thresholds
    bool isWarmHue(double h) => (h >= 0 && h <= 70) || (h >= 330 && h < 360);
    bool isCoolHue(double h) => (h >= 70 && h <= 250);

    // Chroma threshold for an accent vs neutral (mirrors spec.neutrals?.C?.max default 12)
    const double neutralCMax = 12.0;

    Paint p(String id, double l, double c, double h, String name) => Paint.fromJson({
          'hex': '#808080', // mid neutral; won't dictate LRV because we set explicit lrv
          'lab': [l, 0.0, 0.0],
          'lch': [l, c, h],
          'rgb': [128, 128, 128],
          'lrv': l, // ensure computedLrv == intended L
          'brandName': 'Test',
          'brandId': 'Test'
        }, id).copyWith(name: name);

    test('Warm + cool accents triggers bridge neutral presence', () {
      // High-chroma warm (H ~ 30), high-chroma cool (H ~ 220), plus candidate neutrals.
      final available = <Paint>[
        p('very_dark_neutral', 10.0, 2.0, 0.0, 'Very Dark Neutral'),
        p('warm_accent', 45.0, 40.0, 30.0, 'Warm Accent'),
        p('cool_accent', 55.0, 42.0, 220.0, 'Cool Accent'),
        p('mid_neutral', 60.0, 4.0, 0.0, 'Mid Neutral'),
        p('off_white', 78.0, 3.0, 0.0, 'Off White'),
      ];

  final anchors = List<Paint?>.filled(5, null);

      final rolled = PaletteGenerator.rollPalette(
        availablePaints: available,
        anchors: anchors,
        mode: HarmonyMode.colrvia,
        diversifyBrands: false,
      );

      // Debug log palette composition
      // (Will not fail test; just helps if future regression occurs.)
      // ignore: avoid_print
      print('Rolled palette order:');
      for (final r in rolled) {
        final c = r.lch.length > 1 ? r.lch[1] : 0.0;
        final h = r.lch.length > 2 ? r.lch[2] : 0.0;
        // ignore: avoid_print
        print('  ${r.name}  L=${r.computedLrv.toStringAsFixed(1)} C=${c.toStringAsFixed(1)} H=${h.toStringAsFixed(1)}');
      }

      // Minimal ThemeSpec to allow validation (mirroring other tests) - use defaults
      final spec = ThemeSpec(
        id: 'test-theme',
        label: 'Test Theme',
        neutrals: Range3(C: Range1(0, neutralCMax)),
        accents: Range3(C: Range1(neutralCMax + 0.01, 80)),
        varietyControls: const VarietyControls(
          minColors: 4,
          maxColors: 6,
          mustIncludeNeutral: false,
          mustIncludeAccent: false,
        ),
      );

      // Run validation: should not fail with 'no_bridge_for_warm_cool_mix'
      final validation = ThemeEngine.validatePaletteRules(rolled, spec);

      // Manual classification to assert bridge presence when needed
      int warmChromatics = 0, coolChromatics = 0; bool hasBridge = false;
      for (final paint in rolled) {
        final c = paint.lch.length > 1 ? paint.lch[1] : 0.0;
        final h = paint.lch.length > 2 ? ((paint.lch[2] % 360) + 360) % 360 : 0.0;
        final lrv = paint.computedLrv;
        final chromatic = c > neutralCMax;
        if (chromatic && isWarmHue(h)) warmChromatics++;
        if (chromatic && isCoolHue(h)) coolChromatics++;
        if (!chromatic && lrv >= 35.0 && lrv <= 75.0) hasBridge = true;
      }

      // If both warm and cool chromatics appear, assert bridge exists and no validation error.
      if (warmChromatics > 0 && coolChromatics > 0) {
        expect(validation, isNot('no_bridge_for_warm_cool_mix'));
        expect(hasBridge, true,
            reason: 'Expected a neutral mid-LRV bridge when warm and cool chromatics mix.');
      } else {
        // If mixing didn't happen (edge case), the rule should not produce that error anyway.
        expect(validation, isNot('no_bridge_for_warm_cool_mix'));
      }
    });
  });
}

// No extra helpers needed; using dart:math directly.
