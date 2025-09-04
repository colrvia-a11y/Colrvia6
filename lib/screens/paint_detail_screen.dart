import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/utils/color_math.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'dart:ui';
import 'package:color_canvas/services/color_service.dart';
import 'package:color_canvas/services/library_service.dart';
import 'roller_screen.dart';
import 'visualizer_screen.dart';
import 'package:color_canvas/data/sample_paints.dart';
import 'dart:async';

enum LightingMode { d65, incandescent, north }
enum CbMode { none, deuter, protan, tritan }

class PaintDetailScreen extends StatefulWidget {
  final Paint paint;
  const PaintDetailScreen({super.key, required this.paint});

  @override
  State<PaintDetailScreen> createState() => _PaintDetailScreenState();
}

class _PaintDetailScreenState extends State<PaintDetailScreen> {
  LightingMode lighting = LightingMode.d65;
  CbMode cb = CbMode.none;
  // ignore: prefer_final_fields
  bool _isFavorite = false;
  // ignore: prefer_final_fields
  bool _favBusy = false;

  Color? _resolvedBase;
  bool _hasValidHex(String? hex) {
    if (hex == null || hex.isEmpty) return false;
    final h = hex.startsWith('#') ? hex : '#$hex';
    // Treat pure black as invalid for our use-case to avoid flashing a black header
    if (h.toUpperCase() == '#000000') return false;
    final re = RegExp(r'^#([0-9A-Fa-f]{6})$');
    return re.hasMatch(h);
  }
  Color get _base {
    if (_resolvedBase != null) return _resolvedBase!;
    if (_hasValidHex(widget.paint.hex)) {
      return ColorUtils.getPaintColor(widget.paint.hex);
    }
    // Fallback placeholder while resolving from ColorService
    return Colors.grey.shade200;
  }
  // For header rendering, show the base paint color directly.
  // View mode simulations are applied within content, not the hero header.
  Color get _display => _base;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    // Only resolve via ColorService when the incoming hex is missing/invalid.
    if (!_hasValidHex(widget.paint.hex)) {
      ColorService.getColorFromId(widget.paint.id).then((c) {
        if (!mounted) return;
        setState(() => _resolvedBase = c);
      }).catchError((_) {
        // Ignore resolve errors (e.g., Firestore permission); keep fallback color.
      });
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save favorites')));
      }
      return;
    }
    setState(() => _favBusy = true);
    try {
      if (_isFavorite) {
        await LibraryService.removeColor(widget.paint.id);
        if (mounted) setState(() => _isFavorite = false);
      } else {
        await LibraryService.saveColor(widget.paint);
        if (mounted) setState(() => _isFavorite = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update favorite: $e')));
      }
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug quick log to verify incoming color values
    // ignore: avoid_print
    debugPrint('[PaintDetail] id=${widget.paint.id} hex=${widget.paint.hex} validHex=${_hasValidHex(widget.paint.hex)} base=$_base');
    final size = MediaQuery.of(context).size;
    final topHeight = (size.height * 0.6).clamp(240.0, size.height);
    final fg = ThemeData.estimateBrightnessForColor(_display) == Brightness.dark ? Colors.white : Colors.black;

    // delta between base and simulated display can be shown in overview if desired.

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                elevation: 0,
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
                  child: _OutlineSquareIconButton(
                    icon: Icons.arrow_back,
                    color: fg,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    child: _OutlineSquareIconButton(
                      icon: Icons.add,
                      color: fg,
                      onPressed: _showAddMenu,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                    child: _OutlineSquareIconButton(
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
                // Keep hero as paint color; clip to match rounded shape
                flexibleSpace: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: FlexibleSpaceBar(
                    background: Stack(fit: StackFit.expand, children: [
                      Hero(tag: 'swatch_${widget.paint.id}', child: Container(color: _display)),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [Colors.white.withAlpha(25), Colors.transparent, Colors.black.withAlpha(20)],
                              stops: const [0, .45, 1],
                            ),
                          ),
                        ),
                      ),
                      // Lower-third text (leave room for tabs inside hero)
                      Positioned(
                        left: 0, right: 0, bottom: 88,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.paint.brandName,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: fg.withAlpha(220), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(widget.paint.name,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: fg, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(_buildDescription(),
                                  maxLines: 12,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: fg.withAlpha(230))),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(64),
                  child: SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _HeroTabs(),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(paint: widget.paint, lighting: lighting, cb: cb, onLighting: (m){ setState(()=>lighting=m); }, onCb: (m){ setState(()=>cb=m); }),
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
    return '${widget.paint.brandName} ${widget.paint.code} — ${tags.isEmpty ? 'neutral undertone' : tags.join(', ')} • LRV $lrv • ${temp.isNotEmpty ? temp : 'balanced'}.'
        ' A versatile shade that plays well with natural light and pairs beautifully across finishes.';
  }

  void _showAddMenu() async {
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
    chip<T>(String label, T value, T group, ValueChanged<T> on) {
      final sel = value == group;
      return ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => on(value),
        selectedColor: t.colorScheme.primary.withAlpha(36),
        labelStyle: TextStyle(color: sel ? t.colorScheme.primary : t.colorScheme.onSurface),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Text('View modes', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Tooltip(
              message: 'Approximate color difference from base (CIE76)',
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
        Text('Lighting', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withAlpha(165))),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          chip('D65', LightingMode.d65, lighting, onLighting),
          chip('Incandescent', LightingMode.incandescent, lighting, onLighting),
          chip('North', LightingMode.north, lighting, onLighting),
        ]),
        const SizedBox(height: 12),
        Text('Color-blind simulation', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withAlpha(165))),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          chip('None', CbMode.none, cb, onCb),
          chip('Deuter', CbMode.deuter, cb, onCb),
          chip('Protan', CbMode.protan, cb, onCb),
          chip('Tritan', CbMode.tritan, cb, onCb),
        ]),
      ]),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Paint paint;
  const _MetaRow({required this.paint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${paint.brandName} • ${paint.code}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _copyChip(context, paint.hex.toUpperCase(), icon: Icons.tag, semantics: 'hex'),
            _plainChip('LRV ${paint.computedLrv.toStringAsFixed(0)}', style: chipStyle),
          ],
        ),
      ],
    );
  }

  Widget _copyChip(BuildContext context, String text, {IconData icon = Icons.copy, String semantics = 'value'}) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        AnalyticsService.instance.logEvent('detail_copy_$semantics', {'value': text});
        if (!context.mounted) return;
        // tiny toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $semantics: $text'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      },
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(178),
    );
  }

  Widget _plainChip(String text, {TextStyle? style}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(30)),
      ),
      child: Text(text, style: style),
    );
  }
}

