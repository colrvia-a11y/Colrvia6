import 'dart:math';
import 'package:flutter/material.dart';
import '../firestore/firestore_data_schema.dart' show Paint;
import '../services/analytics_service.dart';
import 'async_compute.dart';

// Core color utility functions
double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color c) {
  final r = _lin(((c.r * 255.0).round() & 0xff) / 255), g = _lin(((c.g * 255.0).round() & 0xff) / 255), b = _lin(((c.b * 255.0).round() & 0xff) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final l1 = luminance(a), l2 = luminance(b);
  final hi = max(l1, l2), lo = min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

Color bestTextOn(Color bg) =>
    contrastRatio(bg, Colors.black) >= 4.5 ? Colors.black : Colors.white;

// Approximate simulations
Color simulateProtanopia(Color c) {
  final r = ((c.r * 255.0).round() & 0xff).toDouble(), g = ((c.g * 255.0).round() & 0xff).toDouble(), b = ((c.b * 255.0).round() & 0xff).toDouble();
  final nr = 0.567 * r + 0.433 * g;
  final ng = 0.558 * r + 0.442 * g;
  final nb = 0.0 * r + 0.242 * g + 0.758 * b;
  return Color.fromARGB(((c.a * 255.0).round() & 0xff), nr.toInt(), ng.toInt(), nb.toInt());
}

Color simulateDeuteranopia(Color c) {
  final r = ((c.r * 255.0).round() & 0xff).toDouble(), g = ((c.g * 255.0).round() & 0xff).toDouble(), b = ((c.b * 255.0).round() & 0xff).toDouble();
  final nr = 0.625 * r + 0.375 * g;
  final ng = 0.7 * r + 0.3 * g;
  final nb = 0.0 * r + 0.3 * g + 0.7 * b;
  return Color.fromARGB(((c.a * 255.0).round() & 0xff), nr.toInt(), ng.toInt(), nb.toInt());
}

// Additional utility class for compatibility with existing code
class ColorUtils {
  // Hex to RGB conversion
  static List<int> hexToRgb(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    final value = int.parse(cleanHex, radix: 16);
    return [
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  // RGB to LAB conversion (simplified)
  static List<double> rgbToLab(int r, int g, int b) {
    // Convert RGB to XYZ
    double rNorm = r / 255.0;
    double gNorm = g / 255.0;
    double bNorm = b / 255.0;

    // Apply gamma correction
    rNorm = (rNorm > 0.04045)
        ? pow((rNorm + 0.055) / 1.055, 2.4).toDouble()
        : rNorm / 12.92;
    gNorm = (gNorm > 0.04045)
        ? pow((gNorm + 0.055) / 1.055, 2.4).toDouble()
        : gNorm / 12.92;
    bNorm = (bNorm > 0.04045)
        ? pow((bNorm + 0.055) / 1.055, 2.4).toDouble()
        : bNorm / 12.92;

    // Convert to XYZ
    double x = rNorm * 0.4124564 + gNorm * 0.3575761 + bNorm * 0.1804375;
    double y = rNorm * 0.2126729 + gNorm * 0.7151522 + bNorm * 0.0721750;
    double z = rNorm * 0.0193339 + gNorm * 0.1191920 + bNorm * 0.9503041;

    // Normalize for D65 illuminant
    x = x / 0.95047;
    y = y / 1.00000;
    z = z / 1.08883;

    // Convert XYZ to LAB
    x = (x > 0.008856) ? pow(x, 1 / 3).toDouble() : (7.787 * x + 16 / 116);
    y = (y > 0.008856) ? pow(y, 1 / 3).toDouble() : (7.787 * y + 16 / 116);
    z = (z > 0.008856) ? pow(z, 1 / 3).toDouble() : (7.787 * z + 16 / 116);

    double l = (116 * y) - 16;
    double a = 500 * (x - y);
    double bLab = 200 * (y - z);

    return [l, a, bLab];
  }

  // Color distance calculation using Delta E
  static double deltaE(List<double> lab1, List<double> lab2) {
    final dl = lab1[0] - lab2[0];
    final da = lab1[1] - lab2[1];
    final db = lab1[2] - lab2[2];
    return sqrt(dl * dl + da * da + db * db);
  }

  // LRV calculation helper
  static double computeLrv(String hex) {
    final rgb = hexToRgb(hex);
    final color = Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
    return luminance(color) * 100; // Convert to percentage
  }

  // Convert hex to Flutter Color
  static Color hexToColor(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }

  // Get paint color (wrapper for hexToColor)
  static Color getPaintColor(String hex) {
    return hexToColor(hex);
  }

  // Delta E 2000 calculation (simplified)
  static double deltaE2000(List<double> lab1, List<double> lab2) {
    // Simplified Delta E calculation - in production use proper Delta E 2000
    return deltaE(lab1, lab2);
  }

  static List<double> lchToLab(double l, double c, double hDeg) {
    final h = hDeg * pi / 180.0;
    final a = c * cos(h);
    final b = c * sin(h);
    return [l, a, b];
  }

  static Paint? nearestToTargetLab(List<double> targetLab, List<Paint> candidates) {
    Paint? best;
    double bestDe = double.infinity;
    for (final p in candidates) {
      final de = deltaE2000(p.lab, targetLab);
      if (de < bestDe) {
        bestDe = de;
        best = p;
      }
    }
    return best;
  }

  // Convert LAB to LCH
  static List<double> labToLch(List<double> lab) {
    final l = lab[0];
    final a = lab[1];
    final b = lab[2];

    final c = sqrt(a * a + b * b);
    final h = atan2(b, a) * 180 / pi;

    return [l, c, h < 0 ? h + 360 : h];
  }

  // Analyze undertone tags from LAB values
  static List<String> undertoneTags(List<double> lab) {
    final List<String> tags = [];

    if (lab.length < 3) return tags;

    // ...existing code...
    final a = lab[1]; // Green-Red axis
    final b = lab[2]; // Blue-Yellow axis

    // Undertone analysis based on a* and b* values
    if (a > 5) {
      tags.add('red undertone');
    } else if (a < -5) {
      tags.add('green undertone');
    }

    if (b > 10) {
      tags.add('yellow undertone');
    } else if (b < -10) {
      tags.add('blue undertone');
    }

    // Additional undertone combinations
    if (a > 2 && b > 2) {
      tags.add('warm');
    } else if (a < -2 && b < -2) {
      tags.add('cool');
    }

    // Neutral undertones
    if (a.abs() < 3 && b.abs() < 3) {
      tags.add('neutral');
    }

    return tags;
  }

  // Missing methods for palette generation and color processing
  static Paint? nearestByDeltaE(List<double> targetLab, List<Paint> paints) {
    if (paints.isEmpty) return null;

    Paint? nearest;
    double minDistance = double.infinity;

    for (final paint in paints) {
      final distance = deltaE(targetLab, paint.lab);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = paint;
      }
    }

    return nearest;
  }

  static Paint? nearestByDeltaEMultipleHueWindow(
      List<double> targetLab, List<Paint> paints,
      {double hueWindow = 30.0}) {
    if (paints.isEmpty) return null;

    final targetLch = labToLch(targetLab);
    final targetHue = targetLch[2];

    // Filter paints within hue window
    final filteredPaints = paints.where((paint) {
      final paintLch = labToLch(paint.lab);
      final hue = paintLch[2];
      final hueDiff = (hue - targetHue).abs();
      return hueDiff <= hueWindow || hueDiff >= (360 - hueWindow);
    }).toList();

    return nearestByDeltaE(targetLab, filteredPaints);
  }

  // Batch utilities using isolate offload when payload is large
  static Future<List<double>> batchComputeLrv(List<String> hexes,
      {int threshold = 25}) async {
    if (hexes.length <= threshold) {
      return _computeLrvList(hexes);
    }
    final sw = Stopwatch()..start();
    final result = await AsyncCompute.run(_computeLrvList, hexes);
    sw.stop();
    AnalyticsService.instance
        .log('perf_isolate_used', {'task': 'batch_lrv', 'ms': sw.elapsedMilliseconds});
    return result;
  }

  static List<double> _computeLrvList(List<String> hexes) =>
      [for (final h in hexes) computeLrv(h)];

  static Future<List<double>> batchContrast(List<Color> a, List<Color> b,
      {int threshold = 25}) async {
    final count = min(a.length, b.length);
    final flat = <int>[];
    for (var i = 0; i < count; i++) {
      flat..add(a[i].toARGB32())..add(b[i].toARGB32());
    }
    if (count <= threshold) {
      return _contrastList(flat);
    }
    final sw = Stopwatch()..start();
    final result = await AsyncCompute.run(_contrastList, flat);
    sw.stop();
    AnalyticsService.instance.log(
        'perf_isolate_used', {'task': 'batch_contrast', 'ms': sw.elapsedMilliseconds});
    return result;
  }

  static List<double> _contrastList(List<int> flat) {
    final out = <double>[];
    for (var i = 0; i < flat.length; i += 2) {
      out.add(contrastRatio(Color(flat[i]), Color(flat[i + 1])));
    }
    return out;
  }

  static Color processColor(Color color) {
    // Simple color processing - adjust brightness or saturation if needed
    return color;
  }

  // Calculate luminance
  static double calculateLuminance(Color color) {
    return luminance(color);
  }

  // Lighten color
  static Color lighten(Color color, double amount) {
    final hslColor = HSLColor.fromColor(color);
    final lightness = (hslColor.lightness + amount).clamp(0.0, 1.0);
    return hslColor.withLightness(lightness).toColor();
  }

  // Darken color
  static Color darken(Color color, double amount) {
    final hslColor = HSLColor.fromColor(color);
    final lightness = (hslColor.lightness - amount).clamp(0.0, 1.0);
    return hslColor.withLightness(lightness).toColor();
  }

  // Get color temperature description
    static String getColorTemperature(Color color) {
      final rgb = [((color.r * 255.0).round() & 0xff), ((color.g * 255.0).round() & 0xff), ((color.b * 255.0).round() & 0xff)];
      final r = rgb[0];
      final g = rgb[1];
      final b = rgb[2];

    // Simple temperature analysis
      if ((r + g) > (b * 1.3)) {
        return 'Warm';
      } else if ((g + b) > (r * 1.3)) {
        return 'Cool';
      } else {
        return 'Neutral';
      }
    }

    /// Placeholder for future image-based undertone inference.
    /// Currently unimplemented and always returns `null`.
    ///
    /// TODO: Implement real undertone analysis from an image.
    /// This would require:
    /// - Image processing to extract dominant colors
    /// - Color analysis algorithms to determine undertones
    /// - Possibly machine learning models for accurate undertone detection
    /// - Integration with image processing libraries (e.g., image package)
    static Future<String?> inferUndertoneFromImage(dynamic image) async {
      // TODO: Implement real undertone analysis from an image.
      return null;
    }
  }

// LRV helper function for paint data
double lrvForPaint({double? paintLrv, required String hex}) {
  if (paintLrv != null) return paintLrv;
  return ColorUtils.computeLrv(hex);
}
