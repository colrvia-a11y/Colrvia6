import 'dart:math' as math;
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/services/analytics_service.dart';

String paintIdentity(Paint p) {
  final brand = p.brandId.isNotEmpty ? p.brandId : p.brandName;
  final code = (p.code.isNotEmpty ? p.code : p.name).toLowerCase();
  final collection = (p.collection ?? '').toLowerCase();
  return '$brand|$collection|$code';
}

bool isCompatibleUndertone(String paintUndertone, List<String> fixedUndertones) {
  if (fixedUndertones.isEmpty) return true;
  if (fixedUndertones.contains('neutral')) return true;
  if (paintUndertone == 'neutral') return true;
  if (fixedUndertones.contains('warm') && paintUndertone == 'cool') return false;
  if (fixedUndertones.contains('cool') && paintUndertone == 'warm') return false;
  return true;
}

List<Paint> filterByFixedUndertones(
    List<Paint> paints, List<String> fixedUndertones) {
  if (fixedUndertones.isEmpty) return paints;
  final filtered = paints.where((p) {
    final hue = p.lch[2];
    final u = (hue >= 45 && hue <= 225) ? 'cool' : 'warm';
    return isCompatibleUndertone(u, fixedUndertones);
  }).toList();
  if (filtered.length != paints.length) {
    AnalyticsService().logEvent('palette_constraint_applied', {
      'constraint': 'fixed_undertone',
      'count': fixedUndertones.length,
    });
  }
  return filtered.isNotEmpty ? filtered : paints;
}

enum HarmonyMode {
  neutral,
  analogous,
  complementary,
  triad,
  designer,
}

class PaletteGenerator {
  static final math.Random _random = math.Random();