class _AnalyticsStrip extends StatelessWidget {
  final Paint paint;
  const _AnalyticsStrip({required this.paint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lrv = paint.computedLrv.clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(153),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick analytics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metric(
                  context,
                  label: 'Temperature',
                  value: paint.temperature ?? '—',
                ),
              ),
              Expanded(
                child: _metric(
                  context,
                  label: 'Undertone',
                  value: paint.undertone ?? '—',
                ),
              ),
              Expanded(
                child: _metric(
                  context,
                  label: 'LRV',
                  value: lrv.toStringAsFixed(0),
                  trailing: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                    child: Slider(
                      value: lrv,
                      min: 0, max: 100,
                      onChanged: null, // purely indicative for now
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, {required String label, required String value, Widget? trailing}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153))),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (trailing != null) const SizedBox(height: 6),
        if (trailing != null) trailing,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800));
  }
}

class _PairingRow extends StatefulWidget {
  final List<String> ids;
  const _PairingRow({required this.ids});

  @override
  State<_PairingRow> createState() => _PairingRowState();
}

class _PairingRowState extends State<_PairingRow> {
  List<Paint>? _paints;

  @override
  void initState() {
    super.initState();
    _fetchPaints();
  }

  Future<void> _fetchPaints() async {
    if (widget.ids.isEmpty) return;
    final paints = await FirebaseService.getPaintsByIds(widget.ids);
    if (mounted) {
      setState(() {
        _paints = paints;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) {
      return Text('We’re curating pairings for this shade…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(153))
      );
    }

    if (_paints == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _paints!.map((paint) {
        return InputChip(
          label: Text(paint.name),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PaintDetailScreen(paint: paint),
            ));
          },
        );
      }).toList(),
    );
  }
}

