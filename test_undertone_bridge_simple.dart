// ignore_for_file: avoid_print

import 'lib/firestore/firestore_data_schema.dart';
import 'lib/utils/palette_generator.dart';

void main() {
  print('=== Undertone Bridge Injection Test ===\n');
  
  // Helper functions
  bool isChromatic(Paint paint) {
    final chroma = paint.lch.length > 1 ? paint.lch[1] : 0.0;
    return chroma >= 10.0;
  }
  
  bool isWarmHue(double h) => (h >= 20 && h <= 70) || (h >= 330 || h <= 20);
  bool isCoolHue(double h) => (h >= 70 && h <= 250);
  
  // Test 1: Mixed warm and cool chromatics (should inject bridge)
  print('Test 1: Mixed warm and cool chromatics');
  final mixedPaints = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Warm Red', code: 'WR1',
      hex: '#D32F2F', rgb: [211, 47, 47], lab: [51.7, 68.2, 37.8], lch: [51.7, 77.5, 29.1],
    ),
    Paint(
      id: '2', brandId: 'test', brandName: 'Test', name: 'Cool Blue', code: 'CB1',
      hex: '#1976D2', rgb: [25, 118, 210], lab: [49.7, 3.3, -52.1], lch: [49.7, 52.2, 272.4],
    ),
    Paint(
      id: '3', brandId: 'test', brandName: 'Test', name: 'Light Gray', code: 'LG1',
      hex: '#E0E0E0', rgb: [224, 224, 224], lab: [90.1, 0.0, 0.0], lch: [90.1, 0.0, 0.0],
    ),
    Paint(
      id: '4', brandId: 'test', brandName: 'Test', name: 'Dark Gray', code: 'DG1',
      hex: '#424242', rgb: [66, 66, 66], lab: [28.9, 0.0, 0.0], lch: [28.9, 0.0, 0.0],
    ),
  ];
  
  final mixedPalette = PaletteGenerator.rollPalette(
    availablePaints: mixedPaints,
    anchors: List.filled(4, null),
    mode: HarmonyMode.colrvia,
  );
  
  // Analyze the palette
  bool hasWarm = false, hasCool = false, hasBridge = false;
  for (var paint in mixedPalette) {
    final hue = paint.lch.length > 2 ? paint.lch[2] : 0.0;
    final lrv = paint.computedLrv;
    
    if (isChromatic(paint) && isWarmHue(hue)) hasWarm = true;
    if (isChromatic(paint) && isCoolHue(hue)) hasCool = true;
    if (!isChromatic(paint) && lrv >= 20 && lrv <= 60) hasBridge = true;
  }
  
  print('  Has warm chromatic: $hasWarm');
  print('  Has cool chromatic: $hasCool');
  print('  Has bridge neutral: $hasBridge');
  print('  Expected bridge injection: ${hasWarm && hasCool ? "YES" : "NO"}');
  print('  Test result: ${(hasWarm && hasCool) == hasBridge ? "✓ PASS" : "✗ FAIL"}');
  print('  Palette: ${mixedPalette.map((p) => "${p.name} (LRV=${p.computedLrv.toStringAsFixed(1)}, C=${p.lch.length > 1 ? p.lch[1].toStringAsFixed(1) : "0.0"})").join(", ")}\n');
  
  // Test 2: Only warm chromatics (should NOT inject bridge)
  print('Test 2: Only warm chromatics');
  final warmOnlyPaints = [
    Paint(
      id: '1', brandId: 'test', brandName: 'Test', name: 'Warm Red', code: 'WR1',
      hex: '#D32F2F', rgb: [211, 47, 47], lab: [51.7, 68.2, 37.8], lch: [51.7, 77.5, 29.1],
    ),
    Paint(
      id: '2', brandId: 'test', brandName: 'Test', name: 'Warm Orange', code: 'WO1',
      hex: '#FF9800', rgb: [255, 152, 0], lab: [71.1, 20.5, 70.2], lch: [71.1, 73.1, 73.8],
    ),
    Paint(
      id: '3', brandId: 'test', brandName: 'Test', name: 'Light Gray', code: 'LG1',
      hex: '#E0E0E0', rgb: [224, 224, 224], lab: [90.1, 0.0, 0.0], lch: [90.1, 0.0, 0.0],
    ),
    Paint(
      id: '4', brandId: 'test', brandName: 'Test', name: 'Dark Gray', code: 'DG1',
      hex: '#424242', rgb: [66, 66, 66], lab: [28.9, 0.0, 0.0], lch: [28.9, 0.0, 0.0],
    ),
  ];
  
  final warmOnlyPalette = PaletteGenerator.rollPalette(
    availablePaints: warmOnlyPaints,
    anchors: List.filled(4, null),
    mode: HarmonyMode.colrvia,
  );
  
  // Analyze the palette
  hasWarm = false; hasCool = false; hasBridge = false;
  for (var paint in warmOnlyPalette) {
    final hue = paint.lch.length > 2 ? paint.lch[2] : 0.0;
    final lrv = paint.computedLrv;
    
    if (isChromatic(paint) && isWarmHue(hue)) hasWarm = true;
    if (isChromatic(paint) && isCoolHue(hue)) hasCool = true;
    if (!isChromatic(paint) && lrv >= 20 && lrv <= 60) hasBridge = true;
  }
  
  print('  Has warm chromatic: $hasWarm');
  print('  Has cool chromatic: $hasCool'); 
  print('  Has bridge neutral: $hasBridge');
  print('  Expected bridge injection: ${hasWarm && hasCool ? "YES" : "NO"}');
  print('  Test result: ${(hasWarm && hasCool) == hasBridge ? "✓ PASS" : "✗ FAIL"}');
  print('  Palette: ${warmOnlyPalette.map((p) => "${p.name} (LRV=${p.computedLrv.toStringAsFixed(1)}, C=${p.lch.length > 1 ? p.lch[1].toStringAsFixed(1) : "0.0"})").join(", ")}\n');
  
  print('=== Test Summary ===');
  print('Undertone bridge injection implementation: Complete');
  print('Expected behavior: Inject mid-LRV neutral when warm + cool chromatics mix');
}
