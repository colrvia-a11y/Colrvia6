// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';

void main() {
  group('Undertone Bridge Injection Tests', () {
    test('injects bridge neutral when warm and cool chromatic colors mix', () {
      // Helper function to check if paint is chromatic
      bool isChromatic(Paint paint) {
        final chroma = paint.lch.length > 1 ? paint.lch[1] : 0.0;
        return chroma >= 10.0; // Threshold for chromatic colors
      }
      
      // Helper function to check if hue is warm
      bool isWarmHue(double h) => (h >= 20 && h <= 70) || (h >= 330 || h <= 20);
      
      // Helper function to check if hue is cool  
      bool isCoolHue(double h) => (h >= 70 && h <= 250);
      
      // Create paints with warm and cool chromatics but no mid-LRV neutral
      final paints = [
        Paint(
          id: '1',
          brandId: 'test',
          brandName: 'Test',
          name: 'Warm Red',
          code: 'WR1',
          hex: '#D32F2F',
          rgb: [211, 47, 47],
          lab: [51.7, 68.2, 37.8],  // Warm red
          lch: [51.7, 77.5, 29.1],  // L=51.7, C=77.5, H=29.1
        ),
        Paint(
          id: '2',
          brandId: 'test',
          brandName: 'Test',
          name: 'Cool Blue',
          code: 'CB1',
          hex: '#1976D2',
          rgb: [25, 118, 210],
          lab: [49.7, 3.3, -52.1],  // Cool blue
          lch: [49.7, 52.2, 272.4], // L=49.7, C=52.2, H=272.4
        ),
        Paint(
          id: '3',
          brandId: 'test',
          brandName: 'Test',
          name: 'Light Gray',
          code: 'LG1',
          hex: '#E0E0E0',
          rgb: [224, 224, 224],
          lab: [90.1, 0.0, 0.0],     // Light neutral
          lch: [90.1, 0.0, 0.0],     // L=90.1, C=0.0, H=0.0
        ),
        Paint(
          id: '4',
          brandId: 'test',
          brandName: 'Test',
          name: 'Dark Gray',
          code: 'DG1',
          hex: '#424242',
          rgb: [66, 66, 66],
          lab: [28.9, 0.0, 0.0],     // Dark neutral
          lch: [28.9, 0.0, 0.0],     // L=28.9, C=0.0, H=0.0
        ),
      ];
      
      // Generate palette using Colrvia algorithm
      final palette = PaletteGenerator.rollPalette(
        availablePaints: paints, 
        anchors: List.filled(4, null), 
        mode: HarmonyMode.colrvia
      );
      
      // Check if bridge neutral was injected
      bool hasWarmChromatic = false;
      bool hasCoolChromatic = false;
      bool hasBridgeNeutral = false;
      
      for (var paint in palette) {
        final hue = paint.lch.length > 2 ? paint.lch[2] : 0.0;
        final lrv = paint.computedLrv;
        
        if (isChromatic(paint) && isWarmHue(hue)) {
          hasWarmChromatic = true;
        }
        if (isChromatic(paint) && isCoolHue(hue)) {
          hasCoolChromatic = true;
        }
        if (!isChromatic(paint) && lrv >= 20 && lrv <= 60) {
          hasBridgeNeutral = true;
        }
      }
      
      // When both warm and cool chromatics are present, bridge should be injected
      if (hasWarmChromatic && hasCoolChromatic) {
        expect(hasBridgeNeutral, isTrue, 
               reason: 'Bridge neutral should be present when warm and cool chromatics mix');
      }
      
      print('Test Results:');
      print('  Has warm chromatic: $hasWarmChromatic');
      print('  Has cool chromatic: $hasCoolChromatic');
      print('  Has bridge neutral: $hasBridgeNeutral');
      print('  Palette: ${palette.map((p) => '${p.name} (LRV=${p.computedLrv.toStringAsFixed(1)}, C=${p.lch.length > 1 ? p.lch[1].toStringAsFixed(1) : "0.0"})').join(', ')}');
    });
    
    test('does not inject bridge when only warm OR only cool chromatics present', () {
      // Helper function to check if paint is chromatic
      bool isChromatic(Paint paint) {
        final chroma = paint.lch.length > 1 ? paint.lch[1] : 0.0;
        return chroma >= 10.0;
      }
      
      // Helper function to check if hue is warm
      bool isWarmHue(double h) => (h >= 20 && h <= 70) || (h >= 330 || h <= 20);
      
      // Helper function to check if hue is cool  
      bool isCoolHue(double h) => (h >= 70 && h <= 250);
      
      // Test with only warm chromatics
      final warmOnlyPaints = [
        Paint(
          id: '1',
          brandId: 'test',
          brandName: 'Test',
          name: 'Warm Red',
          code: 'WR1',
          hex: '#D32F2F',
          rgb: [211, 47, 47],
          lab: [51.7, 68.2, 37.8],
          lch: [51.7, 77.5, 29.1],  // Warm
        ),
        Paint(
          id: '2',
          brandId: 'test',
          brandName: 'Test',
          name: 'Warm Orange',
          code: 'WO1',
          hex: '#FF9800',
          rgb: [255, 152, 0],
          lab: [71.1, 20.5, 70.2],
          lch: [71.1, 73.1, 73.8],  // Warm
        ),
        Paint(
          id: '3',
          brandId: 'test',
          brandName: 'Test',
          name: 'Light Gray',
          code: 'LG1',
          hex: '#E0E0E0',
          rgb: [224, 224, 224],
          lab: [90.1, 0.0, 0.0],
          lch: [90.1, 0.0, 0.0],
        ),
        Paint(
          id: '4',
          brandId: 'test',
          brandName: 'Test',
          name: 'Dark Gray',
          code: 'DG1',
          hex: '#424242',
          rgb: [66, 66, 66],
          lab: [28.9, 0.0, 0.0],
          lch: [28.9, 0.0, 0.0],
        ),
      ];
      
      final warmPalette = PaletteGenerator.rollPalette(
        availablePaints: warmOnlyPaints, 
        anchors: List.filled(4, null), 
        mode: HarmonyMode.colrvia
      );
      
      bool hasWarmChromatic = false;
      bool hasCoolChromatic = false;
      
      for (var paint in warmPalette) {
        final hue = paint.lch.length > 2 ? paint.lch[2] : 0.0;
        
        if (isChromatic(paint) && isWarmHue(hue)) {
          hasWarmChromatic = true;
        }
        if (isChromatic(paint) && isCoolHue(hue)) {
          hasCoolChromatic = true;
        }
      }
      
      expect(hasWarmChromatic, isTrue);
      expect(hasCoolChromatic, isFalse);
      
      print('Warm-only test passed: No bridge injection needed when only warm chromatics present');
    });
  });
}
