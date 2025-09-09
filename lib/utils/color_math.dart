import 'dart:math';
import 'package:flutter/material.dart';

class ColorMath {
  // --- sRGB <-> linear helpers ---
  static double _srgbToLin(double c) =>
      c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

  // --- RGB (0..1) -> XYZ (D65) ---
  static List<double> _rgbToXyz(Color col) {
    final r = _srgbToLin(col.r);
    final g = _srgbToLin(col.g);
    final b = _srgbToLin(col.b);
    final x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
    final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    final z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;
    return [x, y, z];
  }

  // --- XYZ -> Lab (D65) ---
  static List<double> _xyzToLab(List<double> xyz) {
    // D65 white
    const xn = 0.95047, yn = 1.00000, zn = 1.08883;
    double f(double t) => t > pow(6 / 29, 3)
        ? pow(t, 1 / 3).toDouble()
        : (1 / 3) * pow(29 / 6, 2).toDouble() * t + 4 / 29;
    final fx = f(xyz[0] / xn);
    final fy = f(xyz[1] / yn);
    final fz = f(xyz[2] / zn);
    final L = 116 * fy - 16;
    final a = 500 * (fx - fy);
    final b = 200 * (fy - fz);
    return [L, a, b];
  }

  static List<double> rgbToLab(Color c) => _xyzToLab(_rgbToXyz(c));

  // CIE76 – good enough for a quick delta
  static double deltaE76(Color a, Color b) {
    final la = rgbToLab(a), lb = rgbToLab(b);
    final dL = la[0] - lb[0];
    final da = la[1] - lb[1];
    final db = la[2] - lb[2];
    return sqrt(dL * dL + da * da + db * db);
  }

  // --- Color-blind simulation (Brettel/Vienot-ish matrices) ---
  static const _prot = [
    [0.152286, 1.052583, -0.204868],
    [0.114503, 0.786281, 0.099216],
    [-0.003882, -0.048116, 1.051998],
  ];

  static const _deut = [
    [0.367322, 0.860646, -0.227968],
    [0.280085, 0.672501, 0.047413],
    [-0.011820, 0.042940, 0.968881],
  ];

  static const _trit = [
    [1.255528, -0.076749, -0.178779],
    [-0.078411, 0.930809, 0.147602],
    [0.004733, 0.691367, 0.303900],
  ];

  static Color _applyMatrix(Color c, List<List<double>> m) {
    final r = c.r, g = c.g, b = c.b;
    double clamp01(double v) => v.clamp(0.0, 1.0);
    final nr = clamp01(m[0][0] * r + m[0][1] * g + m[0][2] * b);
    final ng = clamp01(m[1][0] * r + m[1][1] * g + m[1][2] * b);
    final nb = clamp01(m[2][0] * r + m[2][1] * g + m[2][2] * b);
    return Color.fromARGB((c.a * 255.0).round() & 0xff, (nr * 255).round(),
        (ng * 255).round(), (nb * 255).round());
  }

  static Color simulateCB(Color c, String mode) {
    switch (mode) {
      case 'protan':
        return _applyMatrix(c, _prot);
      case 'deuter':
        return _applyMatrix(c, _deut);
      case 'tritan':
        return _applyMatrix(c, _trit);
      default:
        return c;
    }
  }

  // --- Simple lighting tints (quick, visually plausible) ---
  static Color simulateLighting(Color c, String mode) {
    // multipliers tuned for quick preview (not chromatic adaptation)
    late List<double> m;
    switch (mode) {
      case 'incandescent':
        m = [1.10, 0.97, 0.88];
        break; // warm (boost R, reduce B)
      case 'north':
        m = [0.92, 0.98, 1.08];
        break; // cool (boost B a bit)
      default:
        m = [1.0, 1.0, 1.0];
    }
    int comp(double v, double mul) => (v * mul).clamp(0.0, 1.0).toInt();
    return Color.fromARGB(
      (c.a * 255.0).round() & 0xff,
      comp(c.r, m[0]),
      comp(c.g, m[1]),
      comp(c.b, m[2]),
    );
  }
}
