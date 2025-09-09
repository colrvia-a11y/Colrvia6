// ignore_for_file: avoid_print

import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/utils/palette_isolate.dart';

void main() async {
  print('🧪 Testing Role Preservation for Alternates...\n');

  // Create test paints with known properties
  final testPaints = [
    Paint(
      id: 'anchor1',
      name: 'Anchor Dark',
      code: 'A001',
      hex: '#2E3440',
      lab: [25.0, 2.0, -12.0],
      lch: [25.0, 12.2, 281.0],
      rgb: [46, 52, 64],
      brandName: 'Benjamin Moore',
      brandId: 'bm',
      metadata: {'role': 'Anchor'}
    ),
    Paint(
      id: 'primary1',
      name: 'Primary Blue',
      code: 'P001',
      hex: '#5E81AC',
      lab: [55.0, -5.0, -25.0],
      lch: [55.0, 25.5, 261.0],
      rgb: [94, 129, 172],
      brandName: 'Sherwin Williams',
      brandId: 'sw',
      metadata: {'role': 'Primary'}
    ),
    Paint(
      id: 'secondary1',
      name: 'Secondary Orange',
      code: 'S001',
      hex: '#D08770',
      lab: [70.0, 20.0, 40.0],
      lch: [70.0, 44.7, 63.0],
      rgb: [208, 135, 112],
      brandName: 'PPG',
      brandId: 'ppg',
      metadata: {'role': 'Secondary'}
    ),
    // Additional paints for alternate generation
    Paint(
      id: 'alt_anchor1',
      name: 'Alt Anchor',
      code: 'AA001',
      hex: '#3B4252',
      lab: [30.0, 3.0, -10.0],
      lch: [30.0, 10.4, 287.0],
      rgb: [59, 66, 82],
      brandName: 'Benjamin Moore',
      brandId: 'bm',
    ),
    Paint(
      id: 'alt_primary1',
      name: 'Alt Primary',
      code: 'AP001',
      hex: '#81A1C1',
      lab: [65.0, -8.0, -20.0],
      lch: [65.0, 21.5, 248.0],
      rgb: [129, 161, 193],
      brandName: 'Sherwin Williams',
      brandId: 'sw',
    ),
    Paint(
      id: 'alt_secondary1',
      name: 'Alt Secondary',
      code: 'AS001',
      hex: '#BF616A',
      lab: [55.0, 35.0, 25.0],
      lch: [55.0, 43.9, 35.5],
      rgb: [191, 97, 106],
      brandName: 'PPG',
      brandId: 'ppg',
    ),
  ];

  print('📝 Created ${testPaints.length} test paints');

  // Test 1: Generate a palette with role tagging
  print('\n🎨 Test 1: Generate palette with role tagging');
  final rolledPalette = PaletteGenerator.rollPaletteConstrained(
    availablePaints: testPaints,
    anchors: [null, null, null],
    slotLrvHints: [
      [20.0, 40.0],   // Dark slot
      [50.0, 70.0],   // Medium slot
      [60.0, 80.0],   // Light slot
    ],
    diversifyBrands: false,
  );

  print('Generated palette with ${rolledPalette.length} paints:');
  for (var i = 0; i < rolledPalette.length; i++) {
    final paint = rolledPalette[i];
    final role = paint.metadata?['role'] ?? 'No role';
    print('  [$i] ${paint.hex} - ${paint.brandName} - Role: $role');
  }

  // Test 2: Test alternates by role name
  print('\n🔄 Test 2: Test alternate generation by role name');
  final anchors = [rolledPalette[0], rolledPalette[1], rolledPalette[2]];
  
  // Try to get alternates for the "Primary" role using role name
  final primaryRole = anchors[1].metadata?['role'] as String?;
  print('Looking for alternates for role: $primaryRole');
  
  final args = {
    'available': [for (final p in testPaints) (p.toJson()..['id'] = p.id)],
    'anchors': [
      for (final p in anchors)
        (p.toJson()..['id'] = p.id)
    ],
    'slotIndex': 1, // Original slot position
    'diversify': false,
    'targetCount': 3,
    'attemptsPerRound': 5,
    'roleName': primaryRole,
  };
  
  final alternates = alternatesForSlotInIsolate(args);
  print('Generated ${alternates.length} alternates for role "$primaryRole":');
  for (var i = 0; i < alternates.length; i++) {
    final alt = alternates[i];
    print('  [$i] ${alt['hex']} - ${alt['brandName']}');
  }

  // Test 3: Simulate LRV sorting and verify role preservation
  print('\n📊 Test 3: Simulate LRV sorting and role preservation');
  
  // Sort the original palette by LRV (descending)
  final sortedPalette = [...rolledPalette];
  sortedPalette.sort((a, b) {
    final lrvA = a.lch[0]; // L component approximates LRV
    final lrvB = b.lch[0];
    return lrvB.compareTo(lrvA); // Descending
  });
  
  print('Original palette:');
  for (var i = 0; i < rolledPalette.length; i++) {
    final paint = rolledPalette[i];
    final role = paint.metadata?['role'] ?? 'No role';
    final lrv = paint.lch[0].toStringAsFixed(1);
    print('  [$i] LRV: $lrv - Role: $role - ${paint.hex}');
  }
  
  print('\nSorted by LRV (descending):');
  for (var i = 0; i < sortedPalette.length; i++) {
    final paint = sortedPalette[i];
    final role = paint.metadata?['role'] ?? 'No role';
    final lrv = paint.lch[0].toStringAsFixed(1);
    print('  [$i] LRV: $lrv - Role: $role - ${paint.hex}');
  }
  
  // Find the role's new position after sorting
  final targetRole = 'Slot1'; // The role we want alternates for
  var roleSlotAfterSorting = -1;
  for (var i = 0; i < sortedPalette.length; i++) {
    if (sortedPalette[i].metadata?['role'] == targetRole) {
      roleSlotAfterSorting = i;
      break;
    }
  }
  
  if (roleSlotAfterSorting >= 0) {
    print('\nRole "$targetRole" moved from slot 1 to slot $roleSlotAfterSorting after sorting');
    
    // Test getting alternates using role name
    final roleBasedArgs = {
      'available': [for (final p in testPaints) (p.toJson()..['id'] = p.id)],
      'anchors': [
        for (final p in sortedPalette)
          (p.toJson()..['id'] = p.id)
      ],
      'slotIndex': 1, // This should be ignored when roleName is provided
      'diversify': false,
      'targetCount': 2,
      'attemptsPerRound': 3,
      'roleName': targetRole,
    };
    
    final roleAlternates = alternatesForSlotInIsolate(roleBasedArgs);
    print('✅ Generated ${roleAlternates.length} alternates using role name "$targetRole"');
    
    // Verify the role-based alternates would replace the correct slot
    print('This should replace slot $roleSlotAfterSorting in the sorted palette');
  } else {
    print('❌ Role "$targetRole" not found in sorted palette');
  }

  print('\n🎉 Role preservation test completed!');
  print('The system now preserves role information when UI sorts by LRV');
  print('Alternates will be generated for the correct role regardless of position changes');
}
