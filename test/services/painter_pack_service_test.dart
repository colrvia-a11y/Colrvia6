import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/models/color_plan.dart';
import 'package:color_canvas/services/painter_pack_service.dart';
import 'package:color_canvas/models/schema.dart' as schema;

void main() {
  group('PainterPackService', () {
    test('buildPdf generates non-empty PDF', () async {
      final service = PainterPackService();
      final now = DateTime.now();
      final plan = ColorPlan(
        id: 'test-plan',
        name: 'Test Plan',
        vibe: 'Modern and minimal',
        projectId: 'test-project',
        paletteColorIds: ['color1', 'color2'],
        placementMap: [
          PlanPlacement(
            colorId: 'color1',
            area: 'Living Room Walls',
            sheen: 'Matte',
          ),
          PlanPlacement(
            colorId: 'color2',
            area: 'Kitchen Cabinets',
            sheen: 'Semi-Gloss',
          ),
        ],
        doDont: [
          DoDontEntry(
            doText: 'Use even coats',
            dontText: 'Skip primer',
          ),
        ],
        cohesionTips: ['Use a consistent sheen pattern'],
        accentRules: [
          AccentRule(
            context: 'Accent walls',
            guidance: 'Use darker shades sparingly',
          ),
        ],
        sampleSequence: ['Prime', 'First coat', 'Second coat'],
        roomPlaybook: [
          RoomPlaybookItem(
            roomType: 'Living Room',
            placements: [],
            notes: 'Keep it bright and airy',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final pdf = await service.buildPdf(plan, {
        'color1': schema.PaletteColor(
          paintId: 'color1',
          locked: false,
          position: 0,
          brand: 'Sherwin-Williams',
          name: 'Test Color 1',
          code: 'SW1234',
          hex: '#FFFFFF',
        ),
        'color2': schema.PaletteColor(
          paintId: 'color2',
          locked: false,
          position: 1,
          brand: 'Sherwin-Williams',
          name: 'Test Color 2',
          code: 'SW5678',
          hex: '#000000',
        ),
      });

      expect(pdf.length, greaterThan(0));
    });
  });
}
