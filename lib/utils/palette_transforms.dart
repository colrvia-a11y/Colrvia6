// lib/utils/palette_transforms.dart
// Deterministic palette transforms for one-tap variants in Roller.
// These operate in CIE Lab space and snap back to the nearest catalog color.

import 'dart:math' as math;
import 'lab.dart';

/// Color identifier used in the app's catalog (e.g., hex, GUID, slug).
typedef ColorId = String;

/// Lookup a Lab value for a color id.
typedef LabLookup = Lab Function(ColorId id);

/// Given a Lab value, return the nearest catalog color id.
typedef NearestId = ColorId? Function(Lab lab);

List<ColorId> softer(
  List<ColorId> ids,
  LabLookup labOf,
  NearestId nearestId,
) {
  return ids.map((id) {
    final lab = labOf(id);
    final nearest = nearestId(
      Lab(
        math.min(100.0, lab.l + 5.0),
        lab.a * 0.9,
        lab.b * 0.9,
      ),
    );
    return nearest ?? id;
  }).toList(growable: false);
}

List<ColorId> brighter(
  List<ColorId> ids,
  LabLookup labOf,
  NearestId nearestId,
) {
  return ids.map((id) {
    final lab = labOf(id);
    final nearest = nearestId(
      Lab(
        math.min(100.0, lab.l + 10.0),
        lab.a,
        lab.b,
      ),
    );
    return nearest ?? id;
  }).toList(growable: false);
}

List<ColorId> moodier(
  List<ColorId> ids,
  LabLookup labOf,
  NearestId nearestId,
) {
  return ids.map((id) {
    final lab = labOf(id);
    final nearest = nearestId(
      Lab(
        math.max(0.0, lab.l - 10.0),
        lab.a,
        lab.b,
      ),
    );
    return nearest ?? id;
  }).toList(growable: false);
}

List<ColorId> warmer(
  List<ColorId> ids,
  LabLookup labOf,
  NearestId nearestId,
) {
  return ids.map((id) {
    final lab = labOf(id);
    final nearest = nearestId(
      Lab(
        lab.l,
        lab.a + 4.0,
        lab.b - 2.0,
      ),
    );
    return nearest ?? id;
  }).toList(growable: false);
}

List<ColorId> cooler(
  List<ColorId> ids,
  LabLookup labOf,
  NearestId nearestId,
) {
  return ids.map((id) {
    final lab = labOf(id);
    final nearest = nearestId(
      Lab(
        lab.l,
        lab.a - 4.0,
        lab.b + 2.0,
      ),
    );
    return nearest ?? id;
  }).toList(growable: false);
}

/// Generate a color-blind-friendly variant by increasing luminance contrast
/// and reducing red/green components.
List<ColorId> cbFriendlyVariant(
  List<ColorId> ids,
  LabLookup labOf,
  NearestId nearestId,
) {
  return ids.map((id) {
    final lab = labOf(id);
    final l = lab.l < 50.0
        ? math.min(100.0, lab.l + 15.0)
        : math.max(0.0, lab.l - 15.0);
    final adjusted = Lab(l, lab.a * 0.5, lab.b);
    final nearest = nearestId(adjusted);
    return nearest ?? id;
  }).toList(growable: false);
}
