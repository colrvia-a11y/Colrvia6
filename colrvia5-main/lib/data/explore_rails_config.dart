import 'package:flutter/material.dart';
import '../models/explore_rail_config.dart';

/// Edit this list to add/remove rails. No widget code changes needed.
const List<ExploreRailConfig> kDefaultExploreRails = [
  ExploreRailConfig(
    title: 'Warm Reds',
    colorFamily: 'Red',
    temperature: 'Warm',
  ),
  ExploreRailConfig(
    title: 'Light Blues (LRV 70–85)',
    colorFamily: 'Blue',
    lrvRange: RangeValues(70, 85),
  ),
  ExploreRailConfig(
    title: 'Balanced Greiges',
    colorFamily: 'Neutral',
    undertone: 'green',
  ),
  ExploreRailConfig(
    title: 'Cool Charcoals',
    colorFamily: 'Neutral',
    temperature: 'Cool',
    lrvRange: RangeValues(5, 22),
  ),
  ExploreRailConfig(
    title: 'Bedrooms we love',
  ),
];
