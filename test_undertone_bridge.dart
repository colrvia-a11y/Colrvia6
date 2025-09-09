// Test script for undertone bridge injection in Colrvia path
// ignore_for_file: avoid_print

import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/utils/color_utils.dart';

void main() {
  print('=== Testing Undertone Bridge Injection ===\n');
  
  // Create test paints with warm and cool chromatic colors and potential bridge neutrals
  final availablePaints = [
    // Warm chromatic paint (Red - H~25, high C)
    Paint(
      id: 'warm1',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Warm Red',
      code: 'WR1',
      hex: '#CC4444',
      rgb: [204, 68, 68],
      lab: [45.0, 45.0, 25.0],
      lch: [45.0, 51.0, 25.0], // Warm hue, high chroma
    ),
    // Cool chromatic paint (Blue - H~240, high C)
    Paint(
      id: 'cool1',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Cool Blue',
      code: 'CB1',
      hex: '#4444CC',
      rgb: [68, 68, 204],
      lab: [35.0, 25.0, -45.0],
      lch: [35.0, 51.0, 240.0], // Cool hue, high chroma
    ),
    // Very light neutral (no bridge)
    Paint(
      id: 'light1',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Light Gray',
      code: 'LG1',
      hex: '#DDDDDD',
      rgb: [221, 221, 221],
      lab: [87.0, 0.0, 0.0],
      lch: [87.0, 0.0, 0.0], // Very light, low chroma
    ),
    // Dark neutral (no bridge)
    Paint(
      id: 'dark1',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Dark Gray',
      code: 'DG1',
      hex: '#333333',
      rgb: [51, 51, 51],
      lab: [20.0, 0.0, 0.0],
      lch: [20.0, 0.0, 0.0], // Dark, low chroma
    ),
    // PERFECT BRIDGE: Mid-LRV neutral (should be selected as bridge)
    Paint(
      id: 'bridge1',
      brandId: 'test-brand',
      brandName: 'TestBrand',
      name: 'Mid Neutral',
      code: 'MN1',
      hex: '#888888',
      rgb: [136, 136, 136],
      lab: [55.0, 0.0, 0.0],
      lch: [55.0, 8.0, 0.0], // Mid LRV, low chroma - perfect bridge
    ),
  ];

  // Test with a 4-color palette containing warm + cool but no existing bridge
  final anchors = <Paint?>[null, null, null, null];
  
  print('Available paints:');
  for (final paint in availablePaints) {
    final lch = ColorUtils.labToLch(paint.lab);
    print('  ${paint.name}: LRV=${paint.computedLrv.toStringAsFixed(1)}, '
          'C=${lch[1].toStringAsFixed(1)}, H=${lch[2].toStringAsFixed(1)}');
  }
  
  // Generate palette using Colrvia algorithm
  final result = PaletteGenerator.rollPalette(
    availablePaints: availablePaints,
    anchors: anchors,
    mode: HarmonyMode.colrvia,
    diversifyBrands: false,
  );
  
  print('\nGenerated palette:');
  bool hasWarm = false, hasCool = false, hasBridge = false;
  
  for (int i = 0; i < result.length; i++) {
    final paint = result[i];
    final lch = ColorUtils.labToLch(paint.lab);
    final h = ((lch[2] % 360) + 360) % 360;
    final c = lch[1];
    final l = paint.computedLrv;
    
    // Check warm/cool classification
    bool isWarm = (h >= 20 && h <= 70) || (h >= 330 || h <= 20);
    bool isCool = (h >= 70 && h <= 250);
    bool isChromatic = c > 12.0;
    bool isBridge = c <= 12.0 && l >= 35.0 && l <= 75.0;
    
    if (isChromatic && isWarm) hasWarm = true;
    if (isChromatic && isCool) hasCool = true;
    if (isBridge) hasBridge = true;
    
    String classification = '';
    if (isChromatic) {
      if (isWarm) {
        classification = ' (WARM CHROMATIC)';
      } else if (isCool) {
        classification = ' (COOL CHROMATIC)';
      } else {
        classification = ' (NEUTRAL CHROMATIC)';
      }
    } else if (isBridge) {
      classification = ' (BRIDGE NEUTRAL)';
    } else {
      classification = ' (OTHER NEUTRAL)';
    }
    
    print('  ${i + 1}. ${paint.name}: LRV=${l.toStringAsFixed(1)}, '
          'C=${c.toStringAsFixed(1)}, H=${h.toStringAsFixed(1)}$classification');
  }
  
  print('\nBridge analysis:');
  print('  Has warm chromatic: $hasWarm');
  print('  Has cool chromatic: $hasCool');
  print('  Has bridge neutral: $hasBridge');
  
  // Verify acceptance criteria
  if (hasWarm && hasCool) {
    print('\n✓ Warm + cool mix detected');
    if (hasBridge) {
      print('✓ Bridge neutral successfully injected!');
      print('✓ ACCEPTANCE CRITERIA MET: Bridge injection working correctly');
    } else {
      print('✗ FAILED: No bridge neutral found despite warm + cool mix');
    }
  } else {
    print('\n- No warm + cool mix, bridge injection not needed');
  }
  
  print('\n=== Undertone Bridge Injection Test Complete ===');
}
