// lib/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'paint_detail_screen.dart';
import 'package:color_canvas/screens/compare_colors_screen.dart';
import 'package:color_canvas/screens/home_screen.dart';
import '../models/color_filters.dart';
import '../services/paint_query_service.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/fancy_paint_tile.dart';
import '../widgets/explore_rail.dart';
import '../widgets/compare_tray.dart';
import '../widgets/staggered_entrance.dart';

import '../widgets/shimmer.dart';
import '../data/explore_rails_config.dart';

// Shared tile geometry (keep cards consistent across tabs)
const double kTileAspect = 0.72;      // width / height (≈ All tab’s look)
const double kTileSpacing = 12.0;     // gap between tiles
const double kScreenPaddingH = 16.0;  // page horizontal padding

class SearchScreen extends StatefulWidget {
  final Function(Paint)? onPaintSelectedForRoller;
  const SearchScreen({super.key, this.onPaintSelectedForRoller});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _gridController = ScrollController();

  Timer? _debounceTimer;
  bool _showClearButton = false;
  bool _showSearchResults = false;
  bool _isSearching = false;
  bool _showToTop = false;
  int _page = 0;
  static const int _pageSize = 40;
  List<Paint> _cached = [];
  List<Paint> _visible = [];

  // Compare selection
  final Set<String> _selectedForCompare = {};
  final Map<String, Paint> _byId = {};

  bool get _compareTrayVisible => _selectedForCompare.isNotEmpty;
  List<Paint> get _selectedPaintsList =>
      _selectedForCompare.map((id) => _byId[id]).whereType<Paint>().toList();

  // Tabs
  int _tabIndex = 0; // 0 Explore, 1 All Colors, 2 Rooms&Combos, 3 Brands

  // Dense grid
  bool _denseGrid = false;

  // Filters (for All Colors)
  ColorFilters filters = ColorFilters();
  PaintSort sort = PaintSort.relevance;

  // Collapsing search (tabs stay visible)
  bool _hideSearch = false;

