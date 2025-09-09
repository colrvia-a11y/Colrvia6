import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/data/sample_paints.dart';

class PaintRepository {
  List<Paint>? _allCache; // all paints, session cache

  // LRU-ish caches keyed by normalized keys
  final Map<String, List<Paint>> _brandCache = {};
  final Map<String, List<Paint>> _themeCache = {}; // key: themeId|brandKey

  Future<List<Paint>> getAll() async {
    if (_allCache != null) return _allCache!;
    final raw = await SamplePaints.getAllPaints();
    _allCache = raw;
    return _allCache!;
  }

  List<Paint> filterByBrands(List<Paint> paints, Set<String> brandIds) {
    if (brandIds.isEmpty) return paints;
    return paints.where((p) => brandIds.contains(p.brandId)).toList();
  }

  String _brandKey(Set<String> ids) {
    if (ids.isEmpty) return 'ALL';
    final sorted = ids.toList()..sort();
    return sorted.join(',');
  }

  /// Unified access: apply brand filter and optional theme prefilter with caching.
  Future<List<Paint>> getPool({
    required Set<String> brandIds,
    ThemeSpec? theme,
  }) async {
    final all = await getAll();

    // Brand layer
    final bKey = _brandKey(brandIds);
    final branded =
        _brandCache.putIfAbsent(bKey, () => filterByBrands(all, brandIds));

    // Theme layer (optional)
    if (theme == null) return branded;
    final tKey = '${theme.id}|$bKey';
    return _themeCache.putIfAbsent(
        tKey, () => ThemeEngine.prefilter(branded, theme));
  }
}
