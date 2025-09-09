import 'package:flutter/foundation.dart' show compute;
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_isolate.dart' as isolate;
import 'package:color_canvas/roller_theme/theme_spec.dart';

/// A thin facade over the existing isolate entrypoint so all generation funnels through here.
class PaletteService {
  /// Generate a full palette.
  Future<List<Paint>> generate({
    required List<Paint> available,
    required List<Paint?> anchors, // length should match desired strips; null for unlocked
    required bool diversifyBrands,
    List<List<double>>? slotLrvHints,
    List<String>? fixedUndertones,
    ThemeSpec? themeSpec,
    double? themeThreshold,
    int attempts = 6,
  }) async {
    // compute() requires top-level plain-data args; reuse the isolate's map format
    final args = {
      'available': [for (final p in available) (p.toJson()..['id'] = p.id)],
      'anchors': [
        for (final p in anchors) (p == null ? null : (p.toJson()..['id'] = p.id))
      ],
      'modeIndex': 0, // HarmonyMode is fixed in isolate impl; you can expose later
      'diversify': diversifyBrands,
      'slotLrvHints': slotLrvHints,
      'fixedUndertones': fixedUndertones,
      'themeSpec': themeSpec?.toJson(),
      'themeThreshold': themeThreshold,
      'attempts': attempts,
    };

    final result = await compute(isolate.rollPaletteInIsolate, args);
    // Rehydrate Paints
    return [
      for (final m in result) Paint.fromJson(m, m['id'] as String),
    ];
  }
}
