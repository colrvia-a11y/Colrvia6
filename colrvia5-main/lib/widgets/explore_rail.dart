// lib/widgets/explore_rail.dart
import 'package:flutter/material.dart';
import '../services/paint_query_service.dart';
import '../widgets/fancy_paint_tile.dart';
import '../widgets/staggered_entrance.dart';
import '../firestore/firestore_data_schema.dart';

class ExploreRail extends StatefulWidget {
  final String title;
  final String? colorFamily;
  final String? undertone;
  final String? temperature;
  final RangeValues? lrvRange;
  final void Function(Paint) onSelect;
  final void Function(Paint)? onLongPress;

  final void Function({
    String? colorFamily,
    String? undertone,
    String? temperature,
    RangeValues? lrvRange,
  })? onSeeAll;

  // NEW: let rails follow the same card proportions as All
  final double tileAspect; // width / height
  final double horizontalPadding;
  final double tileSpacing;

  const ExploreRail({
    super.key,
    required this.title,
    this.colorFamily,
    this.undertone,
    this.temperature,
    this.lrvRange,
    required this.onSelect,
    this.onLongPress,
    this.onSeeAll,
    this.tileAspect = 0.72,        // same as All
    this.horizontalPadding = 16.0, // same as page padding
    this.tileSpacing = 12.0,       // same as grid spacing
  });

  @override
  State<ExploreRail> createState() => _ExploreRailState();
}

class _ExploreRailState extends State<ExploreRail> {
  List<Paint>? items;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await PaintQueryService.instance.exploreRail(
      colorFamily: widget.colorFamily,
      undertone: widget.undertone,
      temperature: widget.temperature,
      lrvRange: widget.lrvRange,
      sort: PaintSort.hue,
      limit: 16,
    );
    if (!mounted) return;
    setState(() { items = list; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _skeleton();
    }
    if (items == null || items!.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: () {
                  if (widget.onSeeAll != null) {
                    widget.onSeeAll!(
                      colorFamily: widget.colorFamily,
                      undertone: widget.undertone,
                      temperature: widget.temperature,
                      lrvRange: widget.lrvRange,
                    );
                  }
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Mirror a 2-column grid width to get identical sizes
            const cols = 2;
            final usableW = constraints.maxWidth - (widget.horizontalPadding * 2);
            final tileW = (usableW - (cols - 1) * widget.tileSpacing) / cols;
            final tileH = tileW / widget.tileAspect;

            return SizedBox(
              height: tileH, // same height as All
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
                itemCount: items!.length,
                separatorBuilder: (_, __) => SizedBox(width: widget.tileSpacing),
                itemBuilder: (_, i) {
                  final p = items![i];
                  return SizedBox(
                    width: tileW,  // same width as All
                    height: tileH, // same height as All
                    child: StaggeredEntrance(
                      delay: Duration(milliseconds: 40 + i * 55),
                      child: FancyPaintTile(
                        paint: p,
                        dense: false,                 // matches All
                        selected: false,
                        onOpen: () => widget.onSelect(p),
                        onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(p),
                        onQuickRoller: null,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _skeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mirror a 2-column grid width to get identical sizes
        const cols = 2;
        final usableW = constraints.maxWidth - (widget.horizontalPadding * 2);
        final tileW = (usableW - (cols - 1) * widget.tileSpacing) / cols;
        final tileH = tileW / widget.tileAspect;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 22, width: 140, margin: EdgeInsets.symmetric(horizontal: widget.horizontalPadding, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6))),
            SizedBox(
              height: tileH,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
                itemCount: 8,
                separatorBuilder: (_, __) => SizedBox(width: widget.tileSpacing),
                itemBuilder: (_, __) => Container(
                  width: tileW,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
