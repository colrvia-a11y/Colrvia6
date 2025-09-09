// Theme Engine — summary
//
// What it does
// - Prefilters paints by ThemeSpec LCH windows (neutrals/accents)
// - Validates hard rules (fail fast):
//   • extremes: must include a very light (L≥70) and a very dark (L<15) when size≥3
//   • spacing: reject palettes with min adjacent L gap < 5
//   • warm/cool mix requires a neutral mid-L bridge (low C within ~35≤L≤75)
// - Scores palettes with soft metrics (weightable via ThemeSpec.weights):
//   • neutralShare, forbiddenHuePenalty, saturationDiscipline, harmonyMatch,
//   • accentContrast, warmBias/coolBias, brandDiversity,
//   • valueCoverage, valueSpread, spacingBonus,
//   • undertoneCohesion (with bridge awareness), temperatureBalance (dominant ~80/20)
// - Provides per-slot L (LRV) hints to the generator for theme-guided rolls
//
// Slot→Role mapping (source of truth = ThemeSpec.roleTargets):
// - slot 0 = anchor (roleTargets.anchor L)
// - slot 1 = secondary (roleTargets.secondary L if present, else anchor±Δ)
// - slots 2+ = accents (roleTargets.accent L if present, else anchor spread)
// Use ThemeEngine.slotLrvHintsFor(size, spec) to obtain per-slot L ranges.
//
// Further reading
// - Theme README: docs/README.md
// - Architecture Guide: Roller_Architecture_Theme_Guide.md

import 'dart:math';

import 'package:color_canvas/firestore/firestore_data_schema.dart' show Paint;
import 'package:color_canvas/utils/color_utils.dart';
import 'theme_spec.dart';

class ThemeEngine {
  // ---------- Basic neutral test (theme-driven chroma cutoff) ----------
  static bool _isNeutral(Paint p, ThemeSpec spec) {
    final c = p.lch.length > 1 ? p.lch[1] : 0.0;
    final neutralMax = spec.neutrals?.C?.max ?? 12.0;
    return c <= neutralMax;
  }

  static List<double> _accentHues(List<Paint> palette, ThemeSpec spec) {
    final neutralMax = spec.neutrals?.C?.max ?? 12.0;
    final out = <double>[];
    for (final p in palette) {
      final c = p.lch.length > 1 ? p.lch[1] : 0.0;
      if (c > neutralMax) {
        final h = p.lch.length > 2 ? (p.lch[2] % 360) : 0.0;
        out.add(h < 0 ? h + 360 : h);
      }
    }
    return out;
  }

