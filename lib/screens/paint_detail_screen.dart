import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/color_service.dart';
import 'package:color_canvas/services/library_service.dart';

import 'roller_screen.dart';
import 'visualizer_screen.dart';

import 'package:color_canvas/data/sample_paints.dart';
import 'package:color_canvas/widgets/stacked_chip_card.dart';
import 'package:color_canvas/widgets/app_icon_button.dart';
import 'package:color_canvas/widgets/color_swatch_card.dart';

// ===== Enums for view options (kept simple/optional) =====
enum LightingMode { d65, incandescent, north }
enum CbMode { none, deuter, protan, tritan }

// ===== Main Screen =====
class PaintDetailScreen extends StatefulWidget {
  final Paint paint;
  const PaintDetailScreen({super.key, required this.paint});

  @override
  State<PaintDetailScreen> createState() => _PaintDetailScreenState();
}

class _PaintDetailScreenState extends State<PaintDetailScreen> {
  LightingMode lighting = LightingMode.d65;
  CbMode cb = CbMode.none;

  bool _isFavorite = false;
  bool _favBusy = false;

  Color? _resolvedBase;

  bool _hasValidHex(String? hex) {
    if (hex == null || hex.isEmpty) return false;
    final h = hex.startsWith('#') ? hex : '#$hex';
    if (h.toUpperCase() == '#000000') return false; // avoid pure black header
    final re = RegExp(r'^#([0-9A-Fa-f]{6})$');
    return re.hasMatch(h);
  }

  Color get _base {
    if (_resolvedBase != null) return _resolvedBase!;
    if (_hasValidHex(widget.paint.hex)) {
      return ColorUtils.getPaintColor(widget.paint.hex);
    }
    return Colors.grey.shade200;
  }

  Color get _display => _base; // keep hero as raw paint color

  @override
  void initState() {
    super.initState();
    _loadFavorite();

    // Resolve via ColorService only if incoming hex missing/invalid
    if (!_hasValidHex(widget.paint.hex)) {
      ColorService.getColorFromId(widget.paint.id).then((c) {
        if (!mounted) return;
        setState(() => _resolvedBase = c);
      }).catchError((_) {});
    }
  }

