import 'package:flutter/foundation.dart' show compute;
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/utils/palette_isolate.dart' as isolate;

class PaletteService {
  Future<List<Paint>> generate({
    required List<Paint> available,
    required List<Paint?> anchors,
    required bool diversifyBrands,
    List<List<double>>? slotLrvHints,
    List<String>? fixedUndertones,
    ThemeSpec? themeSpec,
    double? themeThreshold,
    int attempts = 6,
  }) async {
    final args = {
      'available': [for (final p in available) (p.toJson()..['id'] = p.id)],
      'anchors': [for (final p in anchors) (p == null ? null : (p.toJson()..['id'] = p.id))],
      'modeIndex': 0,
      'diversify': diversifyBrands,
      'slotLrvHints': slotLrvHints,
      'fixedUndertones': fixedUndertones,
      'themeSpec': themeSpec?.toJson(),
      'themeThreshold': themeThreshold,
      'attempts': attempts,
    };
    final result = await compute(isolate.rollPipelineInIsolate, args);
    return [for (final m in result) Paint.fromJson(m, m['id'] as String)];
  }

  /// Collect distinct alternates for one slot (index) given the current anchors.
  Future<List<Paint>> alternatesForSlot({
    required List<Paint> available,
    required List<Paint?> anchors,
    required int slotIndex,
    required bool diversifyBrands,
    List<List<double>>? slotLrvHints,
    List<String>? fixedUndertones,
    ThemeSpec? themeSpec,
    int targetCount = 5,
    int attemptsPerRound = 3,
  }) async {
    final args = {
      'available': [for (final p in available) (p.toJson()..['id'] = p.id)],
      'anchors': [for (final p in anchors) (p == null ? null : (p.toJson()..['id'] = p.id))],
      'slotIndex': slotIndex,
      'diversify': diversifyBrands,
      'slotLrvHints': slotLrvHints,
      'fixedUndertones': fixedUndertones,
      'themeSpec': themeSpec?.toJson(),
      'targetCount': targetCount,
      'attemptsPerRound': attemptsPerRound,
    };
    final result = await compute(isolate.alternatesForSlotInIsolate, args);
    return [for (final m in result) Paint.fromJson(m, m['id'] as String)];
  }
}