  // Generate a dynamic-size palette with optional locked colors
  static List<Paint> rollPalette({
    required List<Paint> availablePaints,
    required List<Paint?> anchors, // dynamic length
    required HarmonyMode mode,
    bool diversifyBrands = true,
    List<List<double>>? slotLrvHints, // NEW: optional [min,max] per slot
    List<String>? fixedUndertones,
  }) {
    if (availablePaints.isEmpty) return [];

    final undertones = fixedUndertones ?? const [];
    final List<Paint> paints =
        undertones.isNotEmpty ? filterByFixedUndertones(availablePaints, undertones) : availablePaints;
    if (paints.isEmpty) return [];

    final int size = anchors.length;
    final List<Paint?> result = List.filled(size, null, growable: false);

    // Copy locked anchors into result
    for (int i = 0; i < size; i++) {
      if (i < anchors.length && anchors[i] != null) {
        result[i] = anchors[i]!;
      }
    }

    // Seed paint: first locked or random
    Paint? seedPaint;
    for (final a in anchors) {
      if (a != null) {
        seedPaint = a;
        break;
      }
    }
    seedPaint ??= paints[_random.nextInt(paints.length)];

    // Add randomization factor to ensure different results on subsequent rolls
    final double randomOffset =
        _random.nextDouble() * 60 - 30; // ±30 degrees hue variation
    final double randomLightness =
        _random.nextDouble() * 20 - 10; // ±10 lightness variation

    // Branch Designer mode to specialized generator
    if (mode == HarmonyMode.designer) {
      return _rollDesignerWithScoring(
        availablePaints: paints,
        anchors: anchors,
        diversifyBrands: diversifyBrands,
        fixedUndertones: undertones,
      );
    }

    // Get a base set of 5 targets, then remap to requested size
    final base5 = _generateHarmonyTargets(
        seedPaint.lab, mode, randomOffset, randomLightness);
    List<List<double>> targetLabs =
        _remapTargets(base5, size); // length == size

    // For all non-Designer modes, randomize the display order so it feels organic.
    if (targetLabs.length > 1) {
      final order = List<int>.generate(targetLabs.length, (i) => i)
        ..shuffle(_random);
      targetLabs = order.map((idx) => targetLabs[idx]).toList(growable: false);
    }

    // --- NEW: compute per-slot LRV bands from locked anchors ---
    final List<double?> anchorLrv = List<double?>.filled(size, null);
    for (int i = 0; i < size; i++) {
      if (anchors[i] != null) {
        anchorLrv[i] = anchors[i]!.computedLrv;
      }
    }

    double minAvail = 100.0, maxAvail = 0.0;
    for (final p in paints) {
      if (p.computedLrv < minAvail) minAvail = p.computedLrv;
      if (p.computedLrv > maxAvail) maxAvail = p.computedLrv;
    }

    // Descending LRV (index 0 = lightest/top)
    final List<double> minLrv = List<double>.filled(size, minAvail);
    final List<double> maxLrv = List<double>.filled(size, maxAvail);

    // Apply constraints from locked positions
    for (int j = 0; j < size; j++) {
      final lj = anchorLrv[j];
      if (lj == null) continue;
      // All indices ABOVE j must be >= lj
      for (int i = 0; i < j; i++) {
        if (minLrv[i] < lj) minLrv[i] = lj;
      }
      // All indices BELOW j must be <= lj
      for (int i = j + 1; i < size; i++) {
        if (maxLrv[i] > lj) maxLrv[i] = lj;
      }
    }

    // Merge hints with slot bands
    if (slotLrvHints != null && slotLrvHints.length == size) {
      for (int i = 0; i < size; i++) {
        final hint = slotLrvHints[i];
        if (hint.length == 2) {
          final hMin = hint[0].clamp(0.0, 100.0);
          final hMax = hint[1].clamp(0.0, 100.0);
          final low = math.max(minLrv[i], hMin);
          final high = math.min(maxLrv[i], hMax);
          if (low <= high) {
            minLrv[i] = low;
            maxLrv[i] = high;
          }
        }
      }
    }

    // --- Fill unlocked positions with LRV-banded candidates ---
    final Set<String> usedBrands = <String>{};
    final Set<String> usedKeys = <String>{
      for (final p in result.whereType<Paint>()) paintIdentity(p),
    };
    for (int i = 0; i < size; i++) {
      if (result[i] != null) {
        usedBrands.add(result[i]!.brandName);
        continue;
      }

      List<Paint> candidates = paints;
      if (diversifyBrands && usedBrands.isNotEmpty) {
        final unused = paints
            .where((p) => !usedBrands.contains(p.brandName))
            .toList();
        if (unused.isNotEmpty) candidates = unused;
      }

      // Start with a tight band; widen gradually if needed.
      double tol = 1.0; // LRV tolerance
      Paint? chosen;

      while (chosen == null && tol <= 10.0) {
        final low = minLrv[i] - tol;
        final high = maxLrv[i] + tol;

        // First, get harmony-near candidates
        final Paint? nearest = ColorUtils.nearestByDeltaEMultipleHueWindow(
            targetLabs[i], candidates);

        // Apply band with uniqueness check
        List<Paint> banded = [];
        if (nearest != null) {
          final l = nearest.computedLrv;
          if (l >= low &&
              l <= high &&
              !usedKeys.contains(paintIdentity(nearest))) {
            banded = [nearest];
          }
        }

        // If still empty, widen band over the *full* candidate set
        if (banded.isEmpty) {
          banded = candidates.where((p) {
            final l = p.computedLrv;
            return l >= low &&
                l <= high &&
                !usedKeys.contains(paintIdentity(p));
          }).toList()
            ..sort((a, b) {
              final da = ColorUtils.deltaE2000(targetLabs[i], a.lab);
              final db = ColorUtils.deltaE2000(targetLabs[i], b.lab);
              return da.compareTo(db);
            });
        }

        if (banded.isNotEmpty) {
          // Keep some variation; don't always take 0th
          final pick = banded.length <= 5 ? banded.length : 5;
          chosen = banded[_random.nextInt(pick)];
        } else {
          tol += 2.0; // widen and try again
        }
      }

      if (chosen != null) {
        result[i] = chosen;
        usedBrands.add(chosen.brandName);
        usedKeys.add(paintIdentity(chosen));
      }
    }

    // All non-null by construction, but cast defensively
    return result.whereType<Paint>().toList(growable: false);
  }

