import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import '../firestore/firestore_data_schema.dart';

class SamplePaints {
  static final _logger = Logger('SamplePaints');
  static List<Map<String, dynamic>>? _cachedPaintData;

  /// Load paint data from JSON assets files
  static Future<List<Map<String, dynamic>>> _loadPaintData() async {
    if (_cachedPaintData != null) {
      return _cachedPaintData!;
    }

    try {
      // Load all three brand JSON files
      final sherwinData = await rootBundle
          .loadString('assets/documents/paints_sherwin-williams_mapped.json');
      final benjaminData = await rootBundle
          .loadString('assets/documents/paints_benjamin_moore_mapped.json');
      final behrData =
          await rootBundle.loadString('assets/documents/behr.json');

      // Parse JSON data
      final List<dynamic> sherwinPaints = json.decode(sherwinData);
      final List<dynamic> benjaminPaints = json.decode(benjaminData);
      final List<dynamic> behrPaints = json.decode(behrData);

      // Convert to List<Map<String, dynamic>>
      final List<Map<String, dynamic>> allPaints = [
        ...sherwinPaints.cast<Map<String, dynamic>>(),
        ...benjaminPaints.cast<Map<String, dynamic>>(),
        ...behrPaints.cast<Map<String, dynamic>>(),
      ];

      _cachedPaintData = allPaints;
      return allPaints;
    } catch (e) {
      _logger.severe('Error loading paint data: $e');
      // Return fallback sample data if files can't be loaded
      return _getFallbackPaintData();
    }
  }

  /// Fallback sample paint data in case JSON files can't be loaded
  static List<Map<String, dynamic>> _getFallbackPaintData() {
    return [
      // Sherwin-Williams samples
      {
        'name': 'Oyster White',
        'brandName': 'Sherwin-Williams',
        'code': 'SW 7004',
        'hex': 'E8E3D9',
        'rgb': [232, 227, 217],
        'hsl': [45, 25, 89],
        'lrv': 78.5,
        'computedLrv': 78.5,
        'family': 'Whites',
        'finish': 'Flat',
        'collection': 'Greens',
        'tags': ['white', 'neutral', 'warm'],
        'description': 'A warm white with subtle green undertones',
      },
      {
        'name': 'Alabaster',
        'brandName': 'Sherwin-Williams',
        'code': 'SW 7008',
        'hex': 'EDEAE0',
        'rgb': [237, 234, 224],
        'hsl': [48, 22, 91],
        'lrv': 83.2,
        'computedLrv': 83.2,
        'family': 'Whites',
        'finish': 'Flat',
        'collection': 'Greens',
        'tags': ['white', 'neutral', 'warm'],
        'description': 'A soft, warm white with slight green undertones',
      },
      {
        'name': 'Sea Salt',
        'brandName': 'Sherwin-Williams',
        'code': 'SW 6204',
        'hex': 'D1CFBD',
        'rgb': [209, 207, 189],
        'hsl': [52, 19, 76],
        'lrv': 67.8,
        'computedLrv': 67.8,
        'family': 'Greens',
        'finish': 'Flat',
        'collection': 'Greens',
        'tags': ['green', 'neutral', 'calming'],
        'description': 'A soft green with calming, natural undertones',
      },
      // Benjamin Moore samples
      {
        'name': 'White Dove',
        'brandName': 'Benjamin Moore',
        'code': 'OC-17',
        'hex': 'E6E4DC',
        'rgb': [230, 228, 220],
        'hsl': [48, 18, 88],
        'lrv': 81.4,
        'computedLrv': 81.4,
        'family': 'Whites',
        'finish': 'Flat',
        'collection': 'Classics',
        'tags': ['white', 'neutral', 'timeless'],
        'description': 'A classic white with subtle warmth',
      },
      {
        'name': 'Simply White',
        'brandName': 'Benjamin Moore',
        'code': 'OC-117',
        'hex': 'EFEFE7',
        'rgb': [239, 239, 231],
        'hsl': [60, 20, 93],
        'lrv': 86.1,
        'computedLrv': 86.1,
        'family': 'Whites',
        'finish': 'Flat',
        'collection': 'Classics',
        'tags': ['white', 'neutral', 'clean'],
        'description': 'A clean, crisp white with slight warmth',
      },
      {
        'name': 'Revere Pewter',
        'brandName': 'Benjamin Moore',
        'code': 'HC-172',
        'hex': 'CBC9C0',
        'rgb': [203, 201, 192],
        'hsl': [48, 10, 77],
        'lrv': 65.2,
        'computedLrv': 65.2,
        'family': 'Greys',
        'finish': 'Flat',
        'collection': 'Historical',
        'tags': ['grey', 'neutral', 'sophisticated'],
        'description': 'A sophisticated grey with warm undertones',
      },
      // Behr samples
      {
        'name': 'Ultra Pure White',
        'brandName': 'Behr',
        'code': 'PPU18-01',
        'hex': 'F2F2F2',
        'rgb': [242, 242, 242],
        'hsl': [0, 0, 95],
        'lrv': 88.7,
        'computedLrv': 88.7,
        'family': 'Whites',
        'finish': 'Flat',
        'collection': 'Premium Plus',
        'tags': ['white', 'neutral', 'pure'],
        'description': 'A pure, clean white with excellent coverage',
      },
      {
        'name': 'Classic French Gray',
        'brandName': 'Behr',
        'code': 'MQ5-26',
        'hex': 'C4C0B8',
        'rgb': [196, 192, 184],
        'hsl': [45, 9, 75],
        'lrv': 60.1,
        'computedLrv': 60.1,
        'family': 'Greys',
        'finish': 'Flat',
        'collection': 'Marquee',
        'tags': ['grey', 'neutral', 'classic'],
        'description': 'A classic grey with timeless appeal',
      },
    ];
  }

