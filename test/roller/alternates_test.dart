import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('alternates', () {
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

    test('applies alternate when available', () async {
      when(() => repo.getAll()).thenAnswer(
          (_) async => List.generate(10, (i) => _FakePaint('p$i', '#000000')));
      when(() =>
          repo.getPool(
              brandIds: any(named: 'brandIds'),
              theme: any(named: 'theme'))).thenAnswer(
          (_) async => List.generate(10, (i) => _FakePaint('p$i', '#000000')));

      when(() => svc.generate(
                available: any(named: 'available'),
                anchors: any(named: 'anchors'),
                diversifyBrands: any(named: 'diversifyBrands'),
                slotLrvHints: any(named: 'slotLrvHints'),
                fixedUndertones: any(named: 'fixedUndertones'),
                themeSpec: any(named: 'themeSpec'),
                themeThreshold: any(named: 'themeThreshold'),
                attempts: any(named: 'attempts'),
                mode: any(named: 'mode'),
              ))
          .thenAnswer((_) async =>
              List.generate(5, (i) => _FakePaint('r$i', '#ABCDEF')));

      when(() => svc.alternatesForSlot(
            available: any(named: 'available'),
            anchors: any(named: 'anchors'),
            slotIndex: any(named: 'slotIndex'),
            diversifyBrands: any(named: 'diversifyBrands'),
            fixedUndertones: any(named: 'fixedUndertones'),
            themeSpec: any(named: 'themeSpec'),
            targetCount: any(named: 'targetCount'),
          )).thenAnswer((inv) async => [_FakePaint('alt1', '#111111')]);

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.initIfNeeded();
      await Future.delayed(const Duration(milliseconds: 10));

      await ctrl.useNextAlternateForStrip(0);
      final state = container.read(rollerControllerProvider).value!;
      expect(state.currentPage!.strips[0].id, 'alt1');
    });

    test('falls back to reroll when alternates empty', () async {
      when(() => repo.getAll()).thenAnswer(
          (_) async => List.generate(10, (i) => _FakePaint('p$i', '#000000')));
      when(() =>
          repo.getPool(
              brandIds: any(named: 'brandIds'),
              theme: any(named: 'theme'))).thenAnswer(
          (_) async => List.generate(10, (i) => _FakePaint('p$i', '#000000')));

      when(() => svc.generate(
                available: any(named: 'available'),
                anchors: any(named: 'anchors'),
                diversifyBrands: any(named: 'diversifyBrands'),
                slotLrvHints: any(named: 'slotLrvHints'),
                fixedUndertones: any(named: 'fixedUndertones'),
                themeSpec: any(named: 'themeSpec'),
                themeThreshold: any(named: 'themeThreshold'),
                attempts: any(named: 'attempts'),
                mode: any(named: 'mode'),
              ))
          .thenAnswer((_) async =>
              List.generate(5, (i) => _FakePaint('r$i', '#ABCDEF')));

      when(() => svc.alternatesForSlot(
            available: any(named: 'available'),
            anchors: any(named: 'anchors'),
            slotIndex: any(named: 'slotIndex'),
            diversifyBrands: any(named: 'diversifyBrands'),
            fixedUndertones: any(named: 'fixedUndertones'),
            themeSpec: any(named: 'themeSpec'),
            targetCount: any(named: 'targetCount'),
          )).thenAnswer((inv) async => <Paint>[]);

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.initIfNeeded();
      await Future.delayed(const Duration(milliseconds: 10));

      await ctrl.useNextAlternateForStrip(0);
      final state = container.read(rollerControllerProvider).value!;
      expect(state.currentPage!.strips[0].id.startsWith('r'), true);
    });
  });
}
