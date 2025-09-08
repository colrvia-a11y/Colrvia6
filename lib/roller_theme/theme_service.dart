import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'theme_spec.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  final Map<String, ThemeSpec> _byId = {};
  bool _loaded = false;

  Future<void> loadFromAssetIfNeeded() async {
    if (_loaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/themes/themes.json');
      final Map<String, dynamic> doc = json.decode(jsonString) as Map<String, dynamic>;
      final items = (doc['themes'] as List).cast<Map<String, dynamic>>();
      for (final item in items) {
        final spec = ThemeSpec.fromJson(item);
        _byId[spec.id] = spec;
      }
      _loaded = true;
    } catch (e) {
      // silent failure: leave empty
      _loaded = true;
    }
  }

  List<ThemeSpec> all() => _byId.values.toList();
  ThemeSpec? byId(String? id) => id == null ? null : _byId[id];

  /// Returns label pairs for UI chips. First entry is 'all'.
  List<Map<String, String>> themeLabels() {
    final out = <Map<String, String>>[];
    out.add({'id': 'all', 'label': 'All Themes'});
    for (final spec in _byId.values) {
      out.add({'id': spec.id, 'label': spec.label});
    }
    return out;
  }
}
