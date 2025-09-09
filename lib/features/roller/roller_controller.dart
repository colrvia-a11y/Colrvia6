import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/features/roller/roller_state.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';
import 'package:color_canvas/features/favorites/favorites_repository.dart';
import 'package:color_canvas/services/analytics_service.dart';

final paintRepositoryProvider =
    Provider<PaintRepository>((ref) => PaintRepository());
final paletteServiceProvider =
    Provider<PaletteService>((ref) => PaletteService());

final rollerControllerProvider =
    AsyncNotifierProvider<RollerController, RollerState>(RollerController.new);

class RollerController extends AsyncNotifier<RollerState> {
  late final PaintRepository _repo;
  late final PaletteService _service;
  late final FavoritesRepository _favorites;

  static const bool _enableAlternates = true; // feature flag
  final Map<String, Queue<Paint>> _slotAlternates = {}; // key: pageKey|slot

  String _pageKey(RollerPage p, RollerFilters f, ThemeSpec? t) {
    final ids = p.strips.map((e) => e.id).join('-');
    final brands = (f.brandIds.toList()..sort()).join(',');
    final theme = t?.id ?? 'none';
    return '$ids|$brands|$theme';
  }

  // configurable retention window
  static const int _retainWindow = 50;

  @override
  Future<RollerState> build() async {
    _repo = ref.read(paintRepositoryProvider);
    _service = ref.read(paletteServiceProvider);
    _favorites = FavoritesRepository();
    // eager-load paints so first roll is fast
    await _repo.getAll();
    // seed empty
    return const RollerState(status: RollerStatus.idle);
  }

  void clearError() {
    final s0 = state.valueOrNull ?? const RollerState();
    if (s0.status == RollerStatus.error || s0.error != null) {
      state = AsyncData(s0.copyWith(status: RollerStatus.idle, error: null));
    }
  }

  Future<void> initIfNeeded() async {
    final current = state.valueOrNull;
    if (current == null || current.pages.isEmpty) {
      await rollNext(); // first page
    }
  }

