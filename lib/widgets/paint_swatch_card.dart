import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';

class PaintSwatchCard extends StatefulWidget {
  final Paint paint;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  // new
  final bool showQuickRoller;
  final VoidCallback? onQuickRoller;
  final bool hoverable;
  final bool useHero;

  const PaintSwatchCard({
    super.key,
    required this.paint,
    this.compact = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.showQuickRoller = false,
    this.onQuickRoller,
    this.hoverable = true,
    this.useHero = true,
  });

  @override
  State<PaintSwatchCard> createState() => _PaintSwatchCardState();
}

class _PaintSwatchCardState extends State<PaintSwatchCard> {
  bool _hovering = false;
  bool _pressed = false;

  void _setHover(bool v) => setState(() => _hovering = v);
  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.paint;
    final color = ColorUtils.getPaintColor(p.hex);

    final scale = _pressed ? 0.985 : (_hovering ? 1.015 : 1.0);
    final shadowOpacity = _pressed ? 0.06 : (_hovering ? 0.16 : 0.10);

    Widget swatch = Container(
      height: widget.compact ? 120 : 140,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.20)),
      ),
    );

    if (widget.useHero) {
      swatch = Hero(
          tag: 'paint:${p.id}', flightShuttleBuilder: _flight, child: swatch);
    }

    Widget card = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowOpacity),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: () {
              HapticFeedback.selectionClick();
              widget.onLongPress?.call();
            },
            onHighlightChanged: _setPressed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // swatch + overlays
                Stack(
                  children: [
                    swatch,
                    if (widget.showQuickRoller && widget.onQuickRoller != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color:
                              theme.colorScheme.surface.withValues(alpha: 0.92),
                          elevation: 3,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: widget.onQuickRoller,
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.color_lens, size: 16),
                            ),
                          ),
                        ),
                      ),
                    if (widget.selected)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: .90),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Selected',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // meta
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.brandName} • ${p.code}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: p.hex.toUpperCase()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Copied ${p.hex.toUpperCase()}')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(p.hex.toUpperCase(),
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.hoverable) {
      card = SizedBox.expand(
        child: MouseRegion(
          onEnter: (_) => _setHover(true),
          onExit: (_) => _setHover(false),
          child: card,
        ),
      );
    }

    return card;
  }

  // slightly smoother hero flight
  Widget _flight(BuildContext _, Animation<double> anim,
      HeroFlightDirection dir, BuildContext from, BuildContext to) {
    return ScaleTransition(
        scale: Tween(
                begin: 1.0, end: dir == HeroFlightDirection.push ? 1.03 : 0.98)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(
            opacity:
                CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic),
            child: to.widget));
  }
}
