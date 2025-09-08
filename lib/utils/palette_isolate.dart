import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/services/analytics_service.dart';

/// Arguments passed to the isolate. All data must be simple/serializable.
class _RollArgs {
  final List<Map<String, dynamic>> available; // Paint.toJson() + 'id'
  final List<Map<String, dynamic>?> anchors; // nullable Paint maps
  final int modeIndex;
  final bool diversify;
  final List<List<double>>? slotLrvHints;
  final List<String>? fixedUndertones;
  final Map<String, dynamic>? themeSpec; // ThemeSpec.toJson()
  final double? themeThreshold;
  final int? attempts;

  _RollArgs({
    required this.available,
    required this.anchors,
    required this.modeIndex,
    required this.diversify,
  this.slotLrvHints,
  this.fixedUndertones,
  this.themeSpec,
  this.themeThreshold,
  this.attempts,
  });

  Map<String, dynamic> toMap() => {
        'available': available,
        'anchors': anchors,
        'modeIndex': modeIndex,
        'diversify': diversify,
        'slotLrvHints': slotLrvHints,
        'fixedUndertones': fixedUndertones,
  'themeSpec': themeSpec,
  'themeThreshold': themeThreshold,
  'attempts': attempts,
      };

  static _RollArgs fromMap(Map<String, dynamic> m) => _RollArgs(
        available: List<Map<String, dynamic>>.from(m['available'] as List),
        anchors: List<Map<String, dynamic>?>.from(m['anchors'] as List),
        modeIndex: m['modeIndex'] as int,
        diversify: m['diversify'] as bool,
        slotLrvHints: m['slotLrvHints'] != null
            ? List<List<double>>.from(
                (m['slotLrvHints'] as List).map((e) => List<double>.from(e)))
            : null,
        fixedUndertones: m['fixedUndertones'] != null
            ? List<String>.from(m['fixedUndertones'] as List)
            : null,
  themeSpec: m['themeSpec'] as Map<String, dynamic>?,
  themeThreshold: m['themeThreshold'] == null ? null : (m['themeThreshold'] as num).toDouble(),
  attempts: m['attempts'] as int?,
      );
}

/// Top-level function for compute(). Returns a List<Map> (Paint.toJson + id).
List<Map<String, dynamic>> rollPaletteInIsolate(Map<String, dynamic> raw) {
  final args = _RollArgs.fromMap(raw);

  // Rehydrate Paint objects inside the isolate
  final available = [
    for (final j in args.available) Paint.fromJson(j, j['id'] as String),
  ];
  final anchors = [
    for (final j in args.anchors)
      (j == null ? null : Paint.fromJson(j, j['id'] as String))
  ];

  // If no theme specified, keep previous behavior
  if (args.themeSpec == null) {
    final rolled = PaletteGenerator.rollPalette(
      availablePaints: available,
      anchors: anchors,
      mode: HarmonyMode.values[args.modeIndex],
      diversifyBrands: args.diversify,
      slotLrvHints: args.slotLrvHints,
      fixedUndertones: args.fixedUndertones,
    );

    return [for (final p in rolled) (p.toJson()..['id'] = p.id)];
  }

  // Rehydrate ThemeSpec
  ThemeSpec spec;
  try {
    spec = ThemeSpec.fromJson(args.themeSpec!);
  } catch (_) {
    // fallback to no-theme behavior on parse error
    final rolled = PaletteGenerator.rollPalette(
      availablePaints: available,
      anchors: anchors,
      mode: HarmonyMode.values[args.modeIndex],
      diversifyBrands: args.diversify,
      slotLrvHints: args.slotLrvHints,
      fixedUndertones: args.fixedUndertones,
    );
    return [for (final p in rolled) (p.toJson()..['id'] = p.id)];
  }

  // Prefilter paints by theme
  final prefiltered = ThemeEngine.prefilter(available, spec);
  final availableForRoll = prefiltered.length < 200 ? available : prefiltered;

  final maxAttempts = args.attempts ?? 10;
  final threshold = args.themeThreshold ?? 0.6;

  double bestScore = -1.0;
  List<Paint> bestPalette = [];

  for (var i = 0; i < maxAttempts; i++) {
    final rolled = PaletteGenerator.rollPalette(
      availablePaints: availableForRoll,
      anchors: anchors,
      mode: HarmonyMode.values[args.modeIndex],
      diversifyBrands: args.diversify,
      slotLrvHints: args.slotLrvHints,
      fixedUndertones: args.fixedUndertones,
    );

    final score = ThemeEngine.scorePalette(rolled, spec);
    if (score > bestScore) {
      bestScore = score;
      bestPalette = rolled;
    }
    if (score >= threshold) break;
  }

  // If bestScore is below threshold, record a breadcrumb for debugging but still return best
  if (bestScore < threshold) {
    try {
      AnalyticsService.instance.logEvent('theme_roll_low_score', {
        'themeId': spec.id,
        'score': bestScore,
        'explain': ThemeEngine.explain(bestPalette, spec),
      });
    } catch (_) {}
  }

  return [for (final p in bestPalette) (p.toJson()..['id'] = p.id)];
}