class _SimilarRow extends StatefulWidget {
  final List<String> ids;
  const _SimilarRow({required this.ids});

  @override
  State<_SimilarRow> createState() => _SimilarRowState();
}

class _SimilarRowState extends State<_SimilarRow> {
  List<Paint>? _paints;

  @override
  void initState() {
    super.initState();
    _fetchPaints();
  }

  Future<void> _fetchPaints() async {
    if (widget.ids.isEmpty) return;
    final paints = await FirebaseService.getPaintsByIds(widget.ids);
    if (mounted) {
      setState(() {
        _paints = paints;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) {
      return Text('Similar shades coming soon',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(153))
      );
    }

    if (_paints == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _paints!.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final paint = _paints![i];
          return ActionChip(
            label: Text(paint.name),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PaintDetailScreen(paint: paint),
              ));
            },
          );
        },
      ),
    );
  }
}

// _ActionBar removed; actions are handled contextually elsewhere.

class _GlassyIconButton extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final VoidCallback onPressed;
  final bool busy;
  const _GlassyIconButton({
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withAlpha(36),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: busy ? null : onPressed,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                      )
                    : Icon(icon, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineSquareIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool busy;
  const _OutlineSquareIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(10);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: BorderSide(color: color.withAlpha(140), width: 1.2),
      ),
      child: InkWell(
        borderRadius: r,
        onTap: busy ? null : onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

class _HeroTabs extends StatelessWidget {
  const _HeroTabs({super.key});
  @override
  Widget build(BuildContext context) {
    // Compute foreground based on the current header color brightness
    final headerColor =
        context.findAncestorStateOfType<_PaintDetailScreenState>()?._display ??
            Theme.of(context).colorScheme.surface;
    final fg = ThemeData.estimateBrightnessForColor(headerColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    const accent = Color(0xFFF2B897);
    return SizedBox(
      height: 52,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withAlpha(60)),
          color: Colors.white.withAlpha(26),
        ),
        child: TabBar(
          isScrollable: true,
          dividerColor: Colors.transparent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withAlpha(72),
          ),
          labelColor: fg,
          unselectedLabelColor: fg.withAlpha(180),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Visuals'),
            Tab(text: 'Pairings'),
            Tab(text: 'Similar'),
            Tab(text: 'Usage & Tips'),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Paint paint;
  final LightingMode lighting;
  final CbMode cb;
  final ValueChanged<LightingMode> onLighting;
  final ValueChanged<CbMode> onCb;
  const _OverviewTab({required this.paint, required this.lighting, required this.cb, required this.onLighting, required this.onCb});

  @override
  Widget build(BuildContext context) {
    final lrv = ColorUtils.computeLrv(paint.hex).toStringAsFixed(1);
    final tags = ColorUtils.undertoneTags(paint.lab);
    final color = ColorUtils.getPaintColor(paint.hex);
    final crWhite = contrastRatio(color, Colors.white);
    final crBlack = contrastRatio(color, Colors.black);
    final passWhite = crWhite >= 4.5;
    final passBlack = crBlack >= 4.5;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _MetaRow(paint: paint),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _infoChip(context, Icons.wb_sunny_outlined, 'LRV $lrv%', tooltip: 'Light Reflectance Value'),
            if (tags.isNotEmpty)
              _tagChip(context, tags.first),
            _infoChip(context, Icons.format_color_text, 'vs White ${crWhite.toStringAsFixed(2)}',
                tooltip: 'WCAG contrast vs white', pass: passWhite),
            _infoChip(context, Icons.format_color_fill, 'vs Black ${crBlack.toStringAsFixed(2)}',
                tooltip: 'WCAG contrast vs black', pass: passBlack),
          ],
        ),
        const SizedBox(height: 12),
        _ViewModes(lighting: lighting, cb: cb, onLighting: onLighting, onCb: onCb, deltaE: lrv),
        const SizedBox(height: 16),
        _AnalyticsStrip(paint: paint),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label, {String? tooltip, bool? pass}) {
    final t = Theme.of(context);
    final base = pass == null
        ? t.colorScheme.surfaceContainerHighest
        : (pass ? Colors.green.withAlpha(28) : Colors.orange.withAlpha(28));
    final border = pass == null
        ? t.colorScheme.outline.withAlpha(60)
        : (pass ? Colors.green.withAlpha(90) : Colors.orange.withAlpha(90));
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label, style: t.textTheme.labelMedium),
      ]),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: chip) : chip;
  }

  Widget _tagChip(BuildContext context, String tag) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.colorScheme.primary.withAlpha(80)),
      ),
      child: Text(tag, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary)),
    );
  }

  // Removed unused _contrastChip helper.
}

