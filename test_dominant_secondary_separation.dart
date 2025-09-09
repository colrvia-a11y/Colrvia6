// Test for Dominant vs. Secondary Separation Feature
//
// This test verifies that the dominant vs. secondary separation check
// correctly identifies and scores palettes based on hue and value differences
// between dominant and secondary colors.

// ignore_for_file: avoid_print

import 'package:color_canvas/firestore/firestore_data_schema.dart' show Paint;
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';

void main() {
  print('=== Testing Dominant vs. Secondary Separation ===\n');

  // Create test theme spec
  final spec = ThemeSpec(
    id: 'test',
    label: 'Test Theme',
    weights: {
      'dominantSecondarySeparation': 1.0, // Full weight for testing
    },
  );

  // Test Case 1: Good L separation (ΔL = 20)
  print('Test 1: Good L separation (should score 1.0)');
  final palette1 = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Dark', code: 'T1',
      hex: '#4A4A4A', rgb: [74, 74, 74], lab: [30.0, 0.0, 0.0], lch: [30.0, 5.0, 0.0]
    ),
    Paint(
      id: '2', brandId: 'test', brandName: 'Test', name: 'Mid', code: 'T2',
      hex: '#808080', rgb: [128, 128, 128], lab: [50.0, 0.0, 0.0], lch: [50.0, 5.0, 0.0]
    ),
    Paint(
      id: '3', brandId: 'test', brandName: 'Test', name: 'Light', code: 'T3',
      hex: '#B3B3B3', rgb: [179, 179, 179], lab: [70.0, 0.0, 0.0], lch: [70.0, 5.0, 0.0]
    ),
  ];
  final score1 = ThemeEngine.scorePalette(palette1, spec);
  print('Score: ${score1.toStringAsFixed(3)}');
  print('Explanation: ${ThemeEngine.explain(palette1, spec)}\n');

  // Test Case 2: Good H separation (ΔH = 180°)
  print('Test 2: Good H separation (should score 1.0)');
  final palette2 = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Red', code: 'T1',
      hex: '#804040', rgb: [128, 64, 64], lab: [40.0, 20.0, 10.0], lch: [40.0, 20.0, 0.0]
    ),
    Paint(
      id: '2', brandId: 'test', brandName: 'Test', name: 'Cyan', code: 'T2',
      hex: '#408080', rgb: [64, 128, 128], lab: [40.0, -20.0, -10.0], lch: [40.0, 20.0, 180.0]
    ),
    Paint(
      id: '3', brandId: 'test', brandName: 'Test', name: 'Neutral', code: 'T3',
      hex: '#808080', rgb: [128, 128, 128], lab: [50.0, 0.0, 0.0], lch: [50.0, 5.0, 0.0]
    ),
  ];
  final score2 = ThemeEngine.scorePalette(palette2, spec);
  print('Score: ${score2.toStringAsFixed(3)}');
  print('Explanation: ${ThemeEngine.explain(palette2, spec)}\n');

  // Test Case 3: Poor separation (ΔL = 3, ΔH = 8°)
  print('Test 3: Poor separation (should score 0.0)');
  final palette3 = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Similar1', code: 'T1',
      hex: '#606060', rgb: [96, 96, 96], lab: [38.0, 5.0, 5.0], lch: [38.0, 8.0, 45.0]
    ),
    Paint(
      id: '2', brandId: 'test', brandName: 'Test', name: 'Similar2', code: 'T2',
      hex: '#656565', rgb: [101, 101, 101], lab: [41.0, 6.0, 6.0], lch: [41.0, 8.0, 53.0]
    ),
    Paint(
      id: '3', brandId: 'test', brandName: 'Test', name: 'Neutral', code: 'T3',
      hex: '#808080', rgb: [128, 128, 128], lab: [50.0, 0.0, 0.0], lch: [50.0, 5.0, 0.0]
    ),
  ];
  final score3 = ThemeEngine.scorePalette(palette3, spec);
  print('Score: ${score3.toStringAsFixed(3)}');
  print('Explanation: ${ThemeEngine.explain(palette3, spec)}\n');

  // Test Case 4: Moderate separation (ΔL = 6, ΔH = 15°)
  print('Test 4: Moderate separation (should score between 0.0 and 1.0)');
  final palette4 = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Moderate1', code: 'T1',
      hex: '#555555', rgb: [85, 85, 85], lab: [35.0, 7.0, 5.0], lch: [35.0, 10.0, 30.0]
    ),
    Paint(
      id: '2', brandId: 'test', brandName: 'Test', name: 'Moderate2', code: 'T2',
      hex: '#707070', rgb: [112, 112, 112], lab: [41.0, 7.0, 7.0], lch: [41.0, 10.0, 45.0]
    ),
    Paint(
      id: '3', brandId: 'test', brandName: 'Test', name: 'Neutral', code: 'T3',
      hex: '#808080', rgb: [128, 128, 128], lab: [50.0, 0.0, 0.0], lch: [50.0, 5.0, 0.0]
    ),
  ];
  final score4 = ThemeEngine.scorePalette(palette4, spec);
  print('Score: ${score4.toStringAsFixed(3)}');
  print('Explanation: ${ThemeEngine.explain(palette4, spec)}\n');

  // Test Case 5: Single color (should default to 1.0)
  print('Test 5: Single color palette (should score 1.0)');
  final palette5 = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Single', code: 'T1',
      hex: '#808080', rgb: [128, 128, 128], lab: [50.0, 0.0, 0.0], lch: [50.0, 5.0, 0.0]
    ),
  ];
  final score5 = ThemeEngine.scorePalette(palette5, spec);
  print('Score: ${score5.toStringAsFixed(3)}');
  print('Explanation: ${ThemeEngine.explain(palette5, spec)}\n');

  print('✓ Dominant vs. Secondary Separation test completed');
  print('Expected behavior:');
  print('- Test 1 & 2: High scores (≥0.8) due to good separation');
  print('- Test 3: Low score (~0.0) due to poor separation');
  print('- Test 4: Moderate score (~0.3-0.7) due to partial separation');
  print('- Test 5: High score (1.0) as default for single color');
  print('\n=== Dominant vs. Secondary Separation Test Complete ===');
}
