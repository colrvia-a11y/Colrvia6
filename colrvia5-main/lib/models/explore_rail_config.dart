import 'package:flutter/material.dart';

class ExploreRailConfig {
  final String title;
  final String? colorFamily;
  final String? undertone;
  final String? temperature;
  final RangeValues? lrvRange;
  final String? brandName;

  const ExploreRailConfig({
    required this.title,
    this.colorFamily,
    this.undertone,
    this.temperature,
    this.lrvRange,
    this.brandName,
  });
}
