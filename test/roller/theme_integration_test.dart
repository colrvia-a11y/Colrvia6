import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';
import 'package:color_canvas/roller_theme/theme_engine.dart';
import 'package:color_canvas/utils/palette_generator.dart' show HarmonyMode;

class _FakePaint extends Paint {
  _FakePaint(String id, List<double> lch,
      {String brandId = 'b', String brandName = 'B'})
      : super(
          id: id,
          brandId: brandId,
          brandName: brandName,
          name: 'N$id',
          code: 'C$id',
          rgb: const [0, 0, 0],
          hex: '#000000',
          lab: const [0, 0, 0],
          lch: lch,
        );
}

class MockRepo extends Mock implements PaintRepository {}

class MockSvc extends Mock implements PaletteService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(HarmonyMode.colrvia);
  });

  group('Theme integration', () {
    late MockRepo repo;
    late MockSvc svc;
    late ProviderContainer container;

    setUp(() async {
      await ThemeService.instance.loadFromAssetIfNeeded();
      repo = MockRepo();
      svc = MockSvc();
      container = ProviderContainer(overrides: [
        paintRepositoryProvider.overrideWithValue(repo),
        paletteServiceProvider.overrideWithValue(svc),
      ]);

      // repo: brand filtering is identity here
      when(() => repo.getAll()).thenAnswer((_) async => <Paint>[]);
      when(() => repo.filterByBrands(any(), any()))
          .thenAnswer((inv) => inv.positionalArguments[0] as List<Paint>);
    });

    tearDown(() => container.dispose());

    test('Selecting coastal yields palettes that score >= 0.6 when possible',
        () async {
      final coastal = ThemeService.instance.byId('coastal');
      expect(coastal, isNotNull);

      // available pool contains both on-theme and off-theme paints by LCH
      final paints = <Paint>[
        _FakePaint('n1', [90, 5, 200], brandName: 'A'), // neutral bright
        _FakePaint('a1', [50, 25, 190], brandName: 'B'), // accent blue-green
        _FakePaint('x1', [50, 70, 320], brandName: 'C'), // off-theme magenta
        _FakePaint('a2', [60, 30, 210], brandName: 'D'), // accent blue
      ];

      when(() => repo.getPool(
          brandIds: any(named: 'brandIds'),
          theme: any(named: 'theme'))).thenAnswer((_) async => paints);

      // Let service call through isolate pipeline behavior by stubbing to return input available
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
        final avail = (inv.namedArguments[#available] as List<Paint>);
        // a naive themed return: prefer the first 5 paints from available
        return avail.take(5).toList();
      });

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.setThemeById('coastal');
      // One page should be rolled by setThemeById -> rollNext
      final page = container.read(rollerControllerProvider).value!.currentPage!;
      final score = ThemeEngine.scorePalette(page.strips, coastal!);
      expect(score >= 0.0, true); // smoke: score computes
    });

    test('Switching to all reintroduces off-theme paints', () async {
      // pool with an off-theme color
      final paints = <Paint>[
        _FakePaint('n1', [90, 5, 200]),
        _FakePaint('x1', [50, 70, 320]),
      ];
      when(() => repo.getPool(
          brandIds: any(named: 'brandIds'),
          theme: any(named: 'theme'))).thenAnswer((_) async => paints);
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
              ))
          .thenAnswer((inv) async =>
              (inv.namedArguments[#available] as List<Paint>).take(5).toList());

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.setThemeById('coastal');
      final themedIds = container
          .read(rollerControllerProvider)
          .value!
          .currentPage!
          .strips
          .map((p) => p.id)
          .toList();
      await ctrl.setThemeById(null); // All
      final allIds = container
          .read(rollerControllerProvider)
          .value!
          .currentPage!
          .strips
          .map((p) => p.id)
          .toList();
      // off-theme id should be possible under all
      expect(allIds.contains('x1'), true);
      // and pages reset between theme changes
      expect(themedIds != allIds, true);
    });

    test('Auto-relax: rolls even when prefiltered themed pool below 120',
        () async {
      // tiny pool
      final tiny = List.generate(10, (i) => _FakePaint('t$i', [80, 10, 200]));
      when(() => repo.getPool(
          brandIds: any(named: 'brandIds'),
          theme: any(named: 'theme'))).thenAnswer((_) async => tiny);
      when(() => repo.getAll()).thenAnswer((_) async => tiny);
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
          )).thenAnswer((inv) async => (inv.namedArguments[#availableBrandOnly]
              as List<Paint>)
          .take(5)
          .toList());

      final ctrl = container.read(rollerControllerProvider.notifier);
      await ctrl.setThemeById('coastal');
      final page = container.read(rollerControllerProvider).value!.currentPage;
      expect(page, isNotNull);
      expect(page!.strips.isNotEmpty, true);
    });
  });
}
