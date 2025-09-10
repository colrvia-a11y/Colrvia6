import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart' show HarmonyMode;

class _FakePaint extends Paint {
  _FakePaint(String id, String hex, {double l = 50})
      : super(
          id: id,
          brandId: 'b',
            brandName: 'Brand',
          name: 'N$id',
          code: 'C$id',
          rgb: const [0, 0, 0],
          hex: hex,
          lab: [l, 0, 0],
          lch: [l, 0, 0],
          lrv: l,
        );
}

class MockRepo extends Mock implements PaintRepository {}
class MockSvc extends Mock implements PaletteService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(HarmonyMode.colrvia);
  });

  group('reroll with locked colors', () {
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

      // brand filter passthrough
      when(() => repo.filterByBrands(any(), any()))
          .thenAnswer((inv) => inv.positionalArguments[0] as List<Paint>);

      // pool + getAll return some paints (not directly used by generate stub)
      when(() => repo.getAll()).thenAnswer((_) async =>
          List.generate(10, (i) => _FakePaint('pool$i', '#AAAAAA', l: (i*10)%100.toDouble())));
      when(() => repo.getPool(brandIds: any(named: 'brandIds'), theme: any(named: 'theme')))
          .thenAnswer((_) async => List.generate(10, (i) => _FakePaint('pool$i', '#AAAAAA', l: (i*10)%100.toDouble())));
    });

    tearDown(() => container.dispose());

    test('locked positions persist while others change', () async {
      // First roll returns deterministic palette A0..A4 with varied LRVs ensuring extremes
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
            availableBrandOnly: any(named: 'availableBrandOnly'),
          )).thenAnswer((inv) async {
        final anchors = inv.namedArguments[#anchors] as List<Paint?>;
        final anyAnchors = anchors.any((p) => p != null);
        if (!anyAnchors) {
          // initial full roll: provide extremes (<15, >=70) and middles
          return <Paint>[
            _FakePaint('A0', '#111111', l: 5),   // very dark
            _FakePaint('A1', '#222222', l: 20),
            _FakePaint('A2', '#333333', l: 40),
            _FakePaint('A3', '#DDDDDD', l: 80),  // very light
            _FakePaint('A4', '#EEEEEE', l: 90),  // very light
          ];
        } else {
          // reroll with some locked anchors. Replace only unlocked indices with new IDs.
          final out = List<Paint>.generate(5, (i) {
            final anchored = anchors[i];
            if (anchored != null) return anchored; // keep locked
            // produce a different paint id for unlocked to ensure change potential
            return _FakePaint('R$i', '#${(i+1)*111111 % 0xFFFFFF}'.padLeft(6,'0'), l: 30 + i * 5);
          });
          // Guarantee extremes still present: if no dark (<15) among out, force index 1 dark; if no light (>=70), force last light
          final hasDark = out.any((p) => p.computedLrv < 15);
          final hasLight = out.any((p) => p.computedLrv >= 70);
          if (!hasDark) {
            // Replace first unlocked slot (skip locked indices) with a dark paint
            for (var i = 0; i < out.length; i++) {
              if (anchors[i] == null) { out[i] = _FakePaint('RD', '#121212', l: 6); break; }
            }
          }
            if (!hasLight) {
            for (var i = out.length - 1; i >= 0; i--) {
              if (anchors[i] == null) { out[i] = _FakePaint('RL', '#EDEDED', l: 85); break; }
            }
          }
          return out;
        }
      });

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.rollNext();
      final initial = container.read(rollerControllerProvider).value!;
      final firstIds = initial.currentPage!.strips.map((p) => p.id).toList();
      expect(firstIds.length, 5);
      // basic extremes assertion (dark + light present)
      final lVals = initial.currentPage!.strips.map((p) => p.computedLrv).toList();
      final minL = lVals.reduce((a,b)=>a<b?a:b); final maxL = lVals.reduce((a,b)=>a>b?a:b);
      expect(minL < 15, true); expect(maxL >= 70, true);

      // Lock first and third (indices 0 and 2)
      ctrl.toggleLock(0);
      ctrl.toggleLock(2);

      await ctrl.rerollCurrent();
      final after = container.read(rollerControllerProvider).value!;
      final secondIds = after.currentPage!.strips.map((p) => p.id).toList();

      // Locked indices unchanged
      expect(secondIds[0], firstIds[0], reason: 'Locked index 0 should remain same');
      expect(secondIds[2], firstIds[2], reason: 'Locked index 2 should remain same');

      // At least one unlocked index changed
      var changedUnlocked = false;
      for (final i in [1,3,4]) {
        if (secondIds[i] != firstIds[i]) { changedUnlocked = true; break; }
      }
      expect(changedUnlocked, true, reason: 'At least one unlocked position should change on reroll');

      // Ensure size preserved
      expect(secondIds.length, firstIds.length);

      // Recheck extremes still present after reroll
      final lVals2 = after.currentPage!.strips.map((p) => p.computedLrv).toList();
      final minL2 = lVals2.reduce((a,b)=>a<b?a:b); final maxL2 = lVals2.reduce((a,b)=>a>b?a:b);
      expect(minL2 < 15, true, reason: 'Very dark color should persist after reroll');
      expect(maxL2 >= 70, true, reason: 'Very light color should persist after reroll');
    });
  });
}
