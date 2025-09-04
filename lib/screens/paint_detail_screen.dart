import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/utils/color_math.dart';
import 'package:color_canvas/services/firebase_service.dart';

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

  Color get _base => ColorUtils.getPaintColor(widget.paint.hex);
  Color get _display {
    var c = _base;
    // order: color-blind simulation -> lighting tint
    switch (cb) {
      case CbMode.deuter: c = ColorMath.simulateCB(c, 'deuter'); break;
      case CbMode.protan: c = ColorMath.simulateCB(c, 'protan'); break;
      case CbMode.tritan: c = ColorMath.simulateCB(c, 'tritan'); break;
      case CbMode.none: break;
    }
    switch (lighting) {
      case LightingMode.d65: c = ColorMath.simulateLighting(c, 'd65'); break;
      case LightingMode.incandescent: c = ColorMath.simulateLighting(c, 'incandescent'); break;
      case LightingMode.north: c = ColorMath.simulateLighting(c, 'north'); break;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final fg = ThemeData.estimateBrightnessForColor(_display) == Brightness.dark ? Colors.white : Colors.black;

    final delta = ColorMath.deltaE76(_base, _display);
    final deltaLabel = delta.toStringAsFixed(1);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: _display,
            foregroundColor: fg,
            title: Text(widget.paint.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Hero(
                  tag: 'swatch_${widget.paint.id}',
                  child: Container(color: _display),
                ),
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
              ]),
            ),
          ),

          // Rounded sheet-cap where the color meets the info
          SliverToBoxAdapter(
            child: Container(
              height: 14, // small cap height; tweak 12–18 if you like
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  // soft lift so the sheet reads like a card coming up from the color area
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.list(children: [
              _MetaRow(paint: widget.paint),

              const SizedBox(height: 14),
              _ViewModes(
                lighting: lighting,
                cb: cb,
                onLighting: (m) => setState(() => lighting = m),
                onCb: (m) => setState(() => cb = m),
                deltaE: deltaLabel,
              ),

              const SizedBox(height: 16),
              _AnalyticsStrip(paint: widget.paint),

              const SizedBox(height: 20),
              _SectionTitle('Pairings we love'),
              _PairingRow(ids: widget.paint.companionIds ?? const []),

              const SizedBox(height: 14),
              _SectionTitle('Similar shades'),
              _SimilarRow(ids: widget.paint.similarIds ?? const []),

              const SizedBox(height: 30),
              _ActionBar(paint: widget.paint),
            ]),
          ),
        ],
      ),
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

class _ActionBar extends StatelessWidget {
  final Paint paint;
  const _ActionBar({required this.paint});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save to Library')),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.color_lens), label: const Text('Load in Roller')),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.visibility_outlined), label: const Text('Visualize')),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.compare_arrows_rounded), label: const Text('Compare')),
      ],
    );
  }
}