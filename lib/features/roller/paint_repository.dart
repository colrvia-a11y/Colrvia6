import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/data/sample_paints.dart';

/// Responsible for loading & caching Paints from assets and applying coarse filters.
class PaintRepository {
  List<Paint>? _cache; // cache all paints in-memory for the session

  Future<List<Paint>> getAll() async {
    if (_cache != null) return _cache!;
    final raw = await SamplePaints.getAllPaints(); // returns List<Paint>
    _cache = raw;
    return _cache!;
  }

  /// Apply brand filter if provided. If brands are empty, returns [paints] unchanged.
  List<Paint> filterByBrands(List<Paint> paints, Set<String> brandIds) {
    if (brandIds.isEmpty) return paints;
    return paints.where((p) => brandIds.contains(p.brandId)).toList();
  }
}
