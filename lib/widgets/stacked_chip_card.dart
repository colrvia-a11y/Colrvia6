import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';
import '../theme.dart';

class StackedChipCard extends StatelessWidget {
  // Tweakables
  static const double cardBottomRadius = AppDims.radiusLarge;
  static const double overlap = cardBottomRadius - 6.0; // 18px
  static const double secondExtraRoom = AppDims.gap * 2;
  static const double _parallaxBase = 0.06;
  static const double _parallaxIncrement = 0.015;
  static const double _parallaxMaxShift = 40.0;

  final Paint paint;
  final Color color;
  final Color nextColor;
  final bool isSelected;
  final double baseHeight;
  final double expandedHeight;
  final int index;
  final double scrollOffset;
  final ValueChanged<int> onTap;
  final ValueChanged<Paint> onOpenDetail;

  const StackedChipCard({
    super.key,
    required this.paint,
    required this.color,
    required this.nextColor,
    required this.isSelected,
    required this.baseHeight,
    required this.expandedHeight,
    required this.index,
    required this.scrollOffset,
    required this.onTap,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius cardRadius =
        BorderRadius.vertical(bottom: Radius.circular(cardBottomRadius));
    final bool onDark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final Color fg = onDark ? Colors.white : Colors.black;

    double baseOverlap = index == 0 ? -cardBottomRadius : -overlap;
    if (index == 1) {
      baseOverlap += secondExtraRoom;
    }
    final double parallaxFactor = _parallaxBase + index * _parallaxIncrement;
    final double parallaxShift =
        (-scrollOffset * parallaxFactor).clamp(-_parallaxMaxShift, _parallaxMaxShift);
    final double shiftY = isSelected ? 0.0 : (baseOverlap + parallaxShift);

    return GestureDetector(
      onTap: () => onTap(index),
      child: Transform.translate(
        offset: Offset(0, shiftY),
        child: Stack(
          children: [
            // Underlay to ensure rounded bottom reveals next card color (never white)
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, overlap),
                child: ClipRRect(
                  borderRadius: cardRadius,
                  child: Container(color: nextColor),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: cardRadius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: isSelected ? expandedHeight : baseHeight,
                decoration: BoxDecoration(borderRadius: cardRadius),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: cardRadius,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ]
                        : null,
                  ),
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
                              offset: isSelected ? Offset.zero : const Offset(0, 0.02),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    paint.brandName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    paint.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: fg, fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDims.radiusMedium),
                              side: BorderSide(color: fg.withAlpha(140), width: 1.2),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppDims.radiusMedium),
                              splashColor: fg.withAlpha(60),
                              highlightColor: fg.withAlpha(24),
                              hoverColor: fg.withAlpha(12),
                              focusColor: fg.withAlpha(24),
                              onTap: () => onOpenDetail(paint),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(child: Icon(Icons.arrow_forward, color: fg)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: isSelected
                            ? Padding(
                                padding:
                                    const EdgeInsets.only(top: AppDims.gap),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _infoTag(
                                          context,
                                          fg,
                                          '#${paint.hex.replaceFirst('#', '').toUpperCase()}',
                                        ),
                                        if (paint.code.isNotEmpty)
                                          _infoTag(context, fg, paint.code),
                                      ],
                                    ),
                                    const SizedBox(height: AppDims.gap),
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
                                                  builder: (_) =>
                                                      const RollerScreen(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.grid_goldenratio),
                                            label: const Text('Add to Roller'),
                                          ),
                                        ),
                                        const SizedBox(width: AppDims.gap),
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
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoTag(BuildContext context, Color fg, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withAlpha(140)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

