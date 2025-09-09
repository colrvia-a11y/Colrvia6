import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/services/analytics_service.dart';

// ---------- Internal helpers (pure functions) ----------
List<Paint> _rehydrate(List<Map<String, dynamic>> maps) => [
      for (final m in maps) Paint.fromJson(m, m['id'] as String),
    ];

List<Map<String, dynamic>> _dehydrate(List<Paint> paints) => [
      for (final p in paints) (p.toJson()..['id'] = p.id),
    ];

class _PipelineArgs {
  _PipelineArgs({
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

  final List<Map<String, dynamic>> available;
  final List<Map<String, dynamic>?> anchors;
  final int modeIndex;
  final bool diversify;
  final List<List<double>>? slotLrvHints;
  final List<String>? fixedUndertones;
  final Map<String, dynamic>? themeSpec;
  final double? themeThreshold;
  final int? attempts;

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

  static _PipelineArgs from(Map<String, dynamic> m) => _PipelineArgs(
        available: List<Map<String, dynamic>>.from(m['available'] as List),
        anchors: List<Map<String, dynamic>?>.from(m['anchors'] as List),
        modeIndex: m['modeIndex'] as int? ?? 0,
        diversify: m['diversify'] as bool? ?? true,
        slotLrvHints: m['slotLrvHints'] == null
            ? null
            : List<List<double>>.from(
                (m['slotLrvHints'] as List).map((e) => List<double>.from(e))),
        fixedUndertones: m['fixedUndertones'] == null
            ? null
            : List<String>.from(m['fixedUndertones'] as List),
        themeSpec: m['themeSpec'] as Map<String, dynamic>?,
        themeThreshold: (m['themeThreshold'] as num?)?.toDouble(),
        attempts: m['attempts'] as int?,
      );
}

List<Paint> _pipeRollBase({
  required List<Paint> available,
  required List<Paint?> anchors,
  required int modeIndex,
  required bool diversify,
  List<List<double>>? slotLrvHints,
  List<String>? fixedUndertones,
}) {
  return PaletteGenerator.rollPalette(
    availablePaints: available,
    anchors: anchors,
    mode: HarmonyMode.values[modeIndex],
    diversifyBrands: diversify,
    slotLrvHints: slotLrvHints,
    fixedUndertones: fixedUndertones,
  );
}

// _pipeMaybeScoreTheme was used by pre-constrained themed alternates; removed after
// switching to constrained generator in both main roll and alternates paths.

// ---------- New public entrypoints ----------
List<Map<String, dynamic>> rollPipelineInIsolate(Map<String, dynamic> argsMap) {
  final args = _PipelineArgs.from(argsMap);
  final themedOrBrandOnly = _rehydrate(args.available);
  final anchors = [
    for (final m in args.anchors)
      (m == null ? null : Paint.fromJson(m, m['id'] as String))
  ];

  // Optional wider brand-only pool for auto-relax fallback
  final brandOnlyRaw =
      (argsMap['availableBrandOnly'] as List?)?.cast<Map<String, dynamic>>();
  final brandOnly =
      brandOnlyRaw == null ? themedOrBrandOnly : _rehydrate(brandOnlyRaw);

  if (args.themeSpec == null) {
    final rolled = _pipeRollBase(
      available: themedOrBrandOnly,
      anchors: anchors,
      modeIndex: args.modeIndex,
      diversify: args.diversify,
      slotLrvHints: args.slotLrvHints,
      fixedUndertones: args.fixedUndertones,
    );
    return _dehydrate(rolled);
  }

  // Rehydrate ThemeSpec and apply prefilter with auto-relax
  final spec = ThemeSpec.fromJson(args.themeSpec!);
  final pre = ThemeEngine.prefilter(brandOnly, spec);
  final pool = pre.length < 120 ? brandOnly : pre; // auto-relax if too small

  final maxAttempts =
      args.attempts ?? 10; // service should default, but enforce here
  final threshold = args.themeThreshold ?? 0.6;

  double best = -1.0;
  List<Paint> bestPalette = const [];
  int attemptsUsed = 0;
  for (; attemptsUsed < maxAttempts; attemptsUsed++) {
    final hintsBase = args.slotLrvHints ??
        ThemeEngine.slotLrvHintsFor(anchors.length, spec) ??
        List<List<double>>.generate(anchors.length, (_) => [0.0, 100.0]);
    final relaxRound = attemptsUsed ~/ 3; // every 3 attempts, widen a bit
    final double relaxL = relaxRound == 0 ? 0.0 : (relaxRound * 3.0).clamp(0.0, 8.0);
    final hints = [
      for (final h in hintsBase)
        [
          (h[0] - relaxL).clamp(0.0, 100.0),
          (h[1] + relaxL).clamp(0.0, 100.0),
        ]
    ];
    final tonePenaltySoft = relaxRound == 0 ? 0.7 : 0.85;

    final rolled = PaletteGenerator.rollPaletteConstrained(
      availablePaints: pool,
      anchors: anchors,
      slotLrvHints: hints,
      fixedUndertones: args.fixedUndertones,
      diversifyBrands: args.diversify,
      tonePenaltySoft: tonePenaltySoft,
    );
    final score = ThemeEngine.scorePalette(rolled, spec);
    if (score > best) {
      best = score;
      bestPalette = rolled;
    }
    if (score >= threshold) break; // early exit
  }

  // Logs for visibility
  try {
    final invalid = ThemeEngine.validatePaletteRules(bestPalette, spec);
    AnalyticsService.instance.logEvent('theme_roll_summary', {
      'themeId': spec.id,
      'attempts': maxAttempts,
      'bestScore': best,
      'poolSize': pool.length,
      'prefilterSize': pre.length,
      'relaxRounds': (attemptsUsed / 3).floor(),
      if (invalid != null) 'invalidReason': invalid,
    });
    if (best < threshold) {
      AnalyticsService.instance.logEvent('theme_roll_low_score', {
        'themeId': spec.id,
        'score': best,
        'explain': ThemeEngine.explain(bestPalette, spec),
        if (invalid != null) 'invalidReason': invalid,
      });
    }
  } catch (_) {}

  return _dehydrate(bestPalette);
}

/// Produce distinct alternates for a single [slotIndex] while keeping other slots fixed.
List<Map<String, dynamic>> alternatesForSlotInIsolate(
    Map<String, dynamic> args) {
  final available =
      _rehydrate(List<Map<String, dynamic>>.from(args['available'] as List));
  final anchors = [
    for (final m in List<Map<String, dynamic>?>.from(args['anchors'] as List))
      (m == null ? null : Paint.fromJson(m, m['id'] as String))
  ];
  final slotIndex = args['slotIndex'] as int;
  final diversify = args['diversify'] as bool? ?? true;
  final fixedUndertones = args['fixedUndertones'] == null
      ? null
      : List<String>.from(args['fixedUndertones'] as List);
  final themeSpecMap = args['themeSpec'] as Map<String, dynamic>?;
  final targetCount = args['targetCount'] as int? ?? 5;
  final attemptsPerRound = args['attemptsPerRound'] as int? ?? 3;

  // Lock all other slots; leave only [slotIndex] as null
  for (var i = 0; i < anchors.length; i++) {
    if (i != slotIndex)
      anchors[i] = anchors[i] ??
          Paint.fromJson({
            'hex': '#000000',
            'lab': [0, 0, 0],
            'lch': [0, 0, 0],
            'rgb': [0, 0, 0],
            'brandName': '',
            'brandId': ''
          }, 'LOCK');
  }
  anchors[slotIndex] = null; // ensure target slot is unlocked

  final out = <Paint>[];
  final seenIds = <String>{};

  ThemeSpec? spec;
  if (themeSpecMap != null) {
    try {
      spec = ThemeSpec.fromJson(themeSpecMap);
    } catch (_) {
      spec = null;
    }
  }

  while (out.length < targetCount) {
    for (var i = 0; i < attemptsPerRound && out.length < targetCount; i++) {
      List<Paint> rolled;
      if (spec == null) {
        // Non-themed: keep legacy behavior
        rolled = _pipeRollBase(
          available: available,
          anchors: anchors,
          modeIndex: 0,
          diversify: diversify,
          fixedUndertones: fixedUndertones,
        );
      } else {
        // Themed alternates: prefilter (with auto-relax) and use constrained per-slot roll
        final pre = ThemeEngine.prefilter(available, spec);
        final pool = pre.length < 80 ? available : pre;
        final hints = ThemeEngine.slotLrvHintsFor(anchors.length, spec) ??
            List<List<double>>.generate(anchors.length, (_) => [0.0, 100.0]);
        rolled = PaletteGenerator.rollPaletteConstrained(
          availablePaints: pool,
          anchors: anchors,
          slotLrvHints: hints,
          fixedUndertones: fixedUndertones,
          diversifyBrands: diversify,
        );
      }
      if (rolled.isEmpty) continue;
      final candidate = rolled[slotIndex];
      if (!seenIds.contains(candidate.id)) {
        seenIds.add(candidate.id);
        out.add(candidate);
      }
    }
    if (out.isEmpty) break; // give up gracefully
  }

  return _dehydrate(out);
}

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
        themeThreshold: m['themeThreshold'] == null
            ? null
            : (m['themeThreshold'] as num).toDouble(),
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
  final availableForRoll = prefiltered.isEmpty ? available : prefiltered;

  final maxAttempts = args.attempts ?? 10;
  final threshold = args.themeThreshold ?? 0.6;

  double bestScore = -1.0;
  List<Paint> bestPalette = [];

  for (var i = 0; i < maxAttempts; i++) {
    final hints = args.slotLrvHints ??
        ThemeEngine.slotLrvHintsFor(anchors.length, spec) ??
        List<List<double>>.generate(anchors.length, (_) => [0.0, 100.0]);
    final rolled = PaletteGenerator.rollPaletteConstrained(
      availablePaints: availableForRoll,
      anchors: anchors,
      slotLrvHints: hints,
      fixedUndertones: args.fixedUndertones,
      diversifyBrands: args.diversify,
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
      final invalid = ThemeEngine.validatePaletteRules(bestPalette, spec);
      AnalyticsService.instance.logEvent('theme_roll_low_score', {
        'themeId': spec.id,
        'score': bestScore,
        'explain': ThemeEngine.explain(bestPalette, spec),
        if (invalid != null) 'invalidReason': invalid,
      });
    } catch (_) {}
  }

  return [for (final p in bestPalette) (p.toJson()..['id'] = p.id)];
}
