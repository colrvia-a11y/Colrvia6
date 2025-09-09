// lib/models/saved_photo.dart
import 'dart:typed_data';

class SavedPhoto {
  final String id;
  final String userId;
  final Uint8List imageData;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  SavedPhoto({
    required this.id,
    required this.userId,
    required this.imageData,
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  factory SavedPhoto.fromMap(Map<String, dynamic> map) {
    return SavedPhoto(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      imageData: map['imageData'] ?? Uint8List(0),
      description: map['description'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'imageData': imageData,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  SavedPhoto copyWith({
    String? id,
    String? userId,
    Uint8List? imageData,
    String? description,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return SavedPhoto(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imageData: imageData ?? this.imageData,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'SavedPhoto(id: $id, userId: $userId, description: $description, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedPhoto &&
        other.id == id &&
        other.userId == userId &&
        other.description == description &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        description.hashCode ^
        createdAt.hashCode;
  }
}