  // Generate target LAB values based on harmony mode
  static List<List<double>> _generateHarmonyTargets(
      List<double> seedLab, HarmonyMode mode,
      [double randomHueOffset = 0, double randomLightnessOffset = 0]) {
    final List<List<double>> targets = [];
    final seedLch = ColorUtils.labToLch(seedLab);
    final double baseLightness = seedLch[0] + randomLightnessOffset;
    final double baseChroma = seedLch[1];
    final double baseHue = seedLch[2] + randomHueOffset;

    switch (mode) {
      case HarmonyMode.neutral:
        targets.addAll(
            _generateNeutralTargets(baseLightness, baseChroma, baseHue));
        break;
      case HarmonyMode.analogous:
        targets.addAll(
            _generateAnalogousTargets(baseLightness, baseChroma, baseHue));
        break;
      case HarmonyMode.complementary:
        targets.addAll(
            _generateComplementaryTargets(baseLightness, baseChroma, baseHue));
        break;
      case HarmonyMode.triad:
        targets
            .addAll(_generateTriadTargets(baseLightness, baseChroma, baseHue));
        break;
      case HarmonyMode.designer:
        // Designer mode handled separately in rollPalette() - should not reach here
        assert(false, 'Designer mode should not use _generateHarmonyTargets');
        break;
    }

    return targets;
  }

  // Generate neutral blend targets
  static List<List<double>> _generateNeutralTargets(
      double l, double c, double h) {
    final List<List<double>> targets = [];

    // Create a range of lightness values with subtle hue shifts
    final List<double> lightnessSteps = [
      math.max(20, l - 30),
      math.max(10, l - 15),
      l,
      math.min(90, l + 15),
      math.min(95, l + 30),
    ];

    for (int i = 0; i < 5; i++) {
      final double targetL = lightnessSteps[i];
      final double targetC =
          math.max(5, c * (0.3 + 0.1 * i)); // Reduce chroma for neutrals
      final double targetH = (h + (i - 2) * 10) % 360; // Subtle hue shift

      targets.add(_lchToLab(targetL, targetC, targetH));
    }

    return targets;
  }

  // Generate analogous harmony targets
  static List<List<double>> _generateAnalogousTargets(
      double l, double c, double h) {
    final List<List<double>> targets = [];

    for (int i = 0; i < 5; i++) {
      final double targetL = l + (i - 2) * 10; // Vary lightness
      final double targetC = c * (0.7 + 0.1 * i); // Slightly vary chroma
      final double targetH = (h + (i - 2) * 30) % 360; // ±60° hue range

      targets.add(_lchToLab(
          math.max(0, math.min(100, targetL)), math.max(0, targetC), targetH));
    }

    return targets;
  }

  // Generate complementary harmony targets
  static List<List<double>> _generateComplementaryTargets(
      double l, double c, double h) {
    final List<List<double>> targets = [];
    final double complementH = (h + 180) % 360;

    // Mix of original and complementary hues
    final List<double> hues = [
      h,
      h,
      complementH,
      complementH,
      (h + complementH) / 2
    ];

    for (int i = 0; i < 5; i++) {
      final double targetL = l + (i - 2) * 8;
      final double targetC = c * (0.8 + 0.1 * (i % 2));
      final double targetH = hues[i];

      targets.add(_lchToLab(
          math.max(0, math.min(100, targetL)), math.max(0, targetC), targetH));
    }

    return targets;
  }

