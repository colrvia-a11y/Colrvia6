import 'dart:math';

class ContrastReport {
  final double ratio; // e.g., 4.5
  final String grade; // High / OK / Low
  final String hint; // guidance
  const ContrastReport(
      {required this.ratio, required this.grade, required this.hint});
}

// Parse #RRGGBB → linearized luminance
double _luminanceFromHex(String hex) {
  String h = hex.trim();
  if (!h.startsWith('#')) h = '#$h';
  if (h.length == 4) {
    // #RGB → #RRGGBB
    h = '#'
        '${h[1]}${h[1]}'
        '${h[2]}${h[2]}'
        '${h[3]}${h[3]}';
  }
  int r = int.parse(h.substring(1, 3), radix: 16);
  int g = int.parse(h.substring(3, 5), radix: 16);
  int b = int.parse(h.substring(5, 7), radix: 16);

  double lin(int c) {
    double s = c / 255.0;
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final rl = lin(r), gl = lin(g), bl = lin(b);
  return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl;
}

/// WCAG contrast ratio between two hex colors
double contrastRatio(String hex1, String hex2) {
  final l1 = _luminanceFromHex(hex1);
  final l2 = _luminanceFromHex(hex2);
  final hi = max(l1, l2), lo = min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

ContrastReport assessContrast(String a, String b) {
  final r = double.parse(contrastRatio(a, b).toStringAsFixed(2));
  if (r >= 7.0) {
    return ContrastReport(
        ratio: r,
        grade: 'High',
        hint: 'Crisp separation — great for trim & walls.');
  } else if (r >= 4.5) {
    return ContrastReport(
        ratio: r,
        grade: 'OK',
        hint: 'Comfortable for most walls/trim in natural light.');
  } else if (r >= 3.0) {
    return ContrastReport(
        ratio: r,
        grade: 'Soft',
        hint: 'Soft contrast — works for calm spaces or low-gloss finishes.');
  } else {
    return ContrastReport(
        ratio: r,
        grade: 'Low',
        hint: 'Very low contrast — consider lightening/darkening one color.');
  }
}