  Future<void> _loadFavorite() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    try {
      final fav = await FirebaseService.isPaintFavorited(widget.paint.id, user.uid);
      if (!mounted) return;
      setState(() => _isFavorite = fav);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to save favorites')),
        );
      }
      return;
    }
    setState(() => _favBusy = true);
    try {
      if (_isFavorite) {
        await LibraryService.removeColor(widget.paint.id);
        if (mounted) {
          setState(() => _isFavorite = false);
        }
      } else {
        await LibraryService.saveColor(widget.paint);
        if (mounted) {
          setState(() => _isFavorite = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _favBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topHeight = (size.height * 0.6).clamp(240.0, size.height);
    final fg = ThemeData.estimateBrightnessForColor(_display) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                elevation: 12,
                shadowColor: Colors.black.withAlpha(80),
                forceElevated: true,
                expandedHeight: topHeight,
                backgroundColor: _display,
                foregroundColor: fg,
                automaticallyImplyLeading: false,
                centerTitle: false,
                systemOverlayStyle:
                    ThemeData.estimateBrightnessForColor(_display) == Brightness.dark
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                  child: AppOutlineIconButton(
                    icon: Icons.arrow_back,
                    color: fg,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    child: AppOutlineIconButton(
                      icon: Icons.add,
                      color: fg,
                      onPressed: _showAddMenu,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                    child: AppOutlineIconButton(
                      icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      color: fg,
                      busy: _favBusy,
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ],
                title: Text(
                  widget.paint.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                flexibleSpace: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(tag: 'swatch_${widget.paint.id}', child: Container(color: _display)),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withAlpha(25),
                                  Colors.transparent,
                                  Colors.black.withAlpha(20),
                                ],
                                stops: const [0, .45, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 88,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.paint.brandName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: fg.withAlpha(220), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.paint.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: fg, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'A versatile shade that plays well with natural light and pairs beautifully across finishes.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: fg.withAlpha(230)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Subtle bottom edge shadow to add depth over the content below
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 36,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withAlpha(70),
                                    Colors.black.withAlpha(30),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.35, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(72),
                  child: SizedBox(
                    height: 72,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Transform.translate(
                        offset: Offset(0, -8),
                        child: _HeroTabs(),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(
                paint: widget.paint,
                lighting: lighting,
                cb: cb,
                onLighting: (m) => setState(() => lighting = m),
                onCb: (m) => setState(() => cb = m),
              ),
              _VisualsTab(paint: widget.paint),
              _PairingsTab(paint: widget.paint),
              _SimilarTab(paint: widget.paint),
              _UsageTab(paint: widget.paint),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDescription() {
    final tags = ColorUtils.undertoneTags(widget.paint.lab);
    final lrv = ColorUtils.computeLrv(widget.paint.hex).toStringAsFixed(1);
    final temp = widget.paint.temperature ?? '';
    return '${widget.paint.brandName} ${widget.paint.code} — ${tags.isEmpty ? 'neutral undertone' : tags.join(', ')} • LRV $lrv • ${temp.isNotEmpty ? temp : 'balanced'}. '
        'A versatile shade that plays well with natural light and pairs beautifully across finishes.';
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.grid_goldenratio),
                title: const Text('Add to Roller'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RollerScreen(initialPaints: [widget.paint]),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Add to Visualizer'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VisualizerScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// Replaced by AppOutlineIconButton (see lib/widgets/app_icon_button.dart)

// ===== Tabs row shown inside the hero =====
class _HeroTabs extends StatelessWidget {
  const _HeroTabs();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sc = t.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: sc.surface.withOpacity(0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          isScrollable: false, // equal-width tabs across the container
          dividerColor: Colors.transparent,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(vertical: 10),
          indicatorPadding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab, // indicator matches each tab's full width
          indicator: ShapeDecoration(
            color: sc.onSurface.withAlpha(72),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          labelColor: sc.onSurface,
          unselectedLabelColor: sc.onSurface.withAlpha(170),
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Visuals'),
            Tab(text: 'Pairings'),
            Tab(text: 'Similar'),
            Tab(text: 'Usage'),
          ],
        ),
      ),
    );
  }
}

// ===== Simple section title helper =====
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

// ===== Overview Tab (kept lightweight) =====
class _OverviewTab extends StatelessWidget {
  final Paint paint;
  final LightingMode lighting;
  final CbMode cb;
  final ValueChanged<LightingMode> onLighting;
  final ValueChanged<CbMode> onCb;

  const _OverviewTab({
    required this.paint,
    required this.lighting,
    required this.cb,
    required this.onLighting,
    required this.onCb,
  });

  @override
  Widget build(BuildContext context) {
    final lrv = ColorUtils.computeLrv(paint.hex).toStringAsFixed(1);
    final tags = ColorUtils.undertoneTags(paint.lab).join(', ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SectionTitle('Details'),
        const SizedBox(height: 8),
        _kv(context, 'Brand', paint.brandName),
        _kv(context, 'Name', paint.name),
        if (paint.code.isNotEmpty) _kv(context, 'Code', paint.code),
        _kv(context, 'LRV', lrv),
        if (tags.isNotEmpty) _kv(context, 'Undertones', tags),
        const SizedBox(height: 16),
        _SectionTitle('View Modes'),
        const SizedBox(height: 8),
        _ViewModes(
          lighting: lighting,
          cb: cb,
          onLighting: onLighting,
          onCb: onCb,
          deltaE: '—',
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: t.textTheme.labelLarge)),
          Expanded(child: Text(v, style: t.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ===== Visuals Tab (kept minimal; does not modify your Visualizer screen) =====
class _VisualsTab extends StatelessWidget {
  final Paint paint;
  const _VisualsTab({required this.paint});

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final onDark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final fg = onDark ? Colors.white : Colors.black;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SectionTitle('See it in action'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 160,
            color: color,
            child: Center(
              child: Text(
                'Room preview placeholder',
                style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VisualizerScreen()),
            );
          },
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Open Visualizer'),
        ),
      ],
    );
  }
}

// ===== Pairings Tab (simple pairing scaffold) =====
class _PairingsTab extends StatefulWidget {
  final Paint paint;
  const _PairingsTab({required this.paint});

  @override
  State<_PairingsTab> createState() => _PairingsTabState();
}

class _PairingsTabState extends State<_PairingsTab> {
  List<Paint> _pairings = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPairings();
  }

  Future<void> _loadPairings() async {
    try {
      final ids = widget.paint.companionIds ?? const <String>[];
      List<Paint> paints;
      if (ids.isNotEmpty) {
        paints = await FirebaseService.getPaintsByIds(ids);
      } else {
        final all = await SamplePaints.getAllPaints();
        paints = all
            .where((p) => p.name.toLowerCase().contains('white'))
            .take(3)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _pairings = paints;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionTitle('Suggested pairings'),
        const SizedBox(height: 8),
        if (_pairings.isEmpty)
          const Text('No pairings available.'),
        if (_pairings.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _pairings
                .map((p) => ColorSwatchCard(
                      paint: p,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => PaintDetailScreen(paint: p)),
                        );
                      },
                    ))
                .toList(),
          ),
      ],
    );
  }
}

// ===== Similar Tab (stacked chips with parallax + fixed rounded bottoms) =====
class _SimilarTab extends StatefulWidget {
  final Paint paint;
  const _SimilarTab({required this.paint});
  @override
  State<_SimilarTab> createState() => _SimilarTabState();
}

class _SimilarTabState extends State<_SimilarTab> {
  static const bool _kFirstOnTop = false;

  List<Paint> _similar = const [];
  bool _loading = true;

  ScrollController? _sc; // Use NestedScrollView's primary controller
  bool _scAttached = false;
  double _scrollOffset = 0.0;
  bool _showTopGlow = false;
  bool _showBottomGlow = true;
  bool _showHint = true;

  int? _selected;
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _loadSimilar();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showHint) {
        setState(() => _showHint = false);
      }
    });
  }

  void _onScroll() {
    if (_sc == null || !_sc!.hasClients) return;
    final max = _sc!.position.maxScrollExtent;
    final off = _sc!.offset;
    final top = off > 4;
    final bottom = off < (max - 4);
    if (top != _showTopGlow || bottom != _showBottomGlow || off != _scrollOffset) {
      setState(() {
        _showTopGlow = top;
        _showBottomGlow = bottom;
        _scrollOffset = off;
        _showHint = false;
      });
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final ids = widget.paint.similarIds ?? const <String>[];
      List<Paint> paints;
      if (ids.isNotEmpty) {
        paints = await FirebaseService.getPaintsByIds(ids);
      } else {
        final all = await SamplePaints.getAllPaints();
        paints = List<Paint>.from(all);
      }
      paints.removeWhere((p) => p.id == widget.paint.id);
      paints.sort((a, b) {
        final da = ColorUtils.deltaE2000(widget.paint.lab, a.lab);
        final db = ColorUtils.deltaE2000(widget.paint.lab, b.lab);
        return da.compareTo(db);
      });
      if (!mounted) return;
      setState(() {
        _similar = paints.take(20).toList();
        _loading = false;
      });
      // Only auto-scroll when using reversed order; with natural order
      // we keep the header fully expanded without programmatic jumps.
      if (_kFirstOnTop) {
        _scrollToFirst();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToFirst() {
    int tries = 0;
    void attempt() {
      final c = _sc ?? PrimaryScrollController.of(context);
      if (c == null || !c.hasClients) {
        if (tries++ < 6) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      if (_kFirstOnTop) {
        final max = c.position.maxScrollExtent;
        if (max > 0) {
          c.jumpTo(max);
        } else if (tries++ < 6) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
      } else {
        c.jumpTo(0);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (!identical(_sc, primary)) {
      if (_sc != null && _scAttached) {
        _sc!.removeListener(_onScroll);
        _scAttached = false;
      }
      _sc = primary;
      if (_sc != null && !_scAttached) {
        _sc!.addListener(_onScroll);
        _scAttached = true;
      }
    }
  }

  @override
  void dispose() {
    if (_sc != null && _scAttached) {
      _sc!.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final size = MediaQuery.of(context).size;
    final baseH = (size.height * 0.10).clamp(80.0, 180.0);
    final expandedH = (size.height * 0.22).clamp(180.0, 300.0);

    // Hero/base color under top card (so no white shows)
    Color baseColor = Colors.grey.shade200;
    final baseHex = widget.paint.hex;
    if (baseHex != null && baseHex.isNotEmpty) {
      final h = baseHex.startsWith('#') ? baseHex : '#$baseHex';
      if (h.toUpperCase() != '#000000') {
        baseColor = ColorUtils.getPaintColor(h);
      }
    }

    return Stack(
      children: [
        ListView.builder(
          reverse: _kFirstOnTop,
          clipBehavior: Clip.none,
          padding: EdgeInsets.fromLTRB(
            0,
            StackedChipCard.cardBottomRadius,
            0,
            StackedChipCard.overlap + 24,
          ),
          itemCount: _similar.length,
          itemBuilder: (ctx, visualIdx) {
            final actualIndex =
                _kFirstOnTop ? (_similar.length - 1 - visualIdx) : visualIdx;

            final paint = _similar[actualIndex];
            final color = ColorUtils.getPaintColor(paint.hex);
            final nextColor = (actualIndex + 1 < _similar.length)
                ? ColorUtils.getPaintColor(_similar[actualIndex + 1].hex)
                : baseColor;

            final selected = (_selected == actualIndex);

            final displayTopIndex = _kFirstOnTop ? (_similar.length - 1) : 0;
            final addSpacer = selected && (actualIndex == displayTopIndex);
            final spacerHeight = addSpacer ? (expandedH - baseH + 12) : 0.0;

            final itemKey = _itemKeys.putIfAbsent(actualIndex, () => GlobalKey());

            final card = StackedChipCard(
              key: itemKey,
              index: actualIndex,
              paint: paint,
              color: color,
              nextColor: nextColor,
              isSelected: selected,
              baseHeight: baseH,
              expandedHeight: expandedH,
              scrollOffset: _scrollOffset,
              onTap: (ix) {
                final newSel = (_selected == ix) ? null : ix;
                setState(() => _selected = newSel);
                if (newSel != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final ctx = _itemKeys[newSel]?.currentContext;
                    if (ctx != null) {
                      Scrollable.ensureVisible(
                        ctx,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        alignment: 0.1,
                      );
                    }
                  });
                }
              },
              onOpenDetail: (p) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PaintDetailScreen(paint: p)),
                );
              },
            );

            if (spacerHeight > 0) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: spacerHeight),
                  card,
                ],
              );
            }
            return card;
          },
        ),
        // Top/bottom fades
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showTopGlow ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 24,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black12, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showBottomGlow ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black12, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),
        // One-time scroll hint
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showHint ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.swipe, size: 16, color: Colors.white70),
                    SizedBox(width: 6),
                    Text('Scroll', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===== Usage Tab (uses _SectionTitle; braces added for lints) =====
class _UsageTab extends StatelessWidget {
  final Paint paint;
  const _UsageTab({required this.paint});

  @override
  Widget build(BuildContext context) {
    final lrv = ColorUtils.computeLrv(paint.hex);
    final undertones = ColorUtils.undertoneTags(paint.lab).join(', ');
    final tips = _tipsFor(lrv, undertones);
    final rooms = _roomsFor(undertones, lrv);
    final sampleUrl = paint.metadata?['orderUrl'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionTitle('Tips'),
        const SizedBox(height: 8),
        ...tips.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(t)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Great for'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms.map((r) => _roomChip(context, r)).toList(),
        ),
        if (sampleUrl != null && sampleUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openUrl(context, sampleUrl),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Order Sample'),
            ),
          ),
        ],
      ],
    );
  }

  List<String> _tipsFor(double lrv, String undertones) {
    final tips = <String>[];
    if (lrv >= 70) {
      tips.add('High LRV (${lrv.toStringAsFixed(0)}%) keeps spaces bright; pair with soft contrast on trim.');
    }
    if (lrv < 30) {
      tips.add('Low LRV adds mood; balance with lighter textiles and ample lighting.');
    }
    if (undertones.contains('warm')) {
      tips.add('Warm undertones feel cozy under incandescent or warm LED bulbs.');
    }
    if (undertones.contains('cool')) {
      tips.add('Cool undertones read crisp in north-facing rooms; consider warmer lighting.');
    }
    if (tips.isEmpty) {
      tips.add('Versatile tone; test large samples across different walls and times of day.');
    }
    return tips;
  }

  List<String> _roomsFor(String undertones, double lrv) {
    final rooms = <String>[];
    if (lrv >= 70) {
      rooms.addAll(['Bedrooms', 'Living Rooms']);
    }
    if (lrv >= 40 && lrv <= 70) {
      rooms.addAll(['Kitchens', 'Hallways']);
    }
    if (lrv < 40) {
      rooms.addAll(['Dining Rooms', 'Accent Walls']);
    }
    if (undertones.contains('blue') || undertones.contains('cool')) {
      rooms.add('Bathrooms');
    }
    return rooms.toSet().toList();
  }

  Widget _roomChip(BuildContext context, String label) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.colorScheme.outline.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_outlined, size: 16),
          const SizedBox(width: 6),
          Text(label, style: t.textTheme.labelMedium),
        ],
      ),
    );
  }

  void _openUrl(BuildContext context, String url) {
    // Hook up url_launcher if desired
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Opening order page...')));
  }
}