  // Count "pop" colors based on chroma threshold
  static int _countPops(List<Paint> palette, double popChromaMin) {
    return palette
        .where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) >= popChromaMin)
        .length;
  }

  // Check if palette is muted (median chroma of non-pop colors < threshold)
  static bool _isMutedPalette(List<Paint> palette, double popChromaMin, double mutedThreshold) {
    final nonPops = palette
        .where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) < popChromaMin)
        .map((p) => p.lch.length > 1 ? p.lch[1] : 0.0)
        .toList();
    
    if (nonPops.isEmpty) {
      return false;
    }
    
    nonPops.sort();
    final median = nonPops.length % 2 == 0
        ? (nonPops[nonPops.length ~/ 2 - 1] + nonPops[nonPops.length ~/ 2]) / 2
        : nonPops[nonPops.length ~/ 2];
    
    return median < mutedThreshold;
  }

  // Prefilter paints by LCH windows in spec.neutrals or spec.accents
  static List<Paint> prefilter(List<Paint> paints, ThemeSpec spec) {
    if (spec.neutrals == null && spec.accents == null) {
      return paints;
    }
    final out = <Paint>[];
    for (final p in paints) {
      final l = p.lch.isNotEmpty ? p.lch[0] : 0.0;
      final c = p.lch.length > 1 ? p.lch[1] : 0.0;
      double h = 0.0;
      if (p.lch.length > 2) {
        h = p.lch[2] % 360;
        if (h < 0) h += 360;
      }

      final inNeutral = _inRange3(spec.neutrals, l, c, h);
      final inAccent = _inRange3(spec.accents, l, c, h);
      if (inNeutral || inAccent) out.add(p);
    }
    return out;
  }

  // Return slot L (LRV) hints as ranges [min,max] per slot or null.
  // Theme overrides generic role defaults; mapping is:
  //  - slot 0 = anchor (roleTargets.anchor L)
  //  - slot 1 = secondary (roleTargets.secondary L if present, else anchor ± Δ)
  //  - slots 2+ = accents (roleTargets.accent L if present, else anchor spread)
  // If ThemeSpec does not provide role targets, this returns null.
  static List<List<double>>? slotLrvHintsFor(int size, ThemeSpec spec) {
    final rt = spec.roleTargets;
    final anchorL = rt?.anchor?.L;
    if (anchorL == null) {
      return null;
    }
    final secondaryL = rt?.secondary?.L;
    final accentL = rt?.accent?.L;

    final out = <List<double>>[];
    for (var i = 0; i < size; i++) {
      if (i == 0) {
        out.add([_clamp01Range(anchorL.min), _clamp01Range(anchorL.max)]);
      } else if (i == 1) {
        if (secondaryL != null) {
          out.add(
              [_clamp01Range(secondaryL.min), _clamp01Range(secondaryL.max)]);
        } else {
          // near anchor ±8
          final lo = (anchorL.min - 8.0).clamp(0.0, 100.0);
          final hi = (anchorL.max + 8.0).clamp(0.0, 100.0);
          out.add([lo, hi]);
        }
      } else {
        if (accentL != null) {
          out.add([_clamp01Range(accentL.min), _clamp01Range(accentL.max)]);
        } else {
          // fallback to anchor spread
          out.add([_clamp01Range(anchorL.min), _clamp01Range(anchorL.max)]);
        }
      }
    }
    return out;
  }

  // ---------- Blueprint helper utilities ----------
  // Value buckets & spacing
  static bool _hasVeryLight(List<Paint> p) =>
      p.any((x) => (x.lch.isNotEmpty ? x.lch[0] : 0.0) >= 70.0);
  static bool _hasVeryDark(List<Paint> p) =>
      p.any((x) => (x.lch.isNotEmpty ? x.lch[0] : 0.0) < 15.0);
  static double _valueSpread(List<Paint> p) {
    final l = p.map((x) => x.lch.isNotEmpty ? x.lch[0] : 0.0).toList()..sort();
    return l.isEmpty ? 0.0 : ((l.last - l.first) / 100.0).clamp(0.0, 1.0);
  }
  static double _minSpacing(List<Paint> p) {
    final l = p.map((x) => x.lch.isNotEmpty ? x.lch[0] : 0.0).toList()..sort();
    if (l.length < 2) return 1.0;
    double minGap = 999.0;
    for (var i = 1; i < l.length; i++) {
      minGap = min(minGap, (l[i] - l[i - 1]).abs());
    }
    return minGap; // units in L*
  }

  // Temperature & undertone
  static bool _isWarmHue(double h) =>
      (h >= 20 && h <= 70) || (h >= 330 || h <= 20);
  static bool _isCoolHue(double h) => (h >= 70 && h <= 250);
  static Map<String, int> _temperatureCounts(List<Paint> p) {
    int warm = 0, cool = 0, neutralish = 0;
    for (final x in p) {
      final h = x.lch.length > 2 ? ((x.lch[2] % 360) + 360) % 360 : 0.0;
      if (_isWarmHue(h)) {
        warm++;
      } else if (_isCoolHue(h)) {
        cool++;
      } else {
        neutralish++;
      }
    }
    return {'warm': warm, 'cool': cool, 'neutral': neutralish};
  }

  // Undertone families using metadata when present; fallback to hue families
  static String _undertoneKey(Paint p) {
    final u = p.undertone;
    if (u != null && u.isNotEmpty) {
      return u.split('/').first.toLowerCase();
    }
    final h = p.lch.length > 2 ? ((p.lch[2] % 360) + 360) % 360 : 0.0;
    if (_isWarmHue(h)) {
      return 'warm';
    }
    if (_isCoolHue(h)) {
      return 'cool';
    }
    return 'neutral';
  }
  static double _undertoneVariance(List<Paint> p) {
    if (p.isEmpty) {
      return 0.0;
    }
    final groups = <String, int>{};
    for (final x in p) {
      final k = _undertoneKey(x);
      groups[k] = (groups[k] ?? 0) + 1;
    }
    final n = p.length;
    final maxShare = groups.values.fold<int>(0, (a, b) => max(a, b));
    return 1.0 - (maxShare / n);
  }
  static bool _needsBridge(List<Paint> p) {
    final t = _temperatureCounts(p);
    return (t['warm']! > 0 && t['cool']! > 0);
  }
  static bool _hasBridgeColor(List<Paint> p, ThemeSpec spec) {
    final cMax = spec.neutrals?.C?.max ?? 12.0;
    return p.any((x) {
      final c = x.lch.length > 1 ? x.lch[1] : 0.0;
      final l = x.lch.isNotEmpty ? x.lch[0] : 0.0;
      return c <= cMax && l >= 35.0 && l <= 75.0; // mid neutral bridge
    });
  }

  // Hard-rule validator; return a reason or null if valid
  static String? validatePaletteRules(List<Paint> palette, ThemeSpec spec) {
    if (palette.isEmpty) return 'empty';
    // Strong value presence when size >= 3
    if (palette.length >= 3) {
      if (!_hasVeryLight(palette)) return 'no_very_light';
      if (!_hasVeryDark(palette)) return 'no_very_dark';
    }
    // Basic spacing sanity (hard reject only if extremely tight)
    final minGap = _minSpacing(palette);
    if (palette.length >= 3 && minGap < 5.0) return 'values_too_close';
    // Undertone bridge requirement when both temps present
    if (_needsBridge(palette) && !_hasBridgeColor(palette, spec)) {
      return 'no_bridge_for_warm_cool_mix';
    }
    
    // Pop accent constraint validation
    final vc = spec.varietyControls;
    if (vc?.maxPops != null && vc?.popChromaMin != null) {
      final pops = _countPops(palette, vc!.popChromaMin!);
      if (pops > vc.maxPops!) {
        return 'too_many_pops';
      }
    }
    
    return null;
  }

  // ---------- New rule metrics ----------
  // Undertone cohesion: 1.0 if all chromatic paints are from one temp family
  // or if both are present but a mid-LRV neutral (low C) bridges them.
  static double _undertoneCohesion(List<Paint> palette, ThemeSpec spec) {
    if (palette.length <= 1) return 1.0;
    final neutralMax = spec.neutrals?.C?.max ?? 12.0;

    // Consider only chromatic paints for warm/cool mixing evaluation
    final chroma = palette
        .where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) > neutralMax)
        .toList();
    if (chroma.length <= 1) {
      return 1.0; // single chromatic family or none
    }

    // If we don't actually mix warm & cool, it's cohesive
    int warm = 0, cool = 0;
    for (final p in chroma) {
      final h = p.lch.length > 2 ? ((p.lch[2] % 360) + 360) % 360 : 0.0;
      if (_isWarmHue(h)) {
        warm++;
      } else if (_isCoolHue(h)) {
        cool++;
      }
    }
    if (warm == 0 || cool == 0) {
      return 1.0;
    }

    // Mixed warm/cool: require a neutral mid-L bridge, else penalize by variance
    if (_hasBridgeColor(palette, spec)) {
      return 1.0;
    }

    // Variance across undertone families for chromatic paints
    final variance = _undertoneVariance(chroma); // 0 (cohesive) .. ~0.5 (evenly split)
    // Map variance to cohesion; steeper penalty for even splits without a bridge
    final cohesion = (1.0 - variance * 1.5).clamp(0.25, 1.0);
    return cohesion;
  }

  // Value coverage: ensure at least one very light (>=70), one very dark (<15),
  // and at least one mid (30..60) when size >= 3. Returns 1.0 if satisfied, else 0..0.7.
  static double _valueCoverage(List<Paint> palette) {
    if (palette.isEmpty) return 0.0;
    final lrvs = palette.map((p) => p.lch.isNotEmpty ? p.lch[0] : 0.0).toList();
    final minL = lrvs.reduce(min);
    final maxL = lrvs.reduce(max);
    final hasLight = maxL >= 70.0;
    final hasDark = minL < 15.0;
    final hasMid = lrvs.any((l) => l >= 30.0 && l <= 60.0);
    if (palette.length <= 2) {
  // For 1..2 colors: require strong contrast within 20–30 L range
  final span = (maxL - minL).abs();
  if (span <= 20.0) return 0.0;
  if (span >= 30.0) return 1.0;
  return ((span - 20.0) / 10.0).clamp(0.0, 1.0);
    }
    int ok = 0;
    if (hasLight) ok++;
    if (hasDark) ok++;
    if (hasMid) ok++;
    return ok == 3 ? 1.0 : (ok == 2 ? 0.7 : 0.0);
  }

  // (Deprecated) _valueSpreadScore removed in favor of normalized _valueSpread + spacingBonus

  // Temperature balance: reward a dominant family around ~80% (+/- 10%).
  static double _temperatureBalance(List<Paint> palette) {
    if (palette.isEmpty) return 1.0;
    int warm = 0, cool = 0;
    for (final p in palette) {
      final c = p.lch.length > 1 ? p.lch[1] : 0.0;
      // ignore near-neutrals to avoid skewing by whites/darks
      if (c <= 12.0) continue;
      final h = p.lch.length > 2 ? ((p.lch[2] % 360) + 360) % 360 : 0.0;
      final isWarm = _isWarmHue(h);
      final isCool = _isCoolHue(h);
      if (isWarm) {
        warm++;
      } else if (isCool) {
        cool++;
      }
    }
    final n = max(1, warm + cool).toDouble();
    final majority = max(warm, cool) / n; // 0.5..1.0
    // Map majority proportion to score peaked at 0.8 (±0.1 tolerance)
    final diff = (majority - 0.8).abs();
    if (majority <= 0.55) return 0.0; // near 50/50
    if (diff <= 0.1) return 1.0;
    // linear falloff: 0.1..0.3 -> 1..0
    final t = ((0.3 - diff) / 0.2).clamp(0.0, 1.0);
    return t;
  }

  // Dominant vs. Secondary separation: ensure clear difference by hue or value
  static List<Paint> _identifyDominantSecondary(List<Paint> palette) {
    if (palette.length < 2) return palette;
    
    // Filter to mid-tone "body" colors (L between 25-75) suitable for dominant/secondary roles
    final midTones = palette
        .where((p) {
          final l = p.lch.isNotEmpty ? p.lch[0] : 0.0;
          return l >= 25.0 && l <= 75.0;
        })
        .toList();
    
    if (midTones.length < 2) {
      // Fallback: use first two paints if not enough mid-tones
      return [palette[0], palette[1]];
    }
    
    // Sort by L value and pick two most representative mid-tones
    midTones.sort((a, b) => (a.lch[0]).compareTo(b.lch[0]));
    
    // Take paints from different parts of the L range for better separation
    if (midTones.length == 2) {
      return midTones;
    } else {
      // Pick from lower and upper mid-tone ranges
      final lowerMid = midTones.take(midTones.length ~/ 2).toList();
      final upperMid = midTones.skip(midTones.length ~/ 2).toList();
      return [lowerMid.last, upperMid.first];
    }
  }

  static double _dominantSecondarySeparation(List<Paint> palette) {
    if (palette.length < 2) return 1.0;
    
    final domSec = _identifyDominantSecondary(palette);
    if (domSec.length < 2) return 1.0;
    
    final dominant = domSec[0];
    final secondary = domSec[1];
    
    // Calculate L (value) difference
    final lDom = dominant.lch.isNotEmpty ? dominant.lch[0] : 0.0;
    final lSec = secondary.lch.isNotEmpty ? secondary.lch[0] : 0.0;
    final deltaL = (lDom - lSec).abs();
    
    // Calculate H (hue) difference
    final hDom = dominant.lch.length > 2 ? ((dominant.lch[2] % 360) + 360) % 360 : 0.0;
    final hSec = secondary.lch.length > 2 ? ((secondary.lch[2] % 360) + 360) % 360 : 0.0;
    var deltaH = (hDom - hSec).abs();
    if (deltaH > 180) deltaH = 360 - deltaH; // shorter arc
    
    // Score 1.0 if ΔL ≥ 8 or ΔH ≥ 25°
    if (deltaL >= 8.0 || deltaH >= 25.0) return 1.0;
    
    // Penalize when both ΔL < 5 and ΔH < 12°
    if (deltaL < 5.0 && deltaH < 12.0) return 0.0;
    
    // Linear interpolation for intermediate cases
    double lScore = deltaL < 5.0 ? 0.0 : ((deltaL - 5.0) / (8.0 - 5.0)).clamp(0.0, 1.0);
    double hScore = deltaH < 12.0 ? 0.0 : ((deltaH - 12.0) / (25.0 - 12.0)).clamp(0.0, 1.0);
    
    // Return the maximum of L or H separation scores
    return max(lScore, hScore);
  }

  static double scorePalette(List<Paint> palette, ThemeSpec spec) {
    if (palette.isEmpty) return 0.0;
  // Hard-rule validation: any invalid -> hard gate at 0.0
  final invalid = validatePaletteRules(palette, spec);
  if (invalid != null) return 0.0;


    // v2: hard gates from varietyControls
    final vc = spec.varietyControls;
    if (vc != null) {
      // count range gating
      if (palette.length < vc.minColors || palette.length > vc.maxColors) {
        return 0.0;
      }
      // must include neutral
      if (vc.mustIncludeNeutral && !palette.any((p) => _isNeutral(p, spec))) {
        return 0.0;
      }
      // must include accent (chroma > neutral C max)
      if (vc.mustIncludeAccent && _accentHues(palette, spec).isEmpty) {
        return 0.0;
      }
    }

    final weights = spec.weights;
    double weightedSum = 0.0;
    double sumWeights = 0.0;

    // neutralShare
    final neutralCMax = spec.neutrals?.C?.max ?? 12.0;
    final neutralCount = palette
        .where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) <= neutralCMax)
        .length;
    final neutralShare = neutralCount / palette.length;
    _accumulate('neutralShare', neutralShare, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // forbidden hues -> hueAllowed (1.0 if none offending, else 1 - share offending)
    final forbidden = spec.forbiddenHues;
    int offending = 0;
    for (final p in palette) {
      final hue = (p.lch.length > 2 ? p.lch[2] % 360 : 0.0);
      if (_inForbidden(hue, forbidden)) offending++;
    }
    final hueAllowed =
        offending == 0 ? 1.0 : max(0.0, 1.0 - (offending / palette.length));
    _accumulate('forbiddenHuePenalty', hueAllowed, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // saturationDiscipline: average of per-color (allowedMax / C) capped at 1.0
    final allowedMaxC = spec.accents?.C?.max ?? 20.0;
    double satSum = 0.0;
    for (final p in palette) {
      final c = p.lch.length > 1 ? p.lch[1] : 0.0;
      final val = c <= allowedMaxC ? 1.0 : (allowedMaxC / c).clamp(0.0, 1.0);
      satSum += val;
    }
    final saturationDiscipline = satSum / palette.length;
    _accumulate('saturationDiscipline', saturationDiscipline, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // harmonyMatch
    double harmonyMatch = 0.0;
    if (spec.harmonyBias.contains('analogous')) {
      final hues = palette
          .map((p) => (p.lch.length > 2 ? p.lch[2] % 360 : 0.0))
          .toList();
      if (hues.isNotEmpty) {
        final span = _hueSpan(hues);
        if (span <= 60.0) harmonyMatch = 1.0;
      }
    }
    if (spec.harmonyBias.contains('neutral-plus-accent')) {
      final hasNeutral = palette
          .any((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) <= neutralCMax);
      final hasAccent =
          palette.any((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) > neutralCMax);
      if (hasNeutral && hasAccent) harmonyMatch = max(harmonyMatch, 1.0);
    }
    _accumulate('harmonyMatch', harmonyMatch, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // accentContrast: contrast between darkest and lightest (by L) pair
    final sortedByL = List<Paint>.from(palette)
      ..sort((a, b) => (a.lch[0]).compareTo(b.lch[0]));
    double accentContrast = 0.0;
    if (sortedByL.length >= 2) {
      final low = ColorUtils.hexToColor(sortedByL.first.hex);
      final high = ColorUtils.hexToColor(sortedByL.last.hex);
      final contrast = contrastRatio(low, high);
      accentContrast = (contrast / 7.0).clamp(0.0, 1.0);
    }
    _accumulate('accentContrast', accentContrast, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // warmBias / coolBias
    final hues =
        palette.map((p) => (p.lch.length > 2 ? p.lch[2] % 360 : 0.0)).toList();
    final warmCount =
    hues.where((h) => _isWarmHue((h + 360) % 360)).length;
  final coolCount = hues.where((h) => _isCoolHue((h + 360) % 360)).length;
    final warmProp = warmCount / palette.length;
    final coolProp = coolCount / palette.length;
    if (weights.containsKey('warmBias')) {
      _accumulate('warmBias', warmProp, weights, (s, w) {
        weightedSum += s * w;
        sumWeights += w;
      });
    }
    if (weights.containsKey('coolBias')) {
      _accumulate('coolBias', coolProp, weights, (s, w) {
        weightedSum += s * w;
        sumWeights += w;
      });
    }

    // brandDiversity: unique brandNames / palette size
    final uniqueBrands = palette.map((p) => p.brandName).toSet().length;
    final brandDiversity = uniqueBrands / palette.length;
    _accumulate('brandDiversity', brandDiversity, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // v3: value coverage (light/mid/dark presence) & spread
    final valueCoverage = _valueCoverage(palette);
    _accumulate('valueCoverage', valueCoverage, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });
  final valueSpread = _valueSpread(palette);
    _accumulate('valueSpread', valueSpread, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });
    // v3: spacing bonus encourages ≥20–30 gaps between adjacent levels
    final minGap = _minSpacing(palette);
    double spacingBonus;
    if (minGap >= 20 && minGap <= 30) {
      spacingBonus = 1.0;
    } else if (minGap < 8) {
      spacingBonus = 0.0;
    } else if (minGap > 40) {
      spacingBonus = 0.5; // too far apart; still okay
    } else {
      spacingBonus = ((minGap - 8) / (20 - 8)).clamp(0.0, 1.0);
    }
    _accumulate('spacingBonus', spacingBonus, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // v3: undertone cohesion (w/ neutral bridge) and temperature balance 80/20
    final undertoneCohesion = _undertoneCohesion(palette, spec);
    _accumulate('undertoneCohesion', undertoneCohesion, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });
    final temperatureBalance = _temperatureBalance(palette);
    _accumulate('temperatureBalance', temperatureBalance, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // v2: varietyFitness (soft feature for score shaping)
    double varietyFitness = 1.0;
    if (vc != null) {
      final n = palette.length.toDouble();
      if (n < vc.minColors) {
        final d = (vc.minColors - n).clamp(0.0, vc.minColors.toDouble());
        varietyFitness = (1.0 - d / vc.minColors).clamp(0.0, 1.0);
      } else if (n > vc.maxColors) {
        final d = (n - vc.maxColors).clamp(0.0, n);
        varietyFitness = (1.0 - d / n).clamp(0.0, 1.0);
      }
    }
    _accumulate('varietyFitness', varietyFitness, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // v2: accentHueFit (share of accent hues inside allowed_hue_ranges)
    double accentHueFit = 1.0;
    if (spec.allowedHueRanges.isNotEmpty) {
      final huesAcc = _accentHues(palette, spec);
      if (huesAcc.isNotEmpty) {
        int ok = 0;
        for (final h in huesAcc) {
          bool inside = false;
          for (final band in spec.allowedHueRanges) {
            if (band.length < 2) continue;
            final a = band[0];
            final b = band[1];
            if (a <= b ? (h >= a && h <= b) : (h >= a || h <= b)) {
              inside = true;
              break;
            }
          }
          if (inside) ok++;
        }
        accentHueFit = ok / huesAcc.length;
      }
    }
    _accumulate('accentHueFit', accentHueFit, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // Pop discipline: enforce the "0 or 1 pop accent" rule
    double popDiscipline = 1.0;
    if (vc?.popChromaMin != null) {
      final popChromaMin = vc!.popChromaMin!;
      final pops = _countPops(palette, popChromaMin);
      
      if (pops <= 1) {
        popDiscipline = 1.0;
      } else {
        // Penalize additional pops linearly
        popDiscipline = max(0.0, 1.0 - 0.5 * (pops - 1));
      }
      
      // If muted palette prefers muted pop, penalize overly vivid pops
      if (vc.mutedPalettePrefersMutedPop == true && 
          _isMutedPalette(palette, popChromaMin, 14.0)) {
        final vividPops = palette
            .where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) > 24.0)
            .length;
        if (vividPops > 0) {
          popDiscipline *= 0.7; // penalize vivid pops in muted palettes
        }
      }
    }
    _accumulate('popDiscipline', popDiscipline, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // Dominant vs. Secondary separation: ensure clear difference by hue or value
    final dominantSecondarySeparation = _dominantSecondarySeparation(palette);
    _accumulate('dominantSecondarySeparation', dominantSecondarySeparation, weights, (s, w) {
      weightedSum += s * w;
      sumWeights += w;
    });

    // If no weights provided, return simple average of a core set of features
    if (sumWeights <= 0.0) {
      final fallback = (neutralShare +
              hueAllowed +
              saturationDiscipline +
              harmonyMatch +
              accentContrast +
              warmProp +
              brandDiversity +
              valueCoverage +
              valueSpread +
        spacingBonus +
              undertoneCohesion +
              temperatureBalance +
              popDiscipline +
              dominantSecondarySeparation) /
      14.0;
      return fallback.clamp(0.0, 1.0);
    }

    final score = (weightedSum / sumWeights).clamp(0.0, 1.0);
    return score;
  }

  static String explain(List<Paint> palette, ThemeSpec spec) {
    try {
      final score = scorePalette(palette, spec);
      final vc = spec.varietyControls;
      final accents = _accentHues(palette, spec).length;
      final neutrals = palette.where((p) => _isNeutral(p, spec)).length;
      // Diagnostics
      final vs = _valueSpread(palette).toStringAsFixed(3);
      final uCoh = _undertoneCohesion(palette, spec).toStringAsFixed(3);
      final tb = _temperatureBalance(palette).toStringAsFixed(3);
      final minGap = _minSpacing(palette).toStringAsFixed(1);
      final needBridge = _needsBridge(palette).toString();
      final domSecSep = _dominantSecondarySeparation(palette).toStringAsFixed(3);
      return 'score=${score.toStringAsFixed(3)},n=${palette.length},neutrals=$neutrals,accents=$accents,vc=${vc?.minColors}-${vc?.maxColors}, valueSpread=$vs, undertone=$uCoh, tempBalance=$tb, minGap=$minGap, needBridge=$needBridge, domSecSep=$domSecSep';
    } catch (e) {
      return 'error:${e.toString()}';
    }
  }
}

// Helpers
bool _inRange(Range1? r, double v) {
  if (r == null) return false;
  return v >= r.min && v <= r.max;
}

bool _inHue(RangeH? h, double deg) {
  if (h == null) return false;
  for (final band in h.bands) {
    if (band.length < 2) continue;
    final a = band[0];
    final b = band[1];
    if (a <= b) {
      if (deg >= a && deg <= b) return true;
    } else {
      // wrap-around
      if (deg >= a || deg <= b) return true;
    }
  }
  return false;
}

bool _inRange3(Range3? r3, double L, double C, double hDeg) {
  if (r3 == null) return false;
  final okL = r3.L == null ? true : _inRange(r3.L, L);
  final okC = r3.C == null ? true : _inRange(r3.C, C);
  final okH = r3.H == null ? true : _inHue(r3.H, hDeg);
  return okL && okC && okH;
}

bool _inForbidden(double hue, List<List<double>> forbidden) {
  if (forbidden.isEmpty) return false;
  for (final band in forbidden) {
    if (band.length < 2) continue;
    final a = band[0];
    final b = band[1];
    if (a <= b) {
      if (hue >= a && hue <= b) return true;
    } else {
      if (hue >= a || hue <= b) return true;
    }
  }
  return false;
}

double _hueSpan(List<double> hues) {
  if (hues.isEmpty) return 0.0;
  final sorted = List<double>.from(hues)..sort();
  double maxGap = 0.0;
  for (var i = 1; i < sorted.length; i++) {
    maxGap = max(maxGap, sorted[i] - sorted[i - 1]);
  }
  // include wrap gap
  maxGap = max(maxGap, 360 - (sorted.last - sorted.first));
  return 360 - maxGap; // span covered by hues
}

double _clamp01Range(double v) => v.clamp(0.0, 100.0);

void _accumulate(String key, double featureValue, Map<String, double> weights,
    void Function(double, double) cb) {
  final w = weights[key] ?? 0.0;
  if (w > 0.0) cb(featureValue.clamp(0.0, 1.0), w);
}
