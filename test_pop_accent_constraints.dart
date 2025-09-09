// Test script for Pop Accent constraints
import 'dart:developer' show log;

import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';

void main() {
  log('=== Testing Pop Accent Constraints ===\n');

  // Create test theme spec with pop constraints
  final themeSpec = ThemeSpec(
    id: 'test-pop-theme',
    label: 'Test Pop Theme',
    varietyControls: const VarietyControls(
      minColors: 3,
      maxColors: 5,
      mustIncludeNeutral: false,
      mustIncludeAccent: false,
      popChromaMin: 18.0,
      maxPops: 1,
      mutedPalettePrefersMutedPop: true,
    ),
  );

  // Create test palette with 2 high-chroma colors (should fail validation)
  final highChromaPalette = [
    Paint(
      id: 'paint1',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Red Pop',
      code: 'R1',
      hex: '#FF0000',
      rgb: [255, 0, 0],
      lab: [53.2, 80.1, 67.2],
      lch: [53.2, 104.6, 40.0], // High chroma
    ),
    Paint(
      id: 'paint2',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Green Pop',
      code: 'G1',
      hex: '#00FF00',
      rgb: [0, 255, 0],
      lab: [87.7, -86.2, 83.2],
      lch: [87.7, 119.8, 136.0], // High chroma
    ),
    Paint(
      id: 'paint3',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Neutral Gray',
      code: 'N1',
      hex: '#888888',
      rgb: [136, 136, 136],
      lab: [58.0, 0.0, 0.0],
      lch: [58.0, 0.0, 0.0], // Low chroma neutral
    ),
  ];

  // Test validation - should fail with "too_many_pops"
  final validationResult = ThemeEngine.validatePaletteRules(highChromaPalette, themeSpec);
  log('High chroma palette validation: ${validationResult ?? "PASSED"}');
  
  // Test shows the pop accent constraint is working
  if (validationResult == 'too_many_pops') {
    log('✓ Pop accent constraint validation is working correctly!');
  } else {
    log('✗ Unexpected validation result: $validationResult');
  }

  log('\n=== Pop Accent Constraints Implementation Complete ===');
}
