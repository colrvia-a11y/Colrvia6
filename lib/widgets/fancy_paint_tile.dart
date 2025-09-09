// lib/widgets/fancy_paint_tile.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart' show Paint;
import 'package:color_canvas/utils/color_utils.dart';
import '../theme.dart';

class FancyPaintTile extends StatefulWidget {
  final Paint paint;

  /// First tap shows overlay; second tap (while overlay is visible) calls onOpen.
  final VoidCallback onOpen;

  /// Optional: long-press (mobile) / right-click (desktop) affordance, e.g., toggle compare.
  final VoidCallback? onLongPress;

  /// Optional: tiny pill button in the corner (e.g., quick Roller).
  final VoidCallback? onQuickRoller;

  /// If the item is selected for compare, we show a check badge.
  final bool selected;

  /// When true, tighter padding/smaller corner to fit denser grids.
  final bool dense;

  const FancyPaintTile({
    super.key,
    required this.paint,
    required this.onOpen,
    this.onLongPress,
    this.onQuickRoller,
    this.selected = false,
    this.dense = false,
  });

  @override
  State<FancyPaintTile> createState() => _FancyPaintTileState();
}

class _FancyPaintTileState extends State<FancyPaintTile> {
  final GlobalKey _tileKey = GlobalKey();

  bool _peeked = false; // overlay shown
  bool _hovered = false; // desktop hover lift
  Timer? _peekTimer;

  // Parallax tilt (radians)
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  static const double _kMaxTilt = 0.08; // ~4.5°
  static const double _kPerspective = 0.0015;

  @override
  void dispose() {
    _peekTimer?.cancel();
    super.dispose();
  }

  void _showPeek() {
    _peekTimer?.cancel();
    setState(() => _peeked = true);
    _peekTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _peeked = false);
    });
  }

  void _onTap() {
    if (!_peeked) {
      _showPeek();
      return;
    }
    widget.onOpen();
  }

  void _updateTiltFromLocal(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // Normalize to [-1, 1]
    final dx = (local.dx / size.width) * 2 - 1;
    final dy = (local.dy / size.height) * 2 - 1;
    setState(() {
      _tiltY = dx * _kMaxTilt; // left/right → rotateY
      _tiltX = -dy * _kMaxTilt; // up/down   → rotateX (invert feels natural)
    });
  }

  void _tiltFromGlobal(Offset globalPosition) {
    final box = _tileKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    _updateTiltFromLocal(local, box.size);
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  Color _tint(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = ColorUtils.getPaintColor(widget.paint.hex);
    final radius = widget.dense ? AppDims.radiusMedium : AppDims.radiusLarge;

    final borderGradA = _tint(base, 0.16);
    final borderGradB = _shade(base, 0.18);

    final lift = _hovered || _peeked;

    final tiltMatrix = Matrix4.identity()
      ..setEntry(3, 2, _kPerspective)
      ..rotateX(_tiltX)
      ..rotateY(_tiltY);

    return RepaintBoundary(
      child: MouseRegion(
        onHover: (e) {
          _tiltFromGlobal(e.position);
          if (!_hovered) setState(() => _hovered = true);
        },
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) {
          setState(() => _hovered = false);
          _resetTilt();
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: lift ? 1.02 : 1.0,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            key: _tileKey,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: tiltMatrix,
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius + 3),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [borderGradA, borderGradB],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: lift ? 0.18 : 0.12),
                  blurRadius: lift ? 22 : 16,
                  spreadRadius: 0,
                  offset: Offset(0, lift ? 10 : 8),
                ),
                BoxShadow(
                  color: base.withValues(alpha: lift ? 0.18 : 0.12),
                  blurRadius: lift ? 28 : 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0), // gradient “border”
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: base)),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.07),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Peek overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: AnimatedOpacity(
                          opacity: _peeked ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.0),
                                  Colors.black.withValues(alpha: 0.25),
                                  Colors.black.withValues(alpha: 0.45),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.paint.brandName} • ${widget.paint.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to open',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.selected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.check_circle,
                              size: 18,
                              color: theme.colorScheme.inversePrimary),
                        ),
                      ),
                    if (widget.onQuickRoller != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: lift ? 1 : 0,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: widget.onQuickRoller,
                            icon: const Icon(Icons.colorize, size: 16),
                            label:
                                const Text('Roll', overflow: TextOverflow.fade),
                          ),
                        ),
                      ),
                    // Gesture layer
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: Colors.white.withValues(alpha: 0.08),
                        highlightColor: Colors.white.withValues(alpha: 0.04),
                        onTap: _onTap,
                        onLongPress: widget.onLongPress,
                        onTapDown: (d) {
                          setState(() => _hovered = true);
                          _tiltFromGlobal(d.globalPosition);
                        },
                        onTapUp: (_) {
                          setState(() => _hovered = false);
                          _resetTilt();
                        },
                        onTapCancel: () {
                          setState(() => _hovered = false);
                          _resetTilt();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
