import 'dart:math';
import 'package:color_canvas/models/palette_models.dart';

/// Replace this with your Cloud Function / AI endpoint later.
/// For now we create 2–3 accent variants by nudging lightness while preserving undertone label.
class PaletteSuggestionsService {
  static final PaletteSuggestionsService instance = PaletteSuggestionsService._();
  PaletteSuggestionsService._();

  Future<List<PaintColor>> suggestAccentAlternatives({required Palette base, Map<String, dynamic>? answers}) async {
    final accent = base.roles.accent;
    final List<PaintColor> out = [];
    // Generate light/dark neighbors
    out.add(_nudgeLightness(accent, 0.10));
    out.add(_nudgeLightness(accent, -0.10));
    // If we have mood/lighting, bias an extra option
    final mood = (answers?['moodWords'] as List?)?.cast<String>() ?? const [];
    if (mood.contains('moody')) {
      out.add(_nudgeLightness(accent, -0.18));
    } else {
      out.add(_nudgeLightness(accent, 0.18));
    }
    // Deduplicate by hex
    final seen = <String>{};
    return out.where((c) => seen.add(c.code.toUpperCase())).toList();
  }

  PaintColor _nudgeLightness(PaintColor c, double delta) {
    final hsl = _hexToHsl(c.code);
    final l = (hsl.lightness + delta).clamp(0.05, 0.95);
    final hex = _hslToHex(HSLColor(hue: hsl.hue, saturation: hsl.saturation, lightness: l));
    final lrv = c.lrv == null ? null : (c.lrv! * (1 + delta * 0.6)).clamp(0, 100);
    return PaintColor(name: c.name, code: hex, lrv: lrv?.toDouble(), undertone: c.undertone);
  }

  // --- tiny HSL helpers ---
  HSLColor _hexToHsl(String hex) {
    String h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    final r = int.parse(h.substring(0, 2), radix: 16) / 255.0;
    final g = int.parse(h.substring(2, 4), radix: 16) / 255.0;
    final b = int.parse(h.substring(4, 6), radix: 16) / 255.0;
    final maxc = [r, g, b].reduce(max);
    final minc = [r, g, b].reduce(min);
    final l = (maxc + minc) / 2.0;
    double hDeg, s;
    if (maxc == minc) {
      hDeg = 0;
      s = 0;
    } else {
      final d = maxc - minc;
      s = l > 0.5 ? d / (2 - maxc - minc) : d / (maxc + minc);
      if (maxc == r) {
        hDeg = ((g - b) / d + (g < b ? 6 : 0)) * 60;
      } else if (maxc == g) {
        hDeg = ((b - r) / d + 2) * 60;
      } else {
        hDeg = ((r - g) / d + 4) * 60;
      }
    }
    return HSLColor(hue: hDeg, saturation: s, lightness: l);
  }

  String _hslToHex(HSLColor hsl) {
    final c = (1 - (2 * hsl.lightness - 1).abs()) * hsl.saturation;
    final x = c * (1 - (((hsl.hue / 60) % 2) - 1).abs());
    final m = hsl.lightness - c / 2;
    double r = 0, g = 0, b = 0;
    final h = hsl.hue;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    int ri = ((r + m) * 255).round();
    int gi = ((g + m) * 255).round();
    int bi = ((b + m) * 255).round();
    String hh(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${hh(ri)}${hh(gi)}${hh(bi)}'.toUpperCase();
  }
}

class HSLColor {
  final double hue; // 0..360
  final double saturation; // 0..1
  final double lightness; // 0..1
  HSLColor({required this.hue, required this.saturation, required this.lightness});
}
