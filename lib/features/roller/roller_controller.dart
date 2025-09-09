import 'dart:collection';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';
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

/// Formats for copying HEX values
enum CopyFormat { comma, newline, labeled }

class RollerController extends AsyncNotifier<RollerState> {
  late final PaintRepository _repo;
  late final PaletteService _service;
  late final FavoritesRepository _favorites;
  int _epoch = 0; // bump to invalidate in-flight rolls on theme changes

  static const bool _enableAlternates = true; // feature flag
  static const int _maxAlternateKeys = 30;
  final Map<String, Queue<Paint>> _slotAlternates = {}; // key: pageKey|slot

  void _evictIfNeeded() {
    // Map in Dart is insertion-ordered (LinkedHashMap), so .keys.first is the oldest.
    while (_slotAlternates.length > _maxAlternateKeys) {
      final firstKey = _slotAlternates.keys.first;
      _slotAlternates.remove(firstKey);
    }
  }

  String _pageKey(RollerPage p, RollerFilters f, ThemeSpec? t) {
    final ids = p.strips.map((e) => e.id).join('-');
    final brands = (f.brandIds.toList()..sort()).join(',');
    final theme = t?.id ?? 'none';
    return '$ids|$brands|$theme';
  }

  // configurable retention window
  static const int _retainWindow = 50;

