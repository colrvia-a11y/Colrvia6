// lib/models/fixed_elements.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a fixed element in a project such as flooring,
/// countertops, or existing tile that could influence palette choices.
class FixedElement {
  final String id;
  final String name;
  final String type; // e.g., floor, counter, tile
  final String undertone; // warm, cool, neutral

  FixedElement({
    required this.id,
    required this.name,
    required this.type,
    required this.undertone,
  });

  factory FixedElement.fromSnap(DocumentSnapshot snap) {
    final d = snap.data() as Map<String, dynamic>? ?? {};
    return FixedElement(
      id: snap.id,
      name: d['name'] ?? '',
      type: d['type'] ?? 'other',
      undertone: d['undertone'] ?? 'neutral',
    );
  }

  factory FixedElement.fromJson(String id, Map<String, dynamic> json) =>
      FixedElement(
        id: id,
        name: json['name'] ?? '',
        type: json['type'] ?? 'other',
        undertone: json['undertone'] ?? 'neutral',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'undertone': undertone,
      };

  FixedElement copyWith({String? name, String? type, String? undertone}) =>
      FixedElement(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        undertone: undertone ?? this.undertone,
      );
}
