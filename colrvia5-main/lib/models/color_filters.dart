// lib/models/color_filters.dart
import 'package:flutter/material.dart';

class ColorFilters {
  final String? colorFamily;
  final String? undertone;
  final String? temperature;
  final RangeValues? lrvRange;
  final String? brandName;

  const ColorFilters({
    this.colorFamily,
    this.undertone,
    this.temperature,
    this.lrvRange,
    this.brandName,
  });

  // Optional convenience
  ColorFilters clear() => const ColorFilters();

  // --- Sentinel-based copyWith: allows explicit nulls ---
  static const Object _unset = Object();

  ColorFilters copyWith({
    Object? colorFamily = _unset,
    Object? undertone = _unset,
    Object? temperature = _unset,
    Object? lrvRange = _unset,
    Object? brandName = _unset,
  }) {
    return ColorFilters(
      colorFamily: identical(colorFamily, _unset) ? this.colorFamily : colorFamily as String?,
      undertone: identical(undertone, _unset) ? this.undertone : undertone as String?,
      temperature: identical(temperature, _unset) ? this.temperature : temperature as String?,
      lrvRange: identical(lrvRange, _unset) ? this.lrvRange : lrvRange as RangeValues?,
      brandName: identical(brandName, _unset) ? this.brandName : brandName as String?,
    );
  }

  bool get isEmpty =>
      colorFamily == null &&
      undertone == null &&
      temperature == null &&
      lrvRange == null &&
      brandName == null;

  @override
  String toString() => 'ColorFilters(colorFamily: $colorFamily, undertone: $undertone, temperature: $temperature, lrvRange: $lrvRange, brandName: $brandName)';
}
