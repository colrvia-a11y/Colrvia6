import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart' show Paint;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeEngine prefilter and hints and scoring for coastal', () async {
    await ThemeService.instance.loadFromAssetIfNeeded();
    final coastal = ThemeService.instance.byId('coastal');
    expect(coastal, isNotNull);

    // create small mixed paints list: some that match coastal neutrals/accents and some outside
    final paints = <Paint>[
      Paint.fromJson({
        'hex': '#f6f7f8',
        'lab': [95, 0, 0],
        'lch': [92, 1, 200],
        'rgb': [246, 247, 248],
        'brandName': 'A'
      }, 'p1'),
      Paint.fromJson({
        'hex': '#1f5f6f',
        'lab': [30, 10, 10],
        'lch': [40, 15, 190],
        'rgb': [31, 95, 111],
        'brandName': 'B'
      }, 'p2'),
      Paint.fromJson({
        'hex': '#004488',
        'lab': [30, 40, 20],
        'lch': [30, 45, 210],
        'rgb': [0, 68, 136],
        'brandName': 'C'
      }, 'p3'),
      Paint.fromJson({
        'hex': '#ff00ff',
        'lab': [50, 60, 40],
        'lch': [50, 75, 300],
        'rgb': [255, 0, 255],
        'brandName': 'D'
      }, 'p4'),
    ];

    final filtered = ThemeEngine.prefilter(paints, coastal!);
    expect(filtered.isNotEmpty, true);

    final hints = ThemeEngine.slotLrvHintsFor(3, coastal);
    expect(hints, isNotNull);
    expect(hints!.length, 3);
    // anchor L should be bright for coastal
    final anchorRange = hints[0];
    expect(anchorRange[0] >= 80 || anchorRange[1] >= 80, true);

    final coastalPalette = [
      filtered.first,
      filtered.length > 1 ? filtered[1] : filtered.first,
      filtered.first
    ];
    final score = ThemeEngine.scorePalette(coastalPalette, coastal);
    expect(score > 0.6, true);
  });
}
