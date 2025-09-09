import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

class _FakePaint extends Paint {
  _FakePaint(String id, String hex)
      : super(
          id: id,
          brandId: 'b',
          brandName: 'Brand',
          name: 'N$id',
          code: 'C$id',
          rgb: const [0, 0, 0],
          hex: hex,
          lab: const [0, 0, 0],
          lch: const [0, 0, 0],
        );
}

class MockRepo extends Mock implements PaintRepository {}
class MockSvc extends Mock implements PaletteService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RollerController', () {
    late MockRepo repo;
    late MockSvc svc;
    late ProviderContainer container;

    setUp(() {
      repo = MockRepo();
      svc = MockSvc();
      container = ProviderContainer(overrides: [
        paintRepositoryProvider.overrideWithValue(repo),
        paletteServiceProvider.overrideWithValue(svc),
      ]);
    });

    tearDown(() => container.dispose());

    test('initIfNeeded triggers first roll and populates a page', () async {
      when(() => repo.getAll()).thenAnswer((_) async => List.generate(20, (i) => _FakePaint('p$i', '#000000')));
      when(() => repo.filterByBrands(any(), any())).thenAnswer((inv) => inv.positionalArguments[0] as List<Paint>);
      when(() => repo.getPool(brandIds: any(named: 'brandIds'), theme: any(named: 'theme')))
          .thenAnswer((_) async => List.generate(20, (i) => _FakePaint('p$i', '#000000')));

      when(() => svc.generate(
            available: any(named: 'available'),
            anchors: any(named: 'anchors'),
            diversifyBrands: any(named: 'diversifyBrands'),
            slotLrvHints: any(named: 'slotLrvHints'),
            fixedUndertones: any(named: 'fixedUndertones'),
            themeSpec: any(named: 'themeSpec'),
            themeThreshold: any(named: 'themeThreshold'),
            attempts: any(named: 'attempts'),
          )).thenAnswer((_) async => List.generate(5, (i) => _FakePaint('r$i', '#ABCDEF')));

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.initIfNeeded();
      final state = container.read(rollerControllerProvider).value!;
      expect(state.pages.length, 1);
      expect(state.pages.first.strips.length, 5);
    });

    test('rerollStrip changes only that strip', () async {
      when(() => repo.getAll()).thenAnswer((_) async => List.generate(20, (i) => _FakePaint('p$i', '#000000')));
      when(() => repo.filterByBrands(any(), any())).thenReturn(List.generate(20, (i) => _FakePaint('p$i', '#000000')));
      when(() => repo.getPool(brandIds: any(named: 'brandIds'), theme: any(named: 'theme')))
          .thenAnswer((_) async => List.generate(20, (i) => _FakePaint('p$i', '#000000')));

      when(() => svc.generate(
            available: any(named: 'available'),
            anchors: any(named: 'anchors'),
            diversifyBrands: any(named: 'diversifyBrands'),
            slotLrvHints: any(named: 'slotLrvHints'),
            fixedUndertones: any(named: 'fixedUndertones'),
            themeSpec: any(named: 'themeSpec'),
            themeThreshold: any(named: 'themeThreshold'),
            attempts: any(named: 'attempts'),
          )).thenAnswer((inv) async {
        final anchors = inv.namedArguments[#anchors] as List<Paint?>;
        // Return anchors + one changed slot at index 2
        final out = List<Paint>.generate(5, (i) => anchors[i] ?? _FakePaint('new$i', '#123456'));
        out[2] = _FakePaint('changed', '#654321');
        return out;
      });

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.rollNext();
      final before = container.read(rollerControllerProvider).value!.pages.first.strips.map((e) => e.id).toList();
      await ctrl.rerollStrip(2);
      final after = container.read(rollerControllerProvider).value!.pages.first.strips.map((e) => e.id).toList();
      expect(before[2] != after[2], true);
      for (var i = 0; i < before.length; i++) {
        if (i == 2) continue;
        expect(before[i], after[i]);
      }
    });
  });
}

