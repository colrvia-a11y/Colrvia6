import 'package:flutter/foundation.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/roller_theme/theme_spec.dart';

/// A single "page" in the Roller feed.
@immutable
class RollerPage {
  final List<Paint> strips;         // 5 paints, typically
  final List<bool> locks;           // which strips are locked
  final DateTime createdAt;

  const RollerPage({
    required this.strips,
    required this.locks,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  RollerPage copyWith({
    List<Paint>? strips,
    List<bool>? locks,
  }) => RollerPage(
    strips: strips ?? this.strips,
    locks: locks ?? this.locks,
    createdAt: createdAt,
  );
}

@immutable
class RollerFilters {
  final Set<String> brandIds;         // IDs from Brand.id
  final bool diversifyBrands;         // strategy toggle
  final List<String>? fixedUndertones; // optional undertone constraints

  const RollerFilters({
    this.brandIds = const {},
    this.diversifyBrands = true,
    this.fixedUndertones,
  });

  RollerFilters copyWith({
    Set<String>? brandIds,
    bool? diversifyBrands,
    List<String>? fixedUndertones,
  }) => RollerFilters(
    brandIds: brandIds ?? this.brandIds,
    diversifyBrands: diversifyBrands ?? this.diversifyBrands,
    fixedUndertones: fixedUndertones ?? this.fixedUndertones,
  );

  @override
  String toString() => 'RollerFilters(brandIds: $brandIds, diversify: $diversifyBrands, fixed: $fixedUndertones)';
}

enum RollerStatus { idle, loading, rolling, error }

@immutable
class RollerState {
  final List<RollerPage> pages;
  final int visiblePage;
  final RollerFilters filters;
  final ThemeSpec? themeSpec;
  final RollerStatus status;
  final Set<int> generatingPages; // indices currently generating
  final String? error;

  const RollerState({
    this.pages = const [],
    this.visiblePage = 0,
    this.filters = const RollerFilters(),
    this.themeSpec,
    this.status = RollerStatus.idle,
    this.generatingPages = const {},
    this.error,
  });

  bool get hasPages => pages.isNotEmpty;
  RollerPage? get currentPage => hasPages && visiblePage < pages.length ? pages[visiblePage] : null;

  RollerState copyWith({
    List<RollerPage>? pages,
    int? visiblePage,
    RollerFilters? filters,
    ThemeSpec? themeSpec,
    RollerStatus? status,
    Set<int>? generatingPages,
    String? error,
  }) => RollerState(
    pages: pages ?? this.pages,
    visiblePage: visiblePage ?? this.visiblePage,
    filters: filters ?? this.filters,
    themeSpec: themeSpec ?? this.themeSpec,
    status: status ?? this.status,
    generatingPages: generatingPages ?? this.generatingPages,
    error: error,
  );
}
