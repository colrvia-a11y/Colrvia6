// lib/services/paint_query_service.dart
import 'package:flutter/material.dart';
import '../firestore/firestore_data_schema.dart' show Paint;
import '../services/firebase_service.dart';
import '../data/sample_paints_new.dart';
import '../utils/color_utils.dart';

/// Sorting options for the grid/rails.
enum PaintSort { relevance, hue, lrvAsc, lrvDesc, newest, mostSaved }

class PaintQueryService {
  PaintQueryService._();
  static final instance = PaintQueryService._();

  /// Fetch paints by free-text query (name, brand, code, hex).
  Future<List<Paint>> textSearch(String query, {int limit = 100}) async {
    final list = await FirebaseService.searchPaints(query);
    // Best-effort limit + stable order
    return list.take(limit).toList();
  }

  /// Fetch all paints (may be heavy); try Firestore first; fallback to sample assets.
  Future<List<Paint>> getAllPaints({int? hardLimit}) async {
    try {
      final fs = await FirebaseService.getAllPaints();
      if (fs.isNotEmpty) {
        return hardLimit != null ? fs.take(hardLimit).toList() : fs;
      }
    } catch (_) {
      // ignore and fall back
    }
    // Fallback to bundled sample data when Firestore is empty/unavailable
    final raw = await SamplePaints.searchPaints('');
    return raw
        .map((m) => Paint.fromJson(
              m,
              m['id'] as String? ?? m['code'] as String? ?? 'unknown',
            ))
        .toList();
  }

  /// Compute derived attributes for filtering using existing utilities.
  static _Derived _derive(Paint p) {
    final color = ColorUtils.getPaintColor(p.hex);
    final temp = ColorUtils.getColorTemperature(color); // Warm/Cool/Neutral
    final lrv = p.computedLrv;
    final lab = p.lab;
    final tags = ColorUtils.undertoneTags(lab).map((e) => e.toLowerCase()).toList();
    final hue = HSLColor.fromColor(ColorUtils.getPaintColor(p.hex)).hue; // 0..360
    String family;
    // Coarse family from hue (simplified buckets)
    if (hue >= 0 && hue < 15) { family = 'Red'; }
    else if (hue < 45) { family = 'Orange'; }
    else if (hue < 70) { family = 'Yellow'; }
    else if (hue < 160) { family = 'Green'; }
    else if (hue < 250) { family = 'Blue'; }
    else if (hue < 290) { family = 'Purple'; }
    else { family = 'Red'; }
    // Override to neutrals if saturation is very low
    final hslColor = HSLColor.fromColor(ColorUtils.getPaintColor(p.hex));
    final sat = hslColor.saturation;
    if (sat < 0.08) {
      // neutral lane
      if (lrv > 85) { family = 'White'; }
      else if (lrv < 10) { family = 'Black'; }
      else { family = 'Neutral'; }
    }
    // Undertone family from tags
    String? undertone;
    for (final k in ['green', 'blue', 'violet', 'yellow', 'red']) {
      if (tags.any((t) => t.contains(k))) { undertone = k; break; }
    }
    return _Derived(
      temperature: temp,
      lrv: lrv,
      family: family,
      hue: hue,
      undertone: undertone,
    );
  }

  /// Apply filters client-side (until server-side facets are available).
  List<Paint> applyFilters(
    Iterable<Paint> paints, {
    String? colorFamily,
    String? undertone,
    String? temperature,
    RangeValues? lrvRange,
    String? brandName,
  }) {
    return paints.where((p) {
      final d = _derive(p);
      if (colorFamily != null && d.family.toLowerCase() != colorFamily.toLowerCase()) return false;
      if (undertone != null && (d.undertone ?? '').toLowerCase() != undertone.toLowerCase()) return false;
      if (temperature != null && d.temperature.toLowerCase() != temperature.toLowerCase()) return false;
      if (lrvRange != null) {
        if (d.lrv < lrvRange.start || d.lrv > lrvRange.end) return false;
      }
      if (brandName != null && p.brandName.toLowerCase() != brandName.toLowerCase()) return false;
      return true;
    }).toList();
  }

  /// Sort a list
  List<Paint> applySort(List<Paint> list, PaintSort order) {
    switch (order) {
      case PaintSort.hue:
        list.sort((a, b) => _derive(a).hue.compareTo(_derive(b).hue));
        return list;
      case PaintSort.lrvAsc:
        list.sort((a, b) => _derive(a).lrv.compareTo(_derive(b).lrv));
        return list;
      case PaintSort.lrvDesc:
        list.sort((a, b) => _derive(b).lrv.compareTo(_derive(a).lrv));
        return list;
      case PaintSort.newest:
        // No createdAt on Paint yet; leave as-is
        return list;
      case PaintSort.mostSaved:
        // If popularity exists later, hook here
        return list;
      case PaintSort.relevance:
        return list;
    }
  }

  /// For Explore rails: run a quick filter set and return top N, sorted by a criterion.
  Future<List<Paint>> exploreRail({
    String? title,
    String? colorFamily,
    String? undertone,
    String? temperature,
    RangeValues? lrvRange,
    int limit = 24,
    PaintSort sort = PaintSort.hue,
  }) async {
    final all = await getAllPaints(hardLimit: 1500); // guardrail for perf
    var filtered = applyFilters(all,
      colorFamily: colorFamily,
      undertone: undertone,
      temperature: temperature,
      lrvRange: lrvRange,
    );
    filtered = sortList(filtered, sort).take(limit).toList();
    return filtered;
  }

  List<Paint> sortList(List<Paint> list, PaintSort sort) => applySort(List.from(list), sort);
}

class _Derived {
  final String temperature; // Warm/Cool/Neutral
  final double lrv;
  final String family;
  final double hue;
  final String? undertone;
  _Derived({required this.temperature, required this.lrv, required this.family, required this.hue, required this.undertone});
}