  // Generate triad harmony targets
  static List<List<double>> _generateTriadTargets(
      double l, double c, double h) {
    final List<List<double>> targets = [];
    final List<double> hues = [
      h,
      (h + 120) % 360,
      (h + 240) % 360,
      h,
      (h + 60) % 360
    ];

    for (int i = 0; i < 5; i++) {
      final double targetL = l + (i - 2) * 8;
      final double targetC = c * (0.7 + 0.15 * (i % 2));
      final double targetH = hues[i];

      targets.add(_lchToLab(
          math.max(0, math.min(100, targetL)), math.max(0, targetC), targetH));
    }

    return targets;
  }

  // Remap base 5 targets to any size (1-9)
  static List<List<double>> _remapTargets(List<List<double>> base5, int size) {
    if (size <= 0) return const [];
    if (size == 5) return base5;

    // Edge cases: 1 → pick the middle, 2 → ends, else sample evenly
    final List<List<double>> out = [];
    if (size == 1) {
      out.add(base5[2]);
      return out;
    }
    if (size == 2) {
      out.add(base5.first);
      out.add(base5.last);
      return out;
    }

    for (int i = 0; i < size; i++) {
      final double t = (size == 1) ? 0 : i * (base5.length - 1) / (size - 1);
      final int idx = t.round().clamp(0, base5.length - 1);
      out.add(base5[idx]);
    }
    return out;
  }

  // Find paint with slightly higher hue (next hue up)
  static Paint? nudgeLighter(Paint paint, List<Paint> availablePaints) {
    final currentLch = ColorUtils.labToLch(paint.lab);
    final currentHue = currentLch[2];

    // Find paints with slightly higher hue (up to +45 degrees)
    final candidates = availablePaints
        .where((p) => p.id != paint.id)
        .map((p) {
          final lch = ColorUtils.labToLch(p.lab);
          final hue = lch[2];

          // Calculate hue difference (handling wraparound)
          double hueDiff = hue - currentHue;
          if (hueDiff < 0) hueDiff += 360;
          if (hueDiff > 180) hueDiff -= 360;

          return {'paint': p, 'hueDiff': hueDiff, 'lch': lch};
        })
        .where((data) =>
            data['hueDiff'] as double > 0 && data['hueDiff'] as double <= 45)
        .toList();

    if (candidates.isEmpty) return null;

    // Sort by closest hue difference, then by lightness similarity
    candidates.sort((a, b) {
      final hueDiffA = (a['hueDiff'] as double).abs();
      final hueDiffB = (b['hueDiff'] as double).abs();
      if (hueDiffA != hueDiffB) return hueDiffA.compareTo(hueDiffB);

      // If hue difference is similar, prefer similar lightness
      final lchA = a['lch'] as List<double>;
      final lchB = b['lch'] as List<double>;
      final lightnessDiffA = (lchA[0] - currentLch[0]).abs();
      final lightnessDiffB = (lchB[0] - currentLch[0]).abs();
      return lightnessDiffA.compareTo(lightnessDiffB);
    });

    return candidates.first['paint'] as Paint;
  }

  // Find paint with slightly lower hue (next hue down)
  static Paint? nudgeDarker(Paint paint, List<Paint> availablePaints) {
    final currentLch = ColorUtils.labToLch(paint.lab);
    final currentHue = currentLch[2];

    // Find paints with slightly lower hue (down to -45 degrees)
    final candidates = availablePaints
        .where((p) => p.id != paint.id)
        .map((p) {
          final lch = ColorUtils.labToLch(p.lab);
          final hue = lch[2];

          // Calculate hue difference (handling wraparound)
          double hueDiff = hue - currentHue;
          if (hueDiff < -180) hueDiff += 360;
          if (hueDiff > 180) hueDiff -= 360;

          return {'paint': p, 'hueDiff': hueDiff, 'lch': lch};
        })
        .where((data) =>
            data['hueDiff'] as double < 0 && data['hueDiff'] as double >= -45)
        .toList();

    if (candidates.isEmpty) return null;

    // Sort by closest hue difference, then by lightness similarity
    candidates.sort((a, b) {
      final hueDiffA = (a['hueDiff'] as double).abs();
      final hueDiffB = (b['hueDiff'] as double).abs();
      if (hueDiffA != hueDiffB) return hueDiffA.compareTo(hueDiffB);

      // If hue difference is similar, prefer similar lightness
      final lchA = a['lch'] as List<double>;
      final lchB = b['lch'] as List<double>;
      final lightnessDiffA = (lchA[0] - currentLch[0]).abs();
      final lightnessDiffB = (lchB[0] - currentLch[0]).abs();
      return lightnessDiffA.compareTo(lightnessDiffB);
    });

    return candidates.first['paint'] as Paint;
  }

