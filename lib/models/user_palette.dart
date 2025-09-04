import 'package:flutter/material.dart';

class UserPalette {
  final List<Color> colors;
  final String? name;
  final String? id;

  const UserPalette({
    required this.colors,
    this.name,
    this.id,
  });
}
