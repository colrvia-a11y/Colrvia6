import 'dart:math';

import 'package:color_canvas/firestore/firestore_data_schema.dart' show Paint;
import 'package:color_canvas/utils/color_utils.dart';
import 'theme_spec.dart';

class ThemeEngine {
  // Prefilter paints by LCH windows in spec.neutrals or spec.accents
  static List<Paint> prefilter(List<Paint> paints, ThemeSpec spec) {
    if (spec.neutrals == null && spec.accents == null) return paints;
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

  // Return slot L (LRV) hints as ranges [min,max] per slot or null
  static List<List<double>>? slotLrvHintsFor(int size, ThemeSpec spec) {
    final rt = spec.roleTargets;
    final anchorL = rt?.anchor?.L;
    if (anchorL == null) return null;
    final secondaryL = rt?.secondary?.L;
    final accentL = rt?.accent?.L;

    final out = <List<double>>[];
    for (var i = 0; i < size; i++) {
      if (i == 0) {
        out.add([_clamp01Range(anchorL.min), _clamp01Range(anchorL.max)]);
      } else if (i == 1) {
        if (secondaryL != null) {
          out.add([_clamp01Range(secondaryL.min), _clamp01Range(secondaryL.max)]);
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

  static double scorePalette(List<Paint> palette, ThemeSpec spec) {
    if (palette.isEmpty) return 0.0;

    final weights = spec.weights;
    double weightedSum = 0.0;
    double sumWeights = 0.0;

    // neutralShare
    final neutralCMax = spec.neutrals?.C?.max ?? 12.0;
    final neutralCount = palette.where((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) <= neutralCMax).length;
    final neutralShare = neutralCount / palette.length;
    _accumulate('neutralShare', neutralShare, weights, (s, w) {
      weightedSum += s * w; sumWeights += w;
    });

    // forbidden hues -> hueAllowed (1.0 if none offending, else 1 - share offending)
    final forbidden = spec.forbiddenHues;
    int offending = 0;
    for (final p in palette) {
      final hue = (p.lch.length > 2 ? p.lch[2] % 360 : 0.0);
      if (_inForbidden(hue, forbidden)) offending++;
    }
    final hueAllowed = offending == 0 ? 1.0 : max(0.0, 1.0 - (offending / palette.length));
    _accumulate('forbiddenHuePenalty', hueAllowed, weights, (s, w) {
      weightedSum += s * w; sumWeights += w;
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
      weightedSum += s * w; sumWeights += w;
    });

    // harmonyMatch
    double harmonyMatch = 0.0;
    if (spec.harmonyBias.contains('analogous')) {
      final hues = palette.map((p) => (p.lch.length > 2 ? p.lch[2] % 360 : 0.0)).toList();
      if (hues.isNotEmpty) {
        final span = _hueSpan(hues);
        if (span <= 60.0) harmonyMatch = 1.0;
      }
    }
    if (spec.harmonyBias.contains('neutral-plus-accent')) {
      final hasNeutral = palette.any((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) <= neutralCMax);
      final hasAccent = palette.any((p) => (p.lch.length > 1 ? p.lch[1] : 0.0) > neutralCMax);
      if (hasNeutral && hasAccent) harmonyMatch = max(harmonyMatch, 1.0);
    }
    _accumulate('harmonyMatch', harmonyMatch, weights, (s, w) {
      weightedSum += s * w; sumWeights += w;
    });

    // accentContrast: contrast between darkest and lightest (by L) pair
    final sortedByL = List<Paint>.from(palette)..sort((a, b) => (a.lch[0]).compareTo(b.lch[0]));
    double accentContrast = 0.0;
    if (sortedByL.length >= 2) {
      final low = ColorUtils.hexToColor(sortedByL.first.hex);
      final high = ColorUtils.hexToColor(sortedByL.last.hex);
      final contrast = contrastRatio(low, high);
      accentContrast = (contrast / 7.0).clamp(0.0, 1.0);
    }
    _accumulate('accentContrast', accentContrast, weights, (s, w) {
      weightedSum += s * w; sumWeights += w;
    });

    // warmBias / coolBias
    final hues = palette.map((p) => (p.lch.length > 2 ? p.lch[2] % 360 : 0.0)).toList();
    final warmCount = hues.where((h) => (h >= 0 && h <= 90) || (h >= 330 && h <= 360)).length;
    final coolCount = hues.where((h) => (h >= 90 && h <= 270)).length;
    final warmProp = warmCount / palette.length;
    final coolProp = coolCount / palette.length;
    if (weights.containsKey('warmBias')) {
      _accumulate('warmBias', warmProp, weights, (s, w) {
        weightedSum += s * w; sumWeights += w;
      });
    }
    if (weights.containsKey('coolBias')) {
      _accumulate('coolBias', coolProp, weights, (s, w) {
        weightedSum += s * w; sumWeights += w;
      });
    }

    // brandDiversity: unique brandNames / palette size
    final uniqueBrands = palette.map((p) => p.brandName).toSet().length;
    final brandDiversity = uniqueBrands / palette.length;
    _accumulate('brandDiversity', brandDiversity, weights, (s, w) {
      weightedSum += s * w; sumWeights += w;
    });

    // If no weights provided, return simple average of some features
    if (sumWeights <= 0.0) {
      final fallback = (neutralShare + hueAllowed + saturationDiscipline + harmonyMatch + accentContrast + warmProp + brandDiversity) / 7.0;
      return fallback.clamp(0.0, 1.0);
    }

    final score = (weightedSum / sumWeights).clamp(0.0, 1.0);
    return score;
  }

  static String explain(List<Paint> palette, ThemeSpec spec) {
    try {
      final score = scorePalette(palette, spec);
      return 'score=${score.toStringAsFixed(3)},n=${palette.length}';
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

bool _inRange3(Range3? r3, double L, double C, double Hdeg) {
  if (r3 == null) return false;
  final okL = r3.L == null ? true : _inRange(r3.L, L);
  final okC = r3.C == null ? true : _inRange(r3.C, C);
  final okH = r3.H == null ? true : _inHue(r3.H, Hdeg);
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

void _accumulate(String key, double featureValue, Map<String, double> weights, void Function(double, double) cb) {
  final w = weights[key] ?? 0.0;
  if (w > 0.0) cb(featureValue.clamp(0.0, 1.0), w);
}