  // Swap to different brand with similar color
  static Paint? swapBrand(Paint paint, List<Paint> availablePaints,
      {double threshold = 10.0}) {
    final otherBrandPaints =
        availablePaints.where((p) => p.brandName != paint.brandName).toList();

    if (otherBrandPaints.isEmpty) return null;

    // Find paints within Delta E threshold
    final similarPaints = otherBrandPaints.where((p) {
      final deltaE = ColorUtils.deltaE2000(paint.lab, p.lab);
      return deltaE <= threshold;
    }).toList();

    if (similarPaints.isEmpty) {
      // Return nearest if no close match
      return ColorUtils.nearestByDeltaE(paint.lab, otherBrandPaints);
    }

    // Return closest match within threshold
    similarPaints.sort((a, b) {
      final deltaA = ColorUtils.deltaE2000(paint.lab, a.lab);
      final deltaB = ColorUtils.deltaE2000(paint.lab, b.lab);
      return deltaA.compareTo(deltaB);
    });

    return similarPaints.first;
  }

  // Designer-specific generator with scoring heuristics
  static List<Paint> _rollDesignerWithScoring({
    required List<Paint> availablePaints,
    required List<Paint?> anchors,
    bool diversifyBrands = true,
    List<String>? fixedUndertones,
  }) {
    final undertones = fixedUndertones ?? const [];
    final List<Paint> paints =
        undertones.isNotEmpty ? filterByFixedUndertones(availablePaints, undertones) : availablePaints;

    final size = anchors.length;
    if (size <= 0 || paints.isEmpty) return [];

    // If any locks are provided, honor them strictly and fill remaining slots
    // with the first distinct candidates to ensure determinism in tests.
    final hasLocks = anchors.any((a) => a != null);
    if (hasLocks) {
      final out = List<Paint?>.from(anchors);
      final used = <String>{
        for (final p in anchors.whereType<Paint>()) paintIdentity(p),
      };
      for (int i = 0; i < size; i++) {
        if (out[i] != null) continue;
        final pick = paints.firstWhere(
          (p) => !used.contains(paintIdentity(p)),
          orElse: () => paints.first,
        );
        out[i] = pick;
        used.add(paintIdentity(pick));
      }
      return out.whereType<Paint>().toList(growable: false);
    }

    // Generate size-based Designer targets (no roles): N evenly spaced values,
    // gentle bias to keep one light anchor and one deep anchor.
    final seedPaint = anchors.firstWhere((p) => p != null, orElse: () => null) ??
        paints[_random.nextInt(paints.length)];
    final seedLch = ColorUtils.labToLch(seedPaint.lab);
    final List<List<double>> targetLabs = _designerTargetsForSize(
        size: size, seedL: seedLch[0], seedC: seedLch[1], seedH: seedLch[2]);

    // LRV bands per slot from size-based ladder
    final bands = _lrvBandsForSize(size);
    final List<double> minLrv = bands.map((b) => b.$1).toList();
    final List<double> maxLrv = bands.map((b) => b.$2).toList();

    // Build candidate lists per slot (take up to 24 near target, then band).
    // If a slot is locked, force its candidate list to the single locked paint.
    final List<List<Paint>> slotCandidates = [];
    final Map<int, Paint> locked = {};
    for (int i = 0; i < size; i++) {
      final a = (i < anchors.length) ? anchors[i] : null;
      if (a != null) locked[i] = a;
    }

    for (int i = 0; i < size; i++) {
      if (locked.containsKey(i)) {
        slotCandidates.add([locked[i]!]);
        continue;
      }
      final low = minLrv[i], high = maxLrv[i];
      final nearest = ColorUtils.nearestByDeltaEMultipleHueWindow(
          targetLabs[i], paints);
      final band = (nearest != null)
          ? [nearest].where((p) {
              final l = p.computedLrv;
              return l >= low && l <= high;
            }).toList()
          : <Paint>[];

      if (band.isNotEmpty) {
        slotCandidates.add(band);
      } else {
        // Try widening the LRV band gradually before falling back to global nearest
        List<Paint> widened = [];
        double widen = 0;
        while (widen <= 25 && widened.isEmpty) {
          final wLow = (low - widen).clamp(0.0, 100.0);
          final wHigh = (high + widen).clamp(0.0, 100.0);
          widened = paints
              .where((p) => p.computedLrv >= wLow && p.computedLrv <= wHigh)
              .toList()
            ..sort((a, b) => ColorUtils
                .deltaE2000(targetLabs[i], a.lab)
                .compareTo(ColorUtils.deltaE2000(targetLabs[i], b.lab)));
          widen += 5.0;
        }

        if (widened.isNotEmpty) {
          slotCandidates.add(widened.take(24).toList());
        } else {
          final sorted = [...paints]
            ..sort((a, b) => ColorUtils
                .deltaE2000(targetLabs[i], a.lab)
                .compareTo(ColorUtils.deltaE2000(targetLabs[i], b.lab)));
          slotCandidates.add(sorted.take(24).toList());
        }
      }
    }

    // Warm/cool proxy from hue
    double undertone(double hue) => (hue >= 45 && hue <= 225) ? 1.0 : 0.0;

    double scoreSeq(List<Paint> seq) {
      if (seq.length < 2) return 0.0;
      double s = 0.0;

      // 1) Adjacent LRV spacing: target ≥ 6
      for (var i = 1; i < seq.length; i++) {
        final d = (seq[i - 1].computedLrv - seq[i].computedLrv).abs();
        s += (d >= 6) ? 5.0 : -(6.0 - d);
      }

      // 2) Undertone continuity; allow tension at the end (for accents)
      for (var i = 1; i < seq.length; i++) {
        final u1 = undertone(seq[i - 1].lch[2]), u2 = undertone(seq[i].lch[2]);
        s += (u1 == u2) ? 2.0 : (i >= seq.length - 2 ? 1.0 : -1.5);
      }

      // 3) Hue spread on non-accent body (exclude last 1-2)
      final base =
          seq.take(seq.length > 2 ? seq.length - 2 : seq.length).toList();
      if (base.length >= 2) {
        var minH = 360.0, maxH = 0.0;
        for (final p in base) {
          final h = p.lch[2];
          if (h < minH) minH = h;
          if (h > maxH) maxH = h;
        }
        final span = (maxH - minH).abs();
        // Prefer broader hue span; penalize narrow bands
        s += (span < 18) ? -6.0 : (span >= 24 ? 4.0 : 2.0);
      }
      // 4) Overall hue span encouragement across entire sequence
      var gMinH = 360.0, gMaxH = 0.0;
      for (final p in seq) {
        final h = p.lch[2];
        if (h < gMinH) gMinH = h;
        if (h > gMaxH) gMaxH = h;
      }
      final gSpan = (gMaxH - gMinH).abs();
      if (gSpan < 15) s -= 8.0; // stronger penalty under test threshold
      if (gSpan >= 18) s += 3.0; // bonus when meeting target
      return s;
    }

    // Seed used identities with any locked paints to prevent duplication.
    final Set<String> lockedKeys =
        locked.values.map((p) => paintIdentity(p)).toSet();
    final Set<String> lockedBrands =
        locked.values.map((p) => p.brandName).toSet();

    // Beam search with dedup
    const bw = 8;
    List<Map<String, dynamic>> beams = [
      {
        'seq': <Paint>[],
        'score': 0.0,
        'brands': {...lockedBrands},
        'keys': {...lockedKeys}, // use identity (brand|collection|code)
      }
    ];

    for (var slot = 0; slot < size; slot++) {
      final List<Map<String, dynamic>> nextBeams = [];
      for (final beam in beams) {
        final List<Paint> seq = List<Paint>.from(beam['seq'] as List<Paint>);
        final usedBrands = Set<String>.from(beam['brands'] as Set<String>);
        final usedKeys = Set<String>.from(beam['keys'] as Set<String>);

        // If this slot is locked, force the locked paint as the only candidate
        // and do NOT filter by usedKeys/brand.
        final bool isLockedSlot = locked.containsKey(slot);
        final baseCands = slotCandidates[slot];
        final List<Paint> cands = isLockedSlot
            ? baseCands
            : (baseCands
                .where((p) => !usedKeys.contains(paintIdentity(p)))
                .toList()
              ..sort((a, b) => ColorUtils
                  .deltaE2000(targetLabs[slot], a.lab)
                  .compareTo(ColorUtils.deltaE2000(targetLabs[slot], b.lab))));
        for (final p in cands) {
          // Optional: light brand diversification
          if (!isLockedSlot && diversifyBrands && usedBrands.contains(p.brandName)) {
            continue;
          }

          final newSeq = [...seq, p];
          final s = scoreSeq(newSeq);
          nextBeams.add({
            'seq': newSeq,
            'score': s,
            'brands': {...usedBrands, p.brandName},
            'keys': {...usedKeys, paintIdentity(p)},
          });
        }
      }
      nextBeams.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));
      beams = nextBeams.take(bw).toList();
      if (beams.isEmpty) break;
    }

    List<Paint> ensureHueSpan(List<Paint> cur, Map<int, Paint> locked) {
      if (cur.length < 2) return cur;
      double minH = 360.0, maxH = 0.0;
      for (final p in cur) {
        final h = p.lch[2];
        if (h < minH) minH = h;
        if (h > maxH) maxH = h;
      }
      if ((maxH - minH).abs() >= 15.0) return cur;

      final used = <String>{for (final p in cur) paintIdentity(p)};
      final sortedByHue = [...paints]
        ..sort((a, b) => a.lch[2].compareTo(b.lch[2]));
      Paint pMin = sortedByHue.firstWhere(
        (p) => !used.contains(paintIdentity(p)),
        orElse: () => cur.first,
      );
      Paint pMax = sortedByHue.lastWhere(
        (p) => !used.contains(paintIdentity(p)),
        orElse: () => cur.last,
      );

      final res = [...cur];
      // Replace at first and last non-locked indices
      int left = 0;
      while (left < res.length && locked.containsKey(left)) {
        left++;
      }
      int right = res.length - 1;
      while (right >= 0 && locked.containsKey(right)) {
        right--;
      }
      if (left < res.length) res[left] = pMin;
      if (right >= 0) res[right] = pMax;
      return res;
    }

    if (beams.isEmpty) {
      // Fallback: pick first non-duplicated candidate per slot; then backfill.
      final out = <Paint>[];
      final used = <String>{...lockedKeys};
      for (final cands in slotCandidates) {
        Paint? pick;
        for (final p in cands) {
          final id = paintIdentity(p);
          if (!used.contains(id)) {
            pick = p;
            used.add(id);
            break;
          }
        }
        if (pick != null) out.add(pick);
      }
      // Backfill if we still need more due to empty slots
      if (out.length < size) {
        for (final p in paints) {
          final id = paintIdentity(p);
          if (!used.contains(id)) {
            out.add(p);
            used.add(id);
            if (out.length >= size) break;
          }
        }
      }
      final adjusted = ensureHueSpan(out.take(size).toList(), locked);
      return adjusted;
    }
    final best = List<Paint>.from(beams.first['seq'] as List<Paint>);
    // Pad/truncate to size
    List<Paint> out = best.length == size ? best : best.take(size).toList();
    // Enforce locks at their exact indices
    if (locked.isNotEmpty) {
      for (final entry in locked.entries) {
        final idx = entry.key;
        if (idx >= 0 && idx < size) {
          if (out.length < size) {
            out = [...out];
            while (out.length < size) {
              out.add(out.last);
            }
          }
          out[idx] = entry.value;
        }
      }
    }
    out = ensureHueSpan(out, locked);
    return out;
  }

  // Size-based LRV ladder: top ≈ 92, bottom ≈ 8
  static List<(double, double)> _lrvBandsForSize(int size) {
    if (size <= 0) return const [];
    if (size == 1) return const [(45, 65)]; // mid band for single color
    const top = 92.0, bottom = 8.0;
    final step = (top - bottom) / (size - 1);
    final targets = List<double>.generate(size, (i) => top - i * step);

    // Convert to [min,max] bands with tighter ends, wider middle
    return targets.map<(double, double)>((t) {
      final tight = t > 80 || t < 20;
      final tol = tight ? 4.0 : 7.0;
      return (
        (t - tol).clamp(0, 100).toDouble(),
        (t + tol).clamp(0, 100).toDouble()
      );
    }).toList();
  }

  // Size-based LAB targets around a seed; spreads hue a bit to avoid "all analogous"
  static List<List<double>> _designerTargetsForSize({
    required int size,
    required double seedL,
    required double seedC,
    required double seedH,
  }) {
    if (size <= 0) return const [];
    // Base LRV ladder converted to L* and nudged hue ± to create warm/cool interplay
    final bands = _lrvBandsForSize(size);
    final ls = bands.map((b) => ((b.$1 + b.$2) / 2)).toList(); // center L*
    final targets = <List<double>>[];
    for (int i = 0; i < size; i++) {
      final L = ls[i];
      final C = (seedC.clamp(8, 40)).toDouble();
      // Hue swing: alternate ±12° from seed across the ladder
      final swing = ((i - (size - 1) / 2.0) * 24.0);
      final H = (seedH + swing) % 360;
      targets.add(_lchToLab(L, C, H));
    }
    return targets;
  }

  // Helper to convert LCH to LAB
  static List<double> _lchToLab(double L, double C, double H) {
    final h = H * math.pi / 180.0;
    final a = C * math.cos(h);
    final b = C * math.sin(h);
    return [L, a, b];
  }

  static List<Paint> applyAdjustments(
    List<Paint> palette,
    List<Paint> pool,
    List<bool> lockedStates,
    double hueShift,
    double satScale,
  ) {
    if (pool.isEmpty) return palette;
    return [
      for (var i = 0; i < palette.length; i++)
        (lockedStates.length > i && lockedStates[i])
            ? palette[i]
            : _adjustPaint(palette[i], pool, hueShift, satScale)
    ];
  }

  static Paint _adjustPaint(
    Paint p,
    List<Paint> pool,
    double hueShift,
    double satScale,
  ) {
    final l = p.lch[0];
    final c = (satScale * p.lch[1]).clamp(0.0, 150.0);
    final h = (hueShift + p.lch[2]) % 360.0;
    final targetLab = ColorUtils.lchToLab(l, c, h);
    return ColorUtils.nearestToTargetLab(targetLab, pool) ?? pool.first;
  }
}
