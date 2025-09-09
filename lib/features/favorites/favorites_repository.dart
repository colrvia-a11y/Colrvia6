import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritePalette {
  final String key; // stable key for a palette (e.g., paintIds joined)
  final List<String> paintIds;
  final List<String> hexes;
  final DateTime createdAt;

  FavoritePalette({
    required this.key,
    required this.paintIds,
    required this.hexes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'key': key,
        'paintIds': paintIds,
        'hexes': hexes,
        'createdAt': createdAt.toIso8601String(),
      };

  static FavoritePalette fromJson(Map<String, dynamic> m) => FavoritePalette(
        key: m['key'] as String,
        paintIds: List<String>.from(m['paintIds'] as List),
        hexes: List<String>.from(m['hexes'] as List),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class FavoritesRepository {
  static const _storeKey = 'roller_favorites_v1';

  Future<List<FavoritePalette>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = List<Map<String, dynamic>>.from(decoded);
      return [for (final m in list) FavoritePalette.fromJson(m)];
    } catch (_) {
      // Malformed or unexpected data — return empty rather than throwing
      return [];
    }
  }

  Future<void> _saveAll(List<FavoritePalette> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([for (final it in items) it.toJson()]);
    await prefs.setString(_storeKey, raw);
  }

  Future<bool> isFavorite(String key) async {
    final items = await getAll();
    return items.any((it) => it.key == key);
  }

  Future<void> toggle(FavoritePalette item) async {
    final items = await getAll();
    final idx = items.indexWhere((it) => it.key == item.key);
    if (idx >= 0) {
      items.removeAt(idx);
    } else {
      items.insert(0, item);
    }
    await _saveAll(items);
  }
}
