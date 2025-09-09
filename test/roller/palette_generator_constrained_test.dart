import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

Paint p(String id, double l, double c, double h, {String brand = 'B'}) => Paint.fromJson({
  'hex': '#000000',
  'lab': [l, 0.0, 0.0],
  'lch': [l, c, h],
  'rgb': [0,0,0],
  'brandName': brand,
  'brandId': brand,
}, id);

void main() {
  test('constrained generator respects slot hints and locks', () {
    final pool = <Paint>[
      p('d1', 10, 5, 0), p('d2', 12, 5, 0), // dark band
      p('m1', 45, 20, 30), p('m2', 50, 18, 40), // mid band
      p('l1', 78, 6, 60), p('l2', 85, 4, 80), // light band, low C
    ];
    final anchors = <Paint?>[null, null, null];
    // Theme slot hints: [light][mid][dark]
    final hints = [
      [72.0, 90.0],
      [40.0, 60.0],
      [0.0, 15.0],
    ];

    final out = PaletteGenerator.rollPaletteConstrained(
      availablePaints: pool,
      anchors: anchors,
      slotLrvHints: hints,
      diversifyBrands: false,
    );
    expect(out.length, 3);
    expect(out[0].lch[0] >= 72 && out[0].lch[0] <= 90, true);
    expect(out[1].lch[0] >= 40 && out[1].lch[0] <= 60, true);
    expect(out[2].lch[0] >= 0 && out[2].lch[0] <= 15, true);

    // Lock mid, ensure alternates from same slot stay in band
    final anchors2 = <Paint?>[out[0], out[1], null];
    final out2 = PaletteGenerator.rollPaletteConstrained(
      availablePaints: pool,
      anchors: anchors2,
      slotLrvHints: hints,
      diversifyBrands: false,
    );
    expect(out2[0].id, out[0].id);
    expect(out2[1].id, out[1].id);
    expect(out2[2].lch[0] >= 0 && out2[2].lch[0] <= 15, true);
  });

  test('alternates generation respects hints (via isolate path)', () {
    // Minimal smoke using ThemeEngine hints and a dummy ThemeSpec with anchor=light, accent=dark
    final pool = <Paint>[
      p('d1', 8, 5, 0), p('d2', 12, 5, 0), p('m', 50, 18, 40), p('l', 85, 4, 80),
    ];
    final spec = ThemeSpec(id: 't', label: 't', roleTargets: RoleTargets(
      anchor: RoleTarget(L: Range1(80, 90)),
      accent: RoleTarget(L: Range1(0, 15)),
    ));
    final hints = ThemeEngine.slotLrvHintsFor(2, spec)!; // [anchor(light), secondary≈anchor]
    final out = PaletteGenerator.rollPaletteConstrained(
      availablePaints: pool,
      anchors: <Paint?>[null, null],
      slotLrvHints: hints,
      diversifyBrands: false,
    );
    expect(out[0].lch[0] >= 80 && out[0].lch[0] <= 90, true);
  });
}