  // --- LRV helpers ---------------------------------------------------------
  double _lrvOf(Paint p) {
    try {
      final m = p.toJson();
      // Prefer explicit LRV if available
      final explicit = m['lrv'];
      if (explicit is num) {
        final v = explicit.toDouble();
        return v.clamp(0.0, 100.0);
      }

      // Next: CIELAB L* (0..100), but ignore obviously zeroed placeholders
      final lab = (m['lab'] as List?)?.cast<num>();
      if (lab != null && lab.isNotEmpty) {
        final l = lab[0].toDouble();
        final a = lab.length > 1 ? lab[1].toDouble() : 0.0;
        final b = lab.length > 2 ? lab[2].toDouble() : 0.0;
        final looksZeroed = l == 0.0 && a == 0.0 && b == 0.0;
        if (!looksZeroed) return l.clamp(0.0, 100.0);
      }

      // Fallback: parse HEX if present and compute WCAG luminance (Y*100)
      final hex = (m['hex'] as String?)?.toUpperCase();
      if (hex != null && hex.isNotEmpty) {
        List<int>? rgbFromHex() {
          String h = hex.startsWith('#') ? hex.substring(1) : hex;
          if (h.length == 3) {
            h = h.split('').map((c) => '$c$c').join();
          }
          if (h.length != 6) return null;
          final r = int.parse(h.substring(0, 2), radix: 16);
          final g = int.parse(h.substring(2, 4), radix: 16);
          final b = int.parse(h.substring(4, 6), radix: 16);
          return [r, g, b];
        }

        final rgb = rgbFromHex();
        if (rgb != null) {
          double lin(int v) {
            final x = v / 255.0;
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4).toDouble();
          }
          final r = lin(rgb[0]);
          final g = lin(rgb[1]);
          final b = lin(rgb[2]);
          final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          return (y * 100.0).clamp(0.0, 100.0);
        }
      }

      // Last resort: use provided RGB if available
      final rgb = (m['rgb'] as List?)?.cast<num>();
      if (rgb != null && rgb.length >= 3) {
        double lin(num v) {
          final x = v.toDouble() / 255.0;
          return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4).toDouble();
        }
        final r = lin(rgb[0]);
        final g = lin(rgb[1]);
        final b = lin(rgb[2]);
        final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        return (y * 100.0).clamp(0.0, 100.0);
      }
    } catch (_) {}
    return 0.0;
  }

  List<Paint> _sortByLrvDesc(List<Paint> paints) {
    final list = [...paints];
    list.sort((a, b) => _lrvOf(b).compareTo(_lrvOf(a)));
    return list;
  }

  @override
  Future<RollerState> build() async {
    _repo = ref.read(paintRepositoryProvider);
    _service = ref.read(paletteServiceProvider);
    _favorites = FavoritesRepository();
  // ensure themes are available for UI and generation
  await ThemeService.instance.loadFromAssetIfNeeded();
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
  final startEpoch = _epoch;
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
      final sw = Stopwatch()..start();
      final pool = await _repo.getPool(
        brandIds: s0.filters.brandIds,
        theme: s0.themeSpec,
      );
      // brand-only pool for auto-relax fallback
      final brandOnly = _repo.filterByBrands(
        await _repo.getAll(),
        s0.filters.brandIds,
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
        availableBrandOnly: brandOnly,
      );

      // Sort only if we didn’t anchor any slot (no locks active)
      final noLocks = anchors.every((e) => e == null);
      final paints = noLocks ? _sortByLrvDesc(rolled) : rolled;

      final page = RollerPage(
        strips: paints,
        locks: List<bool>.filled(paints.length, false),
      );

      // trim window
      final newPages = [...s0.pages, page];
      final start = (newPages.length > _retainWindow)
          ? newPages.length - _retainWindow
          : 0;
      final trimmed = newPages.sublist(start);

      // maintain visible index if we trimmed
      final newVisible = start > 0 ? (s0.visiblePage - start).clamp(0, trimmed.length - 1) : s0.visiblePage;

      // Abort if theme changed mid-flight
      if (startEpoch != _epoch) return;
      state = AsyncData(s0.copyWith(
        pages: trimmed,
        visiblePage: newVisible,
        status: RollerStatus.idle,
        generatingPages: {...s0.generatingPages}..remove(nextIndex),
      ));

      sw.stop();
      final poolSize = pool.length;
      final brandCount = s0.filters.brandIds.length;
      final themeId = s0.themeSpec?.id ?? 'none';
      final lockedCount = s0.hasPages
          ? (s0.pages.last.locks.where((l) => l).length)
          : 0;
      AnalyticsService.instance.logEvent('roll_next', {
        'pageCount': trimmed.length,
        'visible': newVisible,
        'elapsedMs': sw.elapsedMilliseconds,
        'poolSize': poolSize,
        'brandCount': brandCount,
        'themeId': themeId,
        'lockedCount': lockedCount,
      });
      debugPrint('roll_next: ${sw.elapsedMilliseconds}ms pool=$poolSize brands=$brandCount theme=$themeId locked=$lockedCount');

  // (re)prime alternates after a successful roll - don't await
  _primeAlternatesForVisible();

      // prefetch one ahead
      if (trimmed.length - 1 - newVisible <= 1) {
        // don't await
        rollNext();
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
    if (s0.pages.length - 1 - index <= 1) { rollNext(); }
    _primeAlternatesForVisible();
  }

  Future<void> rerollCurrent({int attempts = 4}) async {
  final startEpoch = _epoch;
    final s0 = state.valueOrNull;
    if (s0 == null || !s0.hasPages) return;
    final idx = s0.visiblePage;
    if (s0.generatingPages.contains(idx)) return;

    state = AsyncData(s0.copyWith(
      generatingPages: {...s0.generatingPages, idx},
      status: RollerStatus.rolling,
    ));

    try {
      final sw = Stopwatch()..start();
      final pool = await _repo.getPool(
        brandIds: s0.filters.brandIds,
        theme: s0.themeSpec,
      );
      final brandOnly = _repo.filterByBrands(
        await _repo.getAll(),
        s0.filters.brandIds,
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
        availableBrandOnly: brandOnly,
        attempts: attempts,
      );

  // Sort only when page has zero locks
  final hasAnyLock = current.locks.any((l) => l);
  final sorted = hasAnyLock ? rolled : _sortByLrvDesc(rolled);

  final nextPage = current.copyWith(strips: sorted);

      final pages = [...s0.pages]..[idx] = nextPage;
      // Abort if theme changed mid-flight
      if (startEpoch != _epoch) return;
      state = AsyncData(s0.copyWith(
        pages: pages,
        status: RollerStatus.idle,
        generatingPages: {...s0.generatingPages}..remove(idx),
      ));

      sw.stop();
      final poolSize = pool.length;
      final brandCount = s0.filters.brandIds.length;
      final themeId = s0.themeSpec?.id ?? 'none';
      final lockedCount = s0.currentPage!.locks.where((l) => l).length;
      AnalyticsService.instance.logEvent('reroll_current', {
        'pageIndex': idx,
        'elapsedMs': sw.elapsedMilliseconds,
        'poolSize': poolSize,
        'brandCount': brandCount,
        'themeId': themeId,
        'lockedCount': lockedCount,
      });
      debugPrint('reroll_current: idx=$idx ${sw.elapsedMilliseconds}ms pool=$poolSize brands=$brandCount theme=$themeId locked=$lockedCount');
  // (re)prime alternates after a successful reroll - don't await
  _primeAlternatesForVisible();
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
      final sw = Stopwatch()..start();
      final pool = await _repo.getPool(
          brandIds: s0.filters.brandIds, theme: s0.themeSpec);
      final brandOnly = _repo.filterByBrands(
        await _repo.getAll(),
        s0.filters.brandIds,
      );
      final rolled = await _service.generate(
        available: pool,
        anchors: anchors,
        diversifyBrands: s0.filters.diversifyBrands,
        fixedUndertones: s0.filters.fixedUndertones,
        themeSpec: s0.themeSpec,
        availableBrandOnly: brandOnly,
      );

      final nextStrips = [...current.strips]..[stripIndex] = rolled[stripIndex];
      final pages = [...s0.pages]..[idx] = current.copyWith(strips: nextStrips);

      state = AsyncData(s0.copyWith(
        pages: pages,
        status: RollerStatus.idle,
        generatingPages: {...s0.generatingPages}..remove(idx),
      ));

      sw.stop();
      final poolSize = pool.length;
      final brandCount = s0.filters.brandIds.length;
      final themeId = s0.themeSpec?.id ?? 'none';
      final lockedCount = current.locks.where((l) => l).length;
      AnalyticsService.instance
          .logEvent('reroll_strip', {
        'strip': stripIndex,
        'elapsedMs': sw.elapsedMilliseconds,
        'poolSize': poolSize,
        'brandCount': brandCount,
        'themeId': themeId,
        'lockedCount': lockedCount,
      });
      debugPrint('reroll_strip: idx=$idx strip=$stripIndex ${sw.elapsedMilliseconds}ms pool=$poolSize brands=$brandCount theme=$themeId locked=$lockedCount');
  // subtle haptic feedback to indicate a successful reroll
  await HapticFeedback.lightImpact();
  // (re)prime alternates after a successful reroll - don't await
  _primeAlternatesForVisible();
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
  _evictIfNeeded();
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
  // subtle haptic feedback to indicate an alternate was applied
  await HapticFeedback.lightImpact();
  // after applying an alternate, prefetch alternates for the visible page (don't await)
  _primeAlternatesForVisible();
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
  // provide a small selection click to acknowledge the lock toggle
  HapticFeedback.selectionClick();
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

  // New: set theme by id, resetting feed and triggering new roll
  Future<void> setThemeById(String? id) async {
    final current = state.valueOrNull ?? const RollerState();
    final currentId = current.themeSpec?.id;
    final nextKey = (id ?? 'all');
    final currKey = (currentId ?? 'all');
    if (nextKey == currKey) return; // no-op

    // Resolve spec (null for 'all')
    final spec = (id == null || id == 'all')
        ? null
        : ThemeService.instance.byId(id);

    // Reset pages and status; clear alternates
  _epoch++;
    _slotAlternates.clear();
    state = AsyncData(current.copyWith(
      pages: const [],
      visiblePage: 0,
      themeSpec: spec,
      status: RollerStatus.idle,
      generatingPages: {},
      error: null,
    ));

    // Prewarm pool (brands + theme), then roll first page
    await _repo.getPool(brandIds: current.filters.brandIds, theme: spec);
    await rollNext();
    AnalyticsService.instance
        .logEvent('theme_selected', {'themeId': spec?.id ?? 'all'});
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

  Future<void> copyCurrentHexesToClipboard(CopyFormat format) async {
    final s0 = state.valueOrNull;
    if (s0 == null || !s0.hasPages) return;

    final page = s0.currentPage!;

    String text;
    switch (format) {
      case CopyFormat.comma:
        text = page.strips.map((p) => p.hex.toUpperCase()).join(', ');
        break;
      case CopyFormat.newline:
        text = page.strips.map((p) => p.hex.toUpperCase()).join('\n');
        break;
      case CopyFormat.labeled:
        // Example: Sherwin-Williams · Alabaster (SW 7008) — #FAF6F0
        text = page.strips.map((p) {
          final brand = p.brandName.trim();
          final name = p.name.trim();
          final code = p.code.toString().trim();
          final hex = p.hex.toUpperCase();
          final brandPart = brand.isNotEmpty ? brand : 'Unknown';
          final namePart = name.isNotEmpty ? name : 'Unnamed';
          final codePart = code.isNotEmpty ? ' ($code)' : '';
          return '$brandPart \u00B7 $namePart$codePart \u2014 $hex';
        }).join('\n');
        break;
    }

    await Clipboard.setData(ClipboardData(text: text));
    // subtle haptic to confirm copy action
    await HapticFeedback.selectionClick();
  }
}