  Future<void> rollNext() async {
    final s0 = state.valueOrNull ?? const RollerState();
    // prevent duplicate work if already generating next page
    final nextIndex = s0.pages.length;
    if (s0.generatingPages.contains(nextIndex)) return;

    state = AsyncData(
      s0.copyWith(
        status: RollerStatus.rolling,
        generatingPages: {...s0.generatingPages, nextIndex},
      ),
    );

    try {
      final pool = await _repo.getPool(
        brandIds: s0.filters.brandIds,
        theme: s0.themeSpec,
      );

      // anchors come from visible page locks if any
      final anchors = List<Paint?>.filled(5, null);
      if (s0.hasPages) {
        final prev = s0.pages.last;
        for (var i = 0; i < prev.strips.length && i < anchors.length; i++) {
          anchors[i] = prev.locks[i] ? prev.strips[i] : null;
        }
      }

      final rolled = await _service.generate(
        available: pool,
        anchors: anchors,
        diversifyBrands: s0.filters.diversifyBrands,
        fixedUndertones: s0.filters.fixedUndertones,
        themeSpec: s0.themeSpec,
      );

      final page = RollerPage(
        strips: rolled,
        locks: List<bool>.filled(rolled.length, false),
      );

      // trim window
      final newPages = [...s0.pages, page];
      final start = (newPages.length > _retainWindow)
          ? newPages.length - _retainWindow
          : 0;
      final trimmed = newPages.sublist(start);

      // maintain visible index if we trimmed
      final newVisible = start > 0 ? (s0.visiblePage - start).clamp(0, trimmed.length - 1) : s0.visiblePage;

      state = AsyncData(
        s0.copyWith(
          pages: trimmed,
          visiblePage: newVisible,
          status: RollerStatus.idle,
          generatingPages: {...s0.generatingPages}..remove(nextIndex),
        ),
      );

      AnalyticsService.instance.logEvent('roll_next', {
        'pageCount': trimmed.length,
        'visible': newVisible,
      });

      // prefetch one ahead
      if (trimmed.length - 1 - newVisible <= 1) {
        // don't await
        _ = rollNext();
      }
    } catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? const RollerState()).copyWith(
          status: RollerStatus.error,
          error: e.toString(),
          generatingPages: {},
        ),
      );
    }
  }

  void onPageChanged(int index) {
    final s0 = state.valueOrNull; if (s0 == null) return;
    state = AsyncData(s0.copyWith(visiblePage: index));
    if (s0.pages.length - 1 - index <= 1) { _ = rollNext(); }
    _ = _primeAlternatesForVisible();
  }

  Future<void> rerollCurrent({int attempts = 4}) async {
    final s0 = state.valueOrNull;
    if (s0 == null || !s0.hasPages) return;
    final idx = s0.visiblePage;
    if (s0.generatingPages.contains(idx)) return;

    state = AsyncData(s0.copyWith(
      generatingPages: {...s0.generatingPages, idx},
      status: RollerStatus.rolling,
    ));

    try {
      final pool = await _repo.getPool(
        brandIds: s0.filters.brandIds,
        theme: s0.themeSpec,
      );
      final current = s0.currentPage!;
      final anchors = <Paint?>[
        for (var i = 0; i < current.strips.length; i++)
          current.locks[i] ? current.strips[i] : null
      ];

      final rolled = await _service.generate(
        available: pool,
        anchors: anchors,
        diversifyBrands: s0.filters.diversifyBrands,
        fixedUndertones: s0.filters.fixedUndertones,
        themeSpec: s0.themeSpec,
        attempts: attempts,
      );

      final nextPage = current.copyWith(strips: rolled);

      final pages = [...s0.pages]..[idx] = nextPage;
      state = AsyncData(s0.copyWith(
        pages: pages,
        status: RollerStatus.idle,
        generatingPages: {...s0.generatingPages}..remove(idx),
      ));

      AnalyticsService.instance.logEvent('reroll_current', {
        'pageIndex': idx,
      });
    } catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? const RollerState()).copyWith(
          status: RollerStatus.error,
          error: e.toString(),
          generatingPages: {},
        ),
      );
    }
  }

  Future<void> rerollStrip(int stripIndex) async {
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return;
    final idx = s0.visiblePage;
    final current = s0.pages[idx];

    final anchors = <Paint?>[
      for (var i = 0; i < current.strips.length; i++)
        i == stripIndex ? null : current.strips[i]
    ];

    state = AsyncData(s0.copyWith(
      generatingPages: {...s0.generatingPages, idx},
      status: RollerStatus.rolling,
    ));

    try {
      final pool = await _repo.getPool(
          brandIds: s0.filters.brandIds, theme: s0.themeSpec);
      final rolled = await _service.generate(
        available: pool,
        anchors: anchors,
        diversifyBrands: s0.filters.diversifyBrands,
        fixedUndertones: s0.filters.fixedUndertones,
        themeSpec: s0.themeSpec,
      );

      final nextStrips = [...current.strips]..[stripIndex] = rolled[stripIndex];
      final pages = [...s0.pages]..[idx] = current.copyWith(strips: nextStrips);

      state = AsyncData(s0.copyWith(
        pages: pages,
        status: RollerStatus.idle,
        generatingPages: {...s0.generatingPages}..remove(idx),
      ));

      AnalyticsService.instance
          .logEvent('reroll_strip', {'strip': stripIndex});
    } catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? const RollerState()).copyWith(
          status: RollerStatus.error,
          error: e.toString(),
          generatingPages: {},
        ),
      );
    }
  }

  Future<void> _primeAlternatesForVisible() async {
    if (!_enableAlternates) return;
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return;
    final page = s0.currentPage!;
    final keyBase = _pageKey(page, s0.filters, s0.themeSpec);
    final pool = await _repo.getPool(brandIds: s0.filters.brandIds, theme: s0.themeSpec);

    // build anchors that mirror the current page (null for unlocked)
    final anchors = <Paint?>[
      for (var i = 0; i < page.strips.length; i++) page.locks[i] ? page.strips[i] : null
    ];

    for (var i = 0; i < page.strips.length; i++) {
      if (page.locks[i]) continue;
      final k = '$keyBase|$i';
      if (_slotAlternates[k]?.isNotEmpty == true) continue;
      final alts = await _service.alternatesForSlot(
        available: pool,
        anchors: anchors,
        slotIndex: i,
        diversifyBrands: s0.filters.diversifyBrands,
        fixedUndertones: s0.filters.fixedUndertones,
        themeSpec: s0.themeSpec,
        targetCount: 5,
      );
      _slotAlternates[k] = Queue.of(alts);
    }
  }

  Future<void> useNextAlternateForStrip(int i) async {
    if (!_enableAlternates) { await rerollStrip(i); return; }
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return;
    final page = s0.currentPage!;
    final key = '${_pageKey(page, s0.filters, s0.themeSpec)}|$i';
    if (!_slotAlternates.containsKey(key) || _slotAlternates[key]!.isEmpty) {
      await _primeAlternatesForVisible();
    }
    if (_slotAlternates[key]?.isEmpty ?? true) { await rerollStrip(i); return; }
    final next = _slotAlternates[key]!.removeFirst();
    final idx = s0.visiblePage;
    final nextStrips = [...page.strips]..[i] = next;
    final pages = [...s0.pages]..[idx] = page.copyWith(strips: nextStrips);
    state = AsyncData(s0.copyWith(pages: pages));
    AnalyticsService.instance
        .logEvent('alternate_applied', {'strip': i});
  }

  void toggleLock(int stripIndex) {
    final s0 = state.valueOrNull;
    if (s0 == null || !s0.hasPages) return;
    final idx = s0.visiblePage;
    final page = s0.pages[idx];
    if (stripIndex < 0 || stripIndex >= page.locks.length) return;
    final newLocks = [...page.locks];
    newLocks[stripIndex] = !newLocks[stripIndex];
    final pages = [...s0.pages]..[idx] = page.copyWith(locks: newLocks);
    state = AsyncData(s0.copyWith(pages: pages));
    AnalyticsService.instance.logEvent(
        'toggle_lock', {'strip': stripIndex, 'locked': newLocks[stripIndex]});
  }

  void unlockAll() {
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return;
    final idx = s0.visiblePage;
    final page = s0.pages[idx];
    final pages = [...s0.pages]..[idx] = page.copyWith(locks: List<bool>.filled(page.locks.length, false));
    state = AsyncData(s0.copyWith(pages: pages));
  }

  Future<void> setFilters(RollerFilters filters) async {
    final s0 = state.valueOrNull ?? const RollerState();
    state = AsyncData(s0.copyWith(filters: filters));
    // kick a reroll for the current + prefetch next
    await rerollCurrent();
  }

  Future<void> setTheme(ThemeSpec? spec) async {
    final s0 = state.valueOrNull ?? const RollerState();
    state = AsyncData(s0.copyWith(themeSpec: spec));
    await rerollCurrent();
  }

  String _currentKey() {
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return '';
    final p = s0.currentPage!;
    return p.strips.map((e) => e.id).join('-');
  }

  List<String> _currentHexes() {
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return const [];
    final p = s0.currentPage!;
    return [
      for (final paint in p.strips)
        (() {
          try {
            final m = paint.toJson();
            final hex = (m['hex'] as String?)?.toUpperCase();
            if (hex != null) return hex.startsWith('#') ? hex : '#$hex';
            final rgb = (m['rgb'] as List?)?.cast<num>();
            if (rgb != null && rgb.length >= 3) {
              int r = rgb[0].toInt().clamp(0, 255);
              int g = rgb[1].toInt().clamp(0, 255);
              int b = rgb[2].toInt().clamp(0, 255);
              String h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
              return '#${h(r)}${h(g)}${h(b)}';
            }
          } catch (_) {}
          return '#000000';
        })(),
    ];
  }

  Future<bool> isCurrentFavorite() async {
    final key = _currentKey();
    if (key.isEmpty) return false;
    return _favorites.isFavorite(key);
  }

  Future<void> toggleFavoriteCurrent() async {
    final s0 = state.valueOrNull; if (s0 == null || !s0.hasPages) return;
    final key = _currentKey();
    final p = s0.currentPage!;
    final item = FavoritePalette(
      key: key,
      paintIds: [for (final e in p.strips) e.id],
      hexes: _currentHexes(),
    );
    await _favorites.toggle(item);
  }

  Future<void> copyCurrentHexesToClipboard() async {
    final hexes = _currentHexes();
    final text = hexes.join(', ');
    await Clipboard.setData(ClipboardData(text: text));
  }
}
