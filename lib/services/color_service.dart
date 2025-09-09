import 'package:flutter/material.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/color_utils.dart';

class ColorService {
  ColorService._();
  static final Map<String, Color> _cache = {};

  static Future<Color> getColorFromId(String paintId) async {
    final cached = _cache[paintId];
    if (cached != null) return cached;
    final paint = await FirebaseService.getPaintById(paintId);
    final color = ColorUtils.getPaintColor(paint?.hex ?? '#000000');
    _cache[paintId] = color;
    return color;
  }
}
