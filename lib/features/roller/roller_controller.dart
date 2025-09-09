import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/features/roller/roller_state.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';

final rollerControllerProvider =
    AsyncNotifierProvider<RollerController, RollerState>(RollerController.new);

class RollerController extends AsyncNotifier<RollerState> {
  late final PaintRepository _repo;
  late final PaletteService _service;

  // configurable retention window
  static const int _retainWindow = 50;

  @override
  Future<RollerState> build() async {
    _repo = PaintRepository();
    _service = PaletteService();
    // eager-load paints so first roll is fast
    await _repo.getAll();
    // seed empty
    return const RollerState(status: RollerStatus.idle);
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
      final all = await _repo.getAll();
      final pool = _repo.filterByBrands(all, s0.filters.brandIds);

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
    final s0 = state.valueOrNull;
    if (s0 == null) return;
    state = AsyncData(s0.copyWith(visiblePage: index));
    // opportunistically prefetch
    if (s0.pages.length - 1 - index <= 1) {
      _ = rollNext();
    }
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

    final all = await _repo.getAll();
    final pool = _repo.filterByBrands(all, s0.filters.brandIds);
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
}
