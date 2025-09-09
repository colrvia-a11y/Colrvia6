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
  List<Paint>? lastValidPalette; // Track valid candidates during attempts
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
    
    // Track valid palettes for fallback
    if (ThemeEngine.validatePaletteRules(rolled, spec) == null) {
      lastValidPalette = rolled;
    }
    
    if (score > best) {
      best = score;
      bestPalette = rolled;
    }
    if (score >= threshold) break; // early exit
  }

  // Hard-rule gate: validate bestPalette and repair if needed
  String? validationError = ThemeEngine.validatePaletteRules(bestPalette, spec);
  if (validationError != null) {
    // Attempt 1-2 repair strategies
    List<Paint>? repairedPalette = _attemptPaletteRepair(bestPalette, pool, anchors, spec, validationError);
    
    if (repairedPalette != null) {
      final repairedValidation = ThemeEngine.validatePaletteRules(repairedPalette, spec);
      if (repairedValidation == null) {
        // Repair successful
        bestPalette = repairedPalette;
        best = ThemeEngine.scorePalette(bestPalette, spec);
        validationError = null;
      }
    } else if (lastValidPalette != null) {
      // Fallback to last valid palette seen during attempts
      bestPalette = lastValidPalette;
      best = ThemeEngine.scorePalette(bestPalette, spec);
      validationError = null;
    }
    // If still invalid, we'll return best but log it as invalid
  }

  // Logs for visibility
  try {
    final finalValidation = ThemeEngine.validatePaletteRules(bestPalette, spec);
    final wasRepaired = validationError != null && finalValidation == null;
    final hadValidFallback = lastValidPalette != null && validationError != null;
    
    AnalyticsService.instance.logEvent('theme_roll_summary', {
      'themeId': spec.id,
      'attempts': maxAttempts,
      'bestScore': best,
      'poolSize': pool.length,
      'prefilterSize': pre.length,
      'relaxRounds': (attemptsUsed / 3).floor(),
      if (finalValidation != null) 'finalInvalidReason': finalValidation,
      if (wasRepaired) 'repairedFromError': validationError,
      if (hadValidFallback) 'usedValidFallback': true,
    });
    
    if (best < threshold) {
      AnalyticsService.instance.logEvent('theme_roll_low_score', {
        'themeId': spec.id,
        'score': best,
        'explain': ThemeEngine.explain(bestPalette, spec),
        if (finalValidation != null) 'finalInvalidReason': finalValidation,
      });
    }
    
    // Log repair attempts for observability
    if (validationError != null) {
      AnalyticsService.instance.logEvent('theme_hard_rule_gate', {
        'themeId': spec.id,
        'originalError': validationError,
        'repairAttempted': true,
        'repairSuccessful': wasRepaired,
        'fallbackUsed': hadValidFallback,
        'finalValid': finalValidation == null,
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
  var slotIndex = args['slotIndex'] as int;
  final diversify = args['diversify'] as bool? ?? true;
  final fixedUndertones = args['fixedUndertones'] == null
      ? null
      : List<String>.from(args['fixedUndertones'] as List);
  final themeSpecMap = args['themeSpec'] as Map<String, dynamic>?;
  final targetCount = args['targetCount'] as int? ?? 5;
  final attemptsPerRound = args['attemptsPerRound'] as int? ?? 3;
  final roleName = args['roleName'] as String?;

  // If we have a role name, try to find the matching slot by role metadata
  if (roleName != null) {
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      if (anchor?.metadata?['role'] == roleName) {
        slotIndex = i;
        break;
      }
    }
  }

  // Lock all other slots; leave only [slotIndex] as null
  for (var i = 0; i < anchors.length; i++) {
    if (i != slotIndex) {
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

/// Attempts to repair a palette that fails validation rules.
/// Returns null if repair is not possible.
List<Paint>? _attemptPaletteRepair(
  List<Paint> invalidPalette,
  List<Paint> availablePool,
  List<Paint?> anchors,
  ThemeSpec spec,
  String validationError,
) {
  // Strategy 1: Re-roll with widened L bands for specific missing categories
  if (validationError.contains('whisper') || validationError.contains('anchor')) {
    return _repairMissingCategory(invalidPalette, availablePool, anchors, spec, validationError);
  }
  
  // Strategy 2: Inject specific paint to fix bridge/spacing issues  
  if (validationError.contains('bridge') || validationError.contains('spacing')) {
    return _repairByInjection(invalidPalette, availablePool, spec, validationError);
  }
  
  return null; // No repair strategy available
}

/// Repair by re-rolling with widened L bands for missing categories
List<Paint>? _repairMissingCategory(
  List<Paint> invalidPalette,
  List<Paint> availablePool,
  List<Paint?> anchors,
  ThemeSpec spec,
  String validationError,
) {
  // Determine which category is missing and widen its L range
  List<List<double>>? hints = ThemeEngine.slotLrvHintsFor(anchors.length, spec);
  if (hints == null) return null;
  
  // Widen L bands based on missing category
  if (validationError.contains('whisper')) {
    // Widen high L range for whisper (light colors)
    hints = hints.map((h) => [h[0], (h[1] + 15.0).clamp(0.0, 100.0)]).toList();
  } else if (validationError.contains('anchor')) {
    // Widen low L range for anchor (dark colors)  
    hints = hints.map((h) => [(h[0] - 15.0).clamp(0.0, 100.0), h[1]]).toList();
  }
  
  // Try a single re-roll with widened bands
  try {
    final repaired = PaletteGenerator.rollPaletteConstrained(
      availablePaints: availablePool,
      anchors: anchors,
      slotLrvHints: hints,
      diversifyBrands: true,
      tonePenaltySoft: 0.85, // More relaxed
    );
    return repaired;
  } catch (_) {
    return null;
  }
}

/// Repair by swapping a single slot with the nearest candidate that fixes the rule
List<Paint>? _repairByInjection(
  List<Paint> invalidPalette,
  List<Paint> availablePool,
  ThemeSpec spec,
  String validationError,
) {
  if (validationError.contains('bridge')) {
    return _injectBridgeNeutral(invalidPalette, availablePool, spec);
  }
  
  if (validationError.contains('spacing')) {
    return _fixSpacingIssue(invalidPalette, availablePool, spec);
  }
  
  return null;
}

/// Inject a bridge neutral when warm and cool chromatic colors mix
List<Paint>? _injectBridgeNeutral(
  List<Paint> palette,
  List<Paint> availablePool,
  ThemeSpec spec,
) {
  // Find best mid-LRV low-chroma neutral candidate
  final candidates = availablePool
      .where((p) => !palette.contains(p))
      .where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) < 10.0) // Low chroma
      .where((p) => p.computedLrv >= 20 && p.computedLrv <= 60); // Mid LRV
  
  if (candidates.isEmpty) return null;
  
  // Find candidate closest to LRV 40 (ideal bridge)
  Paint? bestCandidate;
  double bestDistance = double.infinity;
  for (final candidate in candidates) {
    final distance = (candidate.computedLrv - 40.0).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestCandidate = candidate;
    }
  }
  
  if (bestCandidate == null) return null;
  
  // Replace least important paint (typically last slot) with bridge
  final result = List<Paint>.from(palette);
  result[result.length - 1] = bestCandidate;
  return result;
}

/// Fix spacing issues by swapping problematic paint
List<Paint>? _fixSpacingIssue(
  List<Paint> palette,
  List<Paint> availablePool,
  ThemeSpec spec,
) {
  // Find paints that are too close in LRV and try to replace one
  for (int i = 0; i < palette.length - 1; i++) {
    final current = palette[i];
    final next = palette[i + 1];
    final lrvDiff = (current.computedLrv - next.computedLrv).abs();
    
    if (lrvDiff < 10.0) { // Too close
      // Try to find a replacement for the second paint
      final targetLrv = current.computedLrv > 50 ? current.computedLrv - 20 : current.computedLrv + 20;
      final candidates = availablePool
          .where((p) => !palette.contains(p))
          .where((p) => (p.computedLrv - targetLrv).abs() < 15.0);
      
      if (candidates.isNotEmpty) {
        final replacement = candidates.first;
        final result = List<Paint>.from(palette);
        result[i + 1] = replacement;
        return result;
      }
    }
  }
  
  return null;
}