// ===== Small view-modes panel (referenced in Overview) =====
class _ViewModes extends StatelessWidget {
  final LightingMode lighting;
  final CbMode cb;
  final ValueChanged<LightingMode> onLighting;
  final ValueChanged<CbMode> onCb;
  final String deltaE;

  const _ViewModes({
    required this.lighting,
    required this.cb,
    required this.onLighting,
    required this.onCb,
    required this.deltaE,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    ChoiceChip chip<T>(String label, T value, T group, ValueChanged<T> on) {
      final sel = value == group;
      return ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => on(value),
        selectedColor: t.colorScheme.primary.withAlpha(36),
        labelStyle:
            TextStyle(color: sel ? t.colorScheme.primary : t.colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withAlpha(153),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.colorScheme.outline.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Modes',
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Tooltip(
                message: 'Approximate color difference',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.colorScheme.outline.withAlpha(38)),
                  ),
                  child: Text('ΔE $deltaE', style: t.textTheme.labelMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Lighting',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurface.withAlpha(165))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('D65', LightingMode.d65, lighting, onLighting),
            chip('Incandescent', LightingMode.incandescent, lighting, onLighting),
            chip('North', LightingMode.north, lighting, onLighting),
          ]),
          const SizedBox(height: 12),
          Text('Accessibility',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurface.withAlpha(165))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('Off', CbMode.none, cb, onCb),
            chip('Protan', CbMode.protan, cb, onCb),
            chip('Deuter', CbMode.deuter, cb, onCb),
            chip('Tritan', CbMode.tritan, cb, onCb),
          ]),
        ],
      ),
    );
  }
}