class _VisualsTab extends StatelessWidget {
  final Paint paint;
  const _VisualsTab({required this.paint});
  @override
  Widget build(BuildContext context) {
    final ids = (paint.metadata?['renderIds'] as List?)?.cast<String>() ?? const <String>[];
    if (ids.isEmpty) return Center(child: Text('No visuals yet'));

    return _Carousel(urls: ids);
  }
}

class _Carousel extends StatefulWidget {
  final List<String> urls;
  const _Carousel({required this.urls});
  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _ctrl = PageController();
  int _index = 0;
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.urls.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: InkWell(
                onTap: () => _openLightbox(context, widget.urls[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(widget.urls[i], fit: BoxFit.cover, width: double.infinity),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.urls.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.all(4),
              width: active ? 10 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFF2B897) : Colors.grey.withAlpha(120),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _openLightbox(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: AspectRatio(
            aspectRatio: 4/3,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _PairingsTab extends StatelessWidget {
  final Paint paint;
  const _PairingsTab({required this.paint});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SectionTitle('Pairings we love'),
        const SizedBox(height: 8),
        _PairingRow(ids: paint.companionIds ?? const []),
      ],
    );
  }
}

class _SimilarTab extends StatefulWidget {
  final Paint paint;
  const _SimilarTab({required this.paint});
  @override
  State<_SimilarTab> createState() => _SimilarTabState();
}

class _SimilarTabState extends State<_SimilarTab> {
  List<Paint> _similar = const [];
  bool _loading = true;
  final ScrollController _sc = ScrollController();
  bool _showTopGlow = false;
  bool _showBottomGlow = true;
  bool _showHint = true;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _loadSimilar();
    _sc.addListener(_onScroll);
    // Auto-hide the hint after a short delay
    Timer(const Duration(seconds: 3), () {
      if (mounted && _showHint) setState(() => _showHint = false);
    });
  }

  Future<void> _loadSimilar() async {
    try {
      final ids = widget.paint.similarIds ?? const <String>[];
      List<Paint> paints;
      if (ids.isNotEmpty) {
        paints = await FirebaseService.getPaintsByIds(ids);
      } else {
        // Fallback: compute from local sample paints
        final all = await SamplePaints.getAllPaints();
        paints = List<Paint>.from(all);
      }
      // Sort by Delta E (closest first), exclude self
      paints.removeWhere((p) => p.id == widget.paint.id);
      paints.sort((a, b) {
        final da = ColorUtils.deltaE2000(widget.paint.lab, a.lab);
        final db = ColorUtils.deltaE2000(widget.paint.lab, b.lab);
        return da.compareTo(db);
      });
      if (mounted) {
        setState(() {
          _similar = paints.take(10).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    final max = _sc.position.maxScrollExtent;
    final off = _sc.offset;
    final top = off > 4;
    final bottom = off < (max - 4);
    if (top != _showTopGlow || bottom != _showBottomGlow || _showHint) {
      setState(() {
        _showTopGlow = top;
        _showBottomGlow = bottom;
        _showHint = false;
      });
    }
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
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
    return Stack(
      children: [
        ListView.builder(
          controller: _sc,
          padding: EdgeInsets.zero,
          itemCount: _similar.length,
          itemBuilder: (ctx, i) {
            final p = _similar[i];
            final color = ColorUtils.getPaintColor(p.hex);
            final isLast = i == _similar.length - 1;
            final onDark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
            final fg = onDark ? Colors.white : Colors.black;
            final selected = _selected == i;
            final targetH = selected ? expandedH : baseH;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selected = selected ? null : i;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: targetH,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: isLast
                      ? const BorderRadius.vertical(bottom: Radius.circular(28))
                      : BorderRadius.zero,
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6))]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              offset: selected ? Offset.zero : const Offset(0, 0.02),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.brandName,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: fg,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: fg,
                                          fontWeight: FontWeight.w800,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _OutlineSquareIconButton(
                            icon: Icons.arrow_forward,
                            color: fg,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PaintDetailScreen(paint: p)),
                              );
                            },
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: selected
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _similarInfoTag(context, fg, '#'+p.hex.replaceFirst('#','').toUpperCase()),
                                        if (p.code.isNotEmpty) _similarInfoTag(context, fg, p.code),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: fg,
                                              side: BorderSide(color: fg.withAlpha(140)),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => RollerScreen(initialPaints: [p]),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.grid_goldenratio),
                                            label: const Text('Add to Roller'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: fg,
                                              side: BorderSide(color: fg.withAlpha(140)),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => const VisualizerScreen(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.visibility_outlined),
        											label: const Text('Add to Visualizer'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Subtle top/bottom fade indicators
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
        // One-time subtle scroll hint
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

  Widget _infoTag(BuildContext context, Color fg, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withAlpha(140)),
        color: Colors.white.withAlpha(20),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

Widget _similarInfoTag(BuildContext context, Color fg, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: fg.withAlpha(140)),
      color: Colors.white.withAlpha(20),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

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
        _SectionTitle('Tips'),
        const SizedBox(height: 8),
        ...tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• '), Expanded(child: Text(t)),
          ]),
        )),
        const SizedBox(height: 12),
        _SectionTitle('Great for'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: rooms.map((r) => _roomChip(context, r)).toList()),
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
        ]
      ],
    );
  }

  List<String> _tipsFor(double lrv, String undertones) {
    final tips = <String>[];
    if (lrv >= 70) tips.add('High LRV (${'${lrv.toStringAsFixed(0)}%'}) keeps spaces bright; pair with soft contrast on trim.');
    if (lrv < 30) tips.add('Low LRV adds mood; balance with lighter textiles and ample lighting.');
    if (undertones.contains('warm')) tips.add('Warm undertones feel cozy under incandescent or warm LED bulbs.');
    if (undertones.contains('cool')) tips.add('Cool undertones read crisp in north-facing rooms; consider warmer lighting.');
    if (tips.isEmpty) tips.add('Versatile tone; test large samples across different walls and times of day.');
    return tips;
  }

  List<String> _roomsFor(String undertones, double lrv) {
    final rooms = <String>[];
    if (lrv >= 70) rooms.addAll(['Bedrooms', 'Living Rooms']);
    if (lrv.between(40, 70)) rooms.addAll(['Kitchens', 'Hallways']);
    if (lrv < 40) rooms.addAll(['Dining Rooms', 'Accent Walls']);
    if (undertones.contains('blue') || undertones.contains('cool')) rooms.add('Bathrooms');
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.home_outlined, size: 16),
        const SizedBox(width: 6),
        Text(label, style: t.textTheme.labelMedium),
      ]),
    );
  }

  void _openUrl(BuildContext context, String url) {
    // Placeholder: integrate url_launcher or router as needed
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening order page...')));
  }
}

extension on double {
  bool between(double a, double b) => this >= a && this <= b;
}