  /// Get all sample paints
  static Future<List<Paint>> getAllPaints() async {
    final paintData = await _loadPaintData();
    // Ensure each paint has a stable, non-empty id so UI updates animate correctly
    final List<Paint> paints = [];
    for (var i = 0; i < paintData.length; i++) {
      final original = paintData[i];
      String? id = (original['id']?.toString().trim().isEmpty ?? true)
          ? null
          : original['id'].toString();
      if (id == null || id.isEmpty) {
        final brand =
            (original['brandId'] ?? original['brandName'] ?? '').toString();
        final codeOrName =
            (original['code'] ?? original['name'] ?? '').toString();
        final hex = (original['hex'] ?? '').toString();
        final composite = '${brand}_${codeOrName}_${hex}_$i';
        id = composite.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      }
      final mapWithId = {
        ...original,
        'id': id,
      };
      paints.add(Paint.fromJson(mapWithId, id));
    }
    return paints;
  }

  /// Get all unique brands from sample paints
  static Future<List<Brand>> getSampleBrands() async {
    final allPaints = await _loadPaintData();
    final brandNames = allPaints
        .map((paint) => paint['brandName'] as String)
        .toSet()
        .toList()
      ..sort();
    return brandNames
        .map((name) => Brand(
              id: name.toLowerCase().replaceAll(' ', '-'),
              name: name,
              slug: name.toLowerCase().replaceAll(' ', '-'),
            ))
        .toList();
  }

  /// Get paints by brand
  static Future<List<Map<String, dynamic>>> getPaintsByBrand(
      String brand) async {
    final allPaints = await _loadPaintData();
    return allPaints.where((paint) => paint['brandName'] == brand).toList();
  }

  /// Get paints by family
  static Future<List<Map<String, dynamic>>> getPaintsByFamily(
      String family) async {
    final allPaints = await _loadPaintData();
    return allPaints.where((paint) => paint['family'] == family).toList();
  }

  /// Search paints by name or code
  static Future<List<Map<String, dynamic>>> searchPaints(String query) async {
    final allPaints = await _loadPaintData();
    final lowerQuery = query.toLowerCase();
    return allPaints.where((paint) {
      final name = paint['name'].toString().toLowerCase();
      final code = paint['code'].toString().toLowerCase();
      final brand = paint['brandName'].toString().toLowerCase();
      return name.contains(lowerQuery) ||
          code.contains(lowerQuery) ||
          brand.contains(lowerQuery);
    }).toList();
  }

  /// Get paint by ID
  static Future<Map<String, dynamic>?> getPaintById(String id) async {
    final allPaints = await _loadPaintData();
    try {
      return allPaints.firstWhere((paint) => paint['id'] == id);
    } catch (e) {
      return null;
    }
  }
}