  // Suggestions

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _gridController.addListener(_onGridScroll);
    // 🔆 glow hook: rebuild when focus changes
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _gridController.removeListener(_onGridScroll);
    _gridController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _showClearButton = _searchController.text.isNotEmpty);
  }



  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
    final f = FocusManager.instance.primaryFocus;
    f?.unfocus();
  }

  void _onGridScroll() {
    if (_gridController.offset > 800 && !_showToTop) {
      setState(() => _showToTop = true);
    }
    if (_gridController.offset <= 800 && _showToTop) {
      setState(() => _showToTop = false);
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }



  void _loadMore() {
    if ((_page + 1) * _pageSize >= _cached.length) {
      return;
    }
    setState(() {
      _page++;
      _visible.addAll(_cached.skip(_page * _pageSize).take(_pageSize));
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) {
      return;
    }
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _showSearchResults = false;
        _visible = [];
        _cached = [];
        _page = 0;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    try {
      final results = await PaintQueryService.instance.textSearch(query, limit: 200);
      _cached = results;
      _page = 0;
      _visible = _cached.take(_pageSize).toList();
      setState(() => _isSearching = false);
      AnalyticsService.instance.logEvent('search_performed', {'q': query, 'count': results.length});
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
    }
  }

  void _openDetails(Paint p) {
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaintDetailScreen(paint: p)),
    );
  }


  void _toggleCompare(Paint p) {
    setState(() {
      if (_selectedForCompare.contains(p.id)) {
        _selectedForCompare.remove(p.id);
      } else if (_selectedForCompare.length < 4) {
        _selectedForCompare.add(p.id);
        _byId[p.id] = p;
      }
    });
  }

  void _loadIntoRoller(Paint p) {
    if (widget.onPaintSelectedForRoller != null) {
      widget.onPaintSelectedForRoller!(p);
      return;
    }
    final home = context.findAncestorStateOfType<HomeScreenState>();
    if (home != null) {
      home.onPaintSelectedFromSearch(p);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load ${p.name} into Roller.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // main column
            Column(
              children: [
                _topBar(theme),
                Expanded(
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (n) {
                      final dy = n.scrollDelta ?? 0.0;
                      // small deadzone so tiny jitters don’t flip the header
                      const threshold = 6.0;

                      if (dy > threshold && !_hideSearch) {
                        setState(() => _hideSearch = true);   // scrolling down → hide search
                      } else if (dy < -threshold && _hideSearch) {
                        setState(() => _hideSearch = false);  // scrolling up → show search
                      }
                      return false; // don’t stop the notification
                    },
                    child: _showSearchResults
                        ? _buildSearchResults()
                        : _buildBodyForTab(),
                  ),
                ),
              ],
            ),

            
            // compare tray
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: CompareTray.height,
                child: ClipRect(
                  child: AnimatedAlign(
                    alignment: _compareTrayVisible
                        ? Alignment.bottomCenter
                        : const Alignment(0, 2.0), // push just below the viewport
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_compareTrayVisible,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _compareTrayVisible ? 1 : 0,
                        child: CompareTray(
                          items: _selectedPaintsList,
                          onRemoveOne: (p) => setState(() {
                            _selectedForCompare.remove(p.id);
                          }),
                          onClear: () => setState(() {
                            _selectedForCompare.clear();
                          }),
                          onCompare: () {
                            AnalyticsService.instance
                                .logEvent('compare_opened', {
                              'count': _selectedForCompare.length
                            });
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CompareColorsScreen(
                                  paletteColorIds:
                                      _selectedForCompare.toList(),
                                ),
                              ),
                            );
                          },
                          onTapPaint: _openDetails,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
// back-to-top pill: conditionally render (no transforms, no ignore)
            if (_showToTop)
              Positioned(
                right: 16,
                bottom: (_compareTrayVisible ? CompareTray.height + 24 : 24) + 12,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    heroTag: 'toTop',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      if (_tabIndex == 1) {
                        _gridController.animateTo(0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic);
                      } else {
                        _scrollController.animateTo(0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic);
                      }
                    },
                    elevation: 3,
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyForTab() {
    switch (_tabIndex) {
      case 0: return _buildExplore();
      case 1: return _buildAllColors();
      case 2: return _buildRoomsCombos();
      case 3: return _buildBrands();
      default: return const SizedBox.shrink();
    }
  }

  // ---------- Explore ----------
  Widget _buildExplore() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(bottom: 24 + kBottomNavigationBarHeight + (_compareTrayVisible ? CompareTray.height + 12 : 0) + bottomInset),
      children: [
        const SizedBox(height: 6),
        ...kDefaultExploreRails.map((c) {
          return ExploreRail(
            title: c.title,
            colorFamily: c.colorFamily,
            undertone: c.undertone,
            temperature: c.temperature,
            lrvRange: c.lrvRange,
            onSelect: _openDetails,
            onLongPress: _toggleCompare,
            onSeeAll: ({colorFamily, undertone, temperature, lrvRange}) {
              setState(() {
                if (colorFamily != null) { filters = filters.copyWith(colorFamily: colorFamily); }
                if (undertone  != null) { filters = filters.copyWith(undertone: undertone); }
                if (temperature != null) { filters = filters.copyWith(temperature: temperature); }
                if (lrvRange   != null) { filters = filters.copyWith(lrvRange: lrvRange); }
                _tabIndex = 1; // jump to All Colors
              });
            },
            tileAspect: kTileAspect,
            horizontalPadding: kScreenPaddingH,
            tileSpacing: kTileSpacing,
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- All Colors (grid + filters) ----------
  Widget _buildAllColors() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return FutureBuilder<List<Paint>>(
      future: PaintQueryService.instance.getAllPaints(hardLimit: 1600),
      builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return ShimmerGrid(
          crossAxisCount: 2,
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(1.0) > 1.1 ? 232 : 220,
          padding: EdgeInsets.fromLTRB(
            16, 8, 16,
            24 + (_compareTrayVisible ? CompareTray.height + 12 : 0) + bottomInset,
          ),
        );
      }
        var list = snapshot.data!;
        list = PaintQueryService.instance.applyFilters(
          list,
          colorFamily: filters.colorFamily,
          undertone: filters.undertone,
          temperature: filters.temperature,
          lrvRange: filters.lrvRange,
          brandName: filters.brandName,
        );
        list = PaintQueryService.instance.sortList(list, sort);
        return Column(
          children: [
            _filterSortBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _denseGrid ? 3 : 2;
                  final usableW = constraints.maxWidth - (kScreenPaddingH * 2);
                  final tileW = (usableW - (cols - 1) * kTileSpacing) / cols;
                  final tileH = tileW / kTileAspect;

                  return Scrollbar(
                    thumbVisibility: true,
                    controller: _gridController,
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      controller: _gridController,
                      padding: EdgeInsets.fromLTRB(
                        kScreenPaddingH, 8, kScreenPaddingH,
                        24 + kBottomNavigationBarHeight + (_compareTrayVisible ? CompareTray.height + 12 : 0) + bottomInset,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: kTileSpacing,
                        mainAxisSpacing: kTileSpacing,
                        mainAxisExtent: tileH, // height from shared aspect
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        _byId[p.id] = p;
                        final selected = _selectedForCompare.contains(p.id);
                        return StaggeredEntrance(
                          delay: Duration(milliseconds: 40 + (i ~/ cols) * 70 + (i % cols) * 50),
                          child: FancyPaintTile(
                            paint: p,
                            dense: false, // set dense=false so Explore and All look identical
                            selected: selected,
                            onOpen: () => _openDetails(p),
                            onLongPress: () => _toggleCompare(p),
                            onQuickRoller: () => _loadIntoRoller(p),
                          ),
                        );
                      },
                     ),
                   );
                 },
               ),
             ),
           ],
         );
      },
    );
  }

  Widget _filterSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha(12))),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.6,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  builder: (context, controller) => SingleChildScrollView(
                    controller: controller,
                    child: FilterSheet(
                      initial: filters,
                      onApply: (f) => setState(() => filters = f),
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.tune),
            label: const Text('Filters'),
          ),
          const SizedBox(width: 8),
      PopupMenuButton<PaintSort>(
        onSelected: (s) => setState(() => sort = s),
        itemBuilder: (_) => const [
          PopupMenuItem(value: PaintSort.relevance, child: Text('Sort: Relevance')),
          PopupMenuItem(value: PaintSort.hue, child: Text('Sort: Hue')),
          PopupMenuItem(value: PaintSort.lrvAsc, child: Text('Sort: LRV ↑')),
          PopupMenuItem(value: PaintSort.lrvDesc, child: Text('Sort: LRV ↓')),
        ],
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.sort),
          label: Text(_sortLabel(sort)),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: _denseGrid ? 'Comfort grid' : 'Dense grid',
        child: IconButton.filledTonal(
          onPressed: () => setState(() => _denseGrid = !_denseGrid),
          icon: Icon(_denseGrid ? Icons.grid_view_rounded : Icons.grid_on_rounded),
        ),
      ),
      const Spacer(),
          if (_selectedForCompare.isNotEmpty) Text('${_selectedForCompare.length} selected'),
        ],
      ),
    );
  }

  String _sortLabel(PaintSort s) {
    switch (s) {
      case PaintSort.hue: return 'Hue';
      case PaintSort.lrvAsc: return 'LRV ↑';
      case PaintSort.lrvDesc: return 'LRV ↓';
      case PaintSort.newest: return 'Newest';
      case PaintSort.mostSaved: return 'Most saved';
      default: return 'Relevance';
    }
  }

  // ---------- Rooms & Combos (placeholder v1) ----------
  Widget _buildRoomsCombos() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final cards = [
      _roomCard('Bedroom Starter Packs', Icons.bed, 'Warm Bedroom Neutrals', 'High-Contrast Retreat', 'Calming Blue-Greens'),
      _roomCard('Kitchen Combinations', Icons.kitchen, 'Classic White + Soft Black', 'Greige + Brass Friendly', 'Fresh Coastal'),
      _roomCard('Exterior Winners', Icons.house, 'Light + Charcoal Trim', 'Moody Modern', 'Warm Cream + Slate'),
    ];
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        24 + (_compareTrayVisible ? CompareTray.height + 12 : 0) + bottomInset,
      ),
      itemBuilder: (_, i) => cards[i],
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: cards.length,
    );
  }

  Widget _roomCard(String title, IconData icon, String a, String b, String c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _miniPalette('• $a'),
                _miniPalette('• $b'),
                _miniPalette('• $c'),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon: curated combos'))); }, icon: const Icon(Icons.chevron_right), label: const Text('Explore')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPalette(String label) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toneBox(Colors.black12),
          _toneBox(Colors.black26),
          _toneBox(Colors.black38),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 2)),
        ],
      ),
    );
  }

  Widget _toneBox(Color c) => Container(
    width: 20, height: 20, margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
  );

  // ---------- Brands (placeholder) ----------
  Widget _buildBrands() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final brands = ['Sherwin-Williams','Benjamin Moore','Behr'];
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: 24 + (_compareTrayVisible ? CompareTray.height + 12 : 0) + bottomInset,
      ),
      itemCount: brands.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.factory_outlined),
        title: Text(brands[i]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          setState(() { filters = filters.copyWith(brandName: brands[i]); _tabIndex = 1; });
        },
      ),
    );
  }

  // ---------- Search Results ----------
  Widget _buildSearchResults() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    if (_isSearching) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 10), Text('Searching…')],
      ));
    }
    if (_visible.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.onSurface.withAlpha(45)),
          const SizedBox(height: 8),
          Text('No results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Try different keywords', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(65))),
        ],
      ));
    }
    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          24 + kBottomNavigationBarHeight + (_compareTrayVisible ? CompareTray.height + 12 : 0) + bottomInset,
        ),
        itemCount: _visible.length,
        itemBuilder: (_, i) {
          final p = _visible[i];
          _byId[p.id] = p;
          final selected = _selectedForCompare.contains(p.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaggeredEntrance(
              delay: Duration(milliseconds: 30 + i * 45),
              child: AspectRatio(
                aspectRatio: kTileAspect,
                child: FancyPaintTile(
                  paint: p,
                  dense: false,
                  selected: selected,
                  onOpen: () => _openDetails(p),
                  onLongPress: () => _toggleCompare(p),
                  onQuickRoller: () => _loadIntoRoller(p),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6), // tighter overall
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(10),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsible search only
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: Offstage(
              offstage: _hideSearch,
              child: _miniSearch(theme),
            ),
          ),
          if (!_hideSearch) const SizedBox(height: 6), // tighter gap under search
          _minimalTabs(theme),
        ],
      ),
    );
  }

  Widget _miniSearch(ThemeData theme) {
    return SizedBox(
      height: 40, // smaller height to save vertical space
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: _performSearch,
        onChanged: (v) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 350), () => _performSearch(v));
        },
        decoration: InputDecoration(
          hintText: 'Search colors…',
          prefixIcon: const Icon(Icons.search, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _showClearButton
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _showSearchResults = false;
                      _visible.clear();
                      _cached.clear();
                    });
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _minimalTabs(ThemeData theme) {
    // “Explore  All  Rooms  Brands” — one line, compact, no scroll.
    final labels = const ['Explore', 'All', 'Rooms', 'Brands'];
    final sel = _tabIndex;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // tighter horizontally
      children: List.generate(labels.length, (i) {
        final isSel = i == sel;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() {
              _tabIndex = i;
              _hideSearch = false; // reveal when switching tabs
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // smaller padding
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // unselected: no border/fill
                // selected: tasteful oval outline
                border: isSel
                    ? Border.all(
                        color: theme.colorScheme.primary.withAlpha(45),
                        width: 1.1,
                      )
                    : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // smaller, closer typography
                style: theme.textTheme.labelMedium?.copyWith( // smaller than labelLarge
                  fontSize: 12.0,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.15,
                  color: isSel
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(78),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

