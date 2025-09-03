// lib/utils/color_spaces.dart
// Hex <-> Lab conversions (D65, sRGB) with clamping.

import 'dart:math' as math;
import 'lab.dart';

int _clampInt(int v, int min, int max) => v < min ? min : (v > max ? max : v);
double _clamp01(double v) => v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);

double _srgbToLinear(double c) {
  if (c <= 0.04045) return c / 12.92;
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _linearToSrgb(double c) {
  if (c <= 0.0031308) return 12.92 * c;
  return 1.055 * math.pow(c, 1.0 / 2.4).toDouble() - 0.055;
}

/// Parse a `#RRGGBB` hex string into R,G,B 0..255.
List<int> _hexToRgb(String hex) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  final r = int.parse(h.substring(0, 2), radix: 16);
  final g = int.parse(h.substring(2, 4), radix: 16);
  final b = int.parse(h.substring(4, 6), radix: 16);
  return [r, g, b];
}

String _rgbToHex(int r, int g, int b) {
  return '#'
      '${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

/// Convert a hex color to Lab (D65).
Lab hexToLab(String hex) {
  final rgb = _hexToRgb(hex);
  final r = _srgbToLinear(rgb[0] / 255.0);
  final g = _srgbToLinear(rgb[1] / 255.0);
  final b = _srgbToLinear(rgb[2] / 255.0);

  // Linear RGB to XYZ (D65)
  final x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375;
  final y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
  final z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041;

  // Normalize by reference white D65
  final xn = x / 0.95047;
  final yn = y / 1.00000;
  final zn = z / 1.08883;

  double f(double t) {
    return t > 0.008856 ? math.pow(t, 1.0 / 3.0).toDouble() : (7.787 * t + 16.0 / 116.0);
  }

  final fx = f(xn);
  final fy = f(yn);
  final fz = f(zn);

  final L = 116.0 * fy - 16.0;
  final a = 500.0 * (fx - fy);
  final b2 = 200.0 * (fy - fz);
  return Lab(L, a, b2);
}

/// Convert Lab (D65) to hex `#RRGGBB`.
String labToHex(Lab lab) {
  final L = lab.l;
  final a = lab.a;
  final b2 = lab.b;

  final fy = (L + 16.0) / 116.0;
  final fx = a / 500.0 + fy;
  final fz = fy - b2 / 200.0;

  double finv(double t) {
    final t3 = t * t * t;
    return t3 > 0.008856 ? t3 : (t - 16.0 / 116.0) / 7.787;
  }

  final xr = finv(fx);
  final yr = finv(fy);
  final zr = finv(fz);

  // Denormalize by reference white D65
  final x = xr * 0.95047;
  final y = yr * 1.00000;
  final z = zr * 1.08883;

  // XYZ to linear RGB
  double rl = 3.2404542 * x + -1.5371385 * y + -0.4985314 * z;
  double gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
  double bl = 0.0556434 * x + -0.2040259 * y + 1.0572252 * z;

  rl = _clamp01(rl);
  gl = _clamp01(gl);
  bl = _clamp01(bl);

  final r = _clampInt((255.0 * _linearToSrgb(rl)).round(), 0, 255);
  final g = _clampInt((255.0 * _linearToSrgb(gl)).round(), 0, 255);
  final b = _clampInt((255.0 * _linearToSrgb(bl)).round(), 0, 255);

  return _rgbToHex(r, g, b);
}

