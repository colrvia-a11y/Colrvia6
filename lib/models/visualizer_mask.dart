// lib/models/visualizer_mask.dart
import 'dart:ui';

/// Represents a user-defined mask for the visualizer.
class VisualizerMask {
  final String id;
  final String surface; // walls, trim, ceiling, doors, cabinets
  final List<List<Offset>> polygons;
  final DateTime createdAt;
  final DateTime updatedAt;

  VisualizerMask({
    required this.id,
    required this.surface,
    required this.polygons,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VisualizerMask.fromJson(Map<String, dynamic> j) {
    final polys = (j['polygons'] as List? ?? [])
        .map<List<Offset>>((poly) => (poly as List)
            .map<Offset>((p) => Offset(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ))
            .toList())
        .toList();
    return VisualizerMask(
      id: j['id'] as String,
      surface: j['surface'] as String,
      polygons: polys,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'surface': surface,
        'polygons': polygons
            .map((poly) =>
                poly.map((p) => {'x': p.dx, 'y': p.dy}).toList())
            .toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
