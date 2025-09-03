import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/widgets/paint_action_sheet.dart';
import 'package:color_canvas/widgets/color_strip_action_menu.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/utils/debug_logger.dart';

// Enhanced styling configuration for roller strips
class _RollerEnhancements {
  // Master feature flag - change to false to instantly revert all enhancements
  static const bool enableAllEnhancements = true;

  // Individual feature flags (only active if master toggle is true)
  static bool get enableRoundedStrips => enableAllEnhancements && true;
  static bool get enableDragReordering => enableAllEnhancements && true;
  static bool get enableGradientBackdrops => enableAllEnhancements && true;
  static bool get enableEnhancedShadows => enableAllEnhancements && true;
  static bool get enableSubtleBorders => enableAllEnhancements && true;

  // Brand colors matching your design system
  static const Color warmPeach = Color(0xFFF2B897);

  // Enhanced styling constants
  static const double stripBorderRadius = 16.0; // Matching your CTA buttons
  static const double enhancedElevation = 4.0;
  static const double dragElevation = 8.0;
  static const double lockIndicatorRadius = 8.0;
}

class PaintStripe extends StatefulWidget {
  final Paint? paint;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onRefine;
  const PaintStripe({
    super.key,
    this.paint,
    required this.isLocked,
    required this.onTap,
    this.onLongPress,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onRefine,
  });

  @override
  State<PaintStripe> createState() => _PaintStripeState();
}

class _PaintStripeState extends State<PaintStripe> {
  double _dragStartX = 0;
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final color = widget.paint != null
        ? ColorUtils.getPaintColor(widget.paint!.hex)
        : Colors.grey;

    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.paint != null
          ? () => _showActionSheet(context)
          : widget.onLongPress,
      onHorizontalDragStart: (details) {
        _dragStartX = details.localPosition.dx;
        _dragDistance = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDistance = details.localPosition.dx - _dragStartX;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        const minDistance = 24.0;
        const minVelocity = 300.0;

        // Right swipe: positive distance and velocity
        if (_dragDistance > minDistance &&
            velocity > minVelocity &&
            widget.onSwipeRight != null) {
          widget.onSwipeRight!();
        }
        // Left swipe: negative distance and velocity
        else if (_dragDistance < -minDistance &&
            velocity < -minVelocity &&
            widget.onSwipeLeft != null) {
          widget.onSwipeLeft!();
        }

        // Reset drag state
        _dragStartX = 0;
        _dragDistance = 0;
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Stack(
          children: [
            // Lock indicator
            if (widget.isLocked)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

            // Paint information
            if (widget.paint != null)
              Positioned(
                left: widget.isLocked ? 60 : 16,
                top: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand information (roles removed)
                    Text(
                      widget.paint!.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Paint name
                    Text(
                      widget.paint!.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            else
              // Empty state
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tap to roll',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    if (widget.paint == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PaintActionSheet(
        paint: widget.paint!,
        onRefine: widget.onRefine,
      ),
    );
  }
}

class AnimatedPaintStripe extends StatefulWidget {
  final Paint? paint;
  final Paint? previousPaint;
  final bool isLocked;
  final bool isRolling;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onRefine;
  final VoidCallback? onDelete; // New: explicit delete callback
  final int? index; // New: for drag reordering
  final Function(int oldIndex, int newIndex)? onReorder; // New: drag callback

  const AnimatedPaintStripe({
  super.key,
    this.paint,
    this.previousPaint,
    required this.isLocked,
    required this.isRolling,
    required this.onTap,
    this.onLongPress,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onRefine,
    this.onDelete,
    this.index,
    this.onReorder,
  });

  @override
  State<AnimatedPaintStripe> createState() => _AnimatedPaintStripeState();
}

class _AnimatedPaintStripeState extends State<AnimatedPaintStripe>
    with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _dragController; // New: for drag animations
  late AnimationController _lockController; // New: for lock indicator
  late AnimationController _swipeController; // New: for swipe removal animation
  late Animation<Color?> _colorAnimation;
  late Animation<double> _scaleAnimation; // New: for drag scale effect
  late Animation<double> _lockAnimation; // New: for lock indicator
  late Animation<Offset> _swipeAnimation; // New: for swipe removal
  late Animation<double> _fadeAnimation; // New: for swipe fade out

  double _dragDx = 0.0;
  Color? _currentDisplayColor;
  String? _lastPaintId;
  bool _isDragging = false; // New: track drag state
  OverlayEntry? _actionMenuOverlay; // New: track overlay for action menu

  @override
  void initState() {
    super.initState();

    Debug.info('AnimatedPaintStripe', 'initState',
        'Initializing with paint: ${widget.paint?.id}');

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize new animation controllers for enhanced interactions
    if (_RollerEnhancements.enableDragReordering && widget.onReorder != null) {
      _dragController = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );

      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _dragController,
        curve: Curves.easeInOut,
      ));
    }

    _lockController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _lockAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lockController,
      curve: Curves.elasticOut,
    ));

    // Initialize swipe removal animation
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.5, 0), // Slide out to the left
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _updateColorAnimation();
    _currentDisplayColor = widget.paint != null
        ? ColorUtils.getPaintColor(widget.paint!.hex)
        : Colors.grey;
    _lastPaintId = widget.paint?.id;

    // Start animation at end state for initial load
    _colorController.value = 1.0;

    // Initialize lock animation state
    if (widget.isLocked) {
      _lockController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedPaintStripe oldWidget) {
    super.didUpdateWidget(oldWidget);

    Debug.info('AnimatedPaintStripe', 'didUpdateWidget',
        'Old: ${oldWidget.paint?.id}, New: ${widget.paint?.id}, Last: $_lastPaintId');

    // Handle lock state changes with animation
    if (widget.isLocked != oldWidget.isLocked) {
      if (widget.isLocked) {
        _lockController.forward();
        HapticFeedback.selectionClick();
      } else {
        _lockController.reverse();
        HapticFeedback.lightImpact();
      }
    }

    // Consider both id and hex; in sample mode ids may collide or be missing
    final oldKey = oldWidget.paint == null
      ? null
      : '${oldWidget.paint!.id}|${oldWidget.paint!.hex}';
    final newKey = widget.paint == null
      ? null
      : '${widget.paint!.id}|${widget.paint!.hex}';

    // Only animate if effective identity changed and we have a real paint change
    if (oldKey != newKey && 
        _lastPaintId != widget.paint?.id && 
        widget.paint != null) {
        Debug.info('AnimatedPaintStripe', 'didUpdateWidget',
            'Paint changed, starting animation');
        _updateColorAnimation();
        _animateColorChange();
        _lastPaintId = widget.paint?.id;
      }
    
    // Update last paint ID even if we don't animate to prevent future unnecessary animations
    if (widget.paint?.id != null) {
      _lastPaintId = widget.paint?.id;
    }
  }

  void _updateColorAnimation() {
    final previousColor = _currentDisplayColor ?? Colors.grey;
    final currentColor = widget.paint != null
        ? ColorUtils.getPaintColor(widget.paint!.hex)
        : Colors.grey;

    _colorAnimation = ColorTween(
      begin: previousColor,
      end: currentColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOutCubic,
    ));

    // Update current display color for next animation
    _currentDisplayColor = currentColor;
  }

  void _animateColorChange() {
    if (!mounted) return;
    _colorController.reset();
    _colorController.forward();
  }

  @override
  void dispose() {
    _dismissActionMenu();
    _colorController.dispose();
    if (_RollerEnhancements.enableDragReordering && widget.onReorder != null) {
      _dragController.dispose();
    }
    _lockController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  // Create gradient backdrop for rounded corners based on the strip's color
  LinearGradient _createBackdropGradient(Color stripColor) {
    if (!_RollerEnhancements.enableGradientBackdrops) {
      return LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade100]);
    }

    final HSLColor hsl = HSLColor.fromColor(stripColor);
    final lightVariant =
        hsl.withLightness((hsl.lightness + 0.3).clamp(0.0, 1.0)).toColor();
    final darkerVariant =
        hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        lightVariant.withValues(alpha: 0.3),
        stripColor.withValues(alpha: 0.1),
        darkerVariant.withValues(alpha: 0.2),
      ],
    );
  }

  // Create enhanced box shadows for depth
  List<BoxShadow> _createEnhancedShadows(Color stripColor) {
    if (!_RollerEnhancements.enableEnhancedShadows) {
      return [];
    }

    final elevation = _isDragging
        ? _RollerEnhancements.dragElevation
        : _RollerEnhancements.enhancedElevation;

    return [
      BoxShadow(
        color: stripColor.withValues(alpha: 0.2),
        blurRadius: elevation * 2,
        offset: Offset(0, elevation * 0.75),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: elevation,
        offset: Offset(0, elevation * 0.5),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Only log debug info for significant changes to reduce rapid build noise
    if (widget.paint?.id != _lastPaintId || widget.isLocked != (_lockController.value > 0.5)) {
      Debug.build('AnimatedPaintStripe', 'build',
          details:
              'paint: ${widget.paint?.id}, isLocked: ${widget.isLocked}, isRolling: ${widget.isRolling}');
    }

    // Wrap with swipe removal animations
    return AnimatedBuilder(
      animation: _swipeController,
      builder: (context, child) {
        return SlideTransition(
          position: _swipeAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedBuilder(
              animation: Listenable.merge([_colorController, _lockController]),
              builder: (context, child) {
                final color = _colorAnimation.value ??
                    (widget.paint != null
                        ? ColorUtils.getPaintColor(widget.paint!.hex)
                        : Colors.grey);
                final brightness = ThemeData.estimateBrightnessForColor(color);
                final textColor =
                    brightness == Brightness.dark ? Colors.white : Colors.black;

                // Key by effective color identity so Flutter rebuilds properly
                Widget stripContent = Container(
                  margin: _RollerEnhancements.enableRoundedStrips
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: _RollerEnhancements.enableGradientBackdrops
                      ? BoxDecoration(
                          gradient: _createBackdropGradient(color),
                          borderRadius: _RollerEnhancements.enableRoundedStrips
                              ? BorderRadius.circular(
                                  _RollerEnhancements.stripBorderRadius)
                              : null,
                          boxShadow: _createEnhancedShadows(color),
                        )
                      : null,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onTap();
                    },
                    onLongPress: widget.paint != null
                        ? () => _showEnhancedActionMenu(context)
                        : widget.onLongPress,
                    onHorizontalDragStart: (_) => _dragDx = 0.0,
                    onHorizontalDragUpdate: (details) =>
                        _dragDx += details.delta.dx,
                    onHorizontalDragEnd: (details) {
                      final v = details.velocity.pixelsPerSecond.dx;
                      // NEW: Both left and right swipes now navigate through color variations
                      if ((_dragDx > 24) || (v > 500)) {
                        // Right swipe: next color variation
                        if (widget.onSwipeRight != null) {
                          HapticFeedback.lightImpact();
                          widget.onSwipeRight!();
                        }
                      } else if ((_dragDx < -24) || (v < -500)) {
                        // Left swipe: previous color variation (or next if no history)
                        if (widget.onSwipeLeft != null) {
                          HapticFeedback.lightImpact();
                          widget.onSwipeLeft!();
                        }
                      }
                      _dragDx = 0.0;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: _RollerEnhancements.enableRoundedStrips
                            ? BorderRadius.circular(
                                _RollerEnhancements.stripBorderRadius - 2)
                            : null,
                        border: _RollerEnhancements.enableSubtleBorders
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 0.5,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Subtle gradient overlay for depth
                          if (_RollerEnhancements.enableRoundedStrips)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    _RollerEnhancements.stripBorderRadius - 2),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.1),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                            ),

                          // Enhanced lock indicator with animation - NO BRAND COLORS!
                          AnimatedBuilder(
                            animation: _lockAnimation,
                            builder: (context, child) {
                              if (!widget.isLocked ||
                                  _lockAnimation.value == 0) {
                                return const SizedBox.shrink();
                              }

                              return Positioned(
                                left: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Transform.scale(
                                    scale: _lockAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(
                                            _RollerEnhancements
                                                .lockIndicatorRadius),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.lock_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Paint information with enhanced typography
                          if (widget.paint != null)
                            Positioned(
                              left: widget.isLocked ? 60 : 16,
                              top: 0,
                              bottom: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Enhanced brand information
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: textColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.paint!.brandName,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Paint name with enhanced styling
                                  Text(
                                    widget.paint!.name,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                          // Hex value display removed to reduce visual clutter
                        ],
                      ),
                    ),
                  ),
                );

                // Wrap with drag functionality if enabled and preserving long-press
                if (_RollerEnhancements.enableDragReordering &&
                    widget.onReorder != null &&
                    widget.index != null) {
                  return AnimatedBuilder(
                    animation: _dragController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: LongPressDraggable<int>(
                          data: widget.index!,
                          delay: const Duration(
                              milliseconds:
                                  500), // Delay to allow paint info long-press
                          feedback: Material(
                            color: Colors.transparent,
                            child: Transform.scale(
                              scale: 1.1,
                              child: Opacity(
                                opacity: 0.8,
                                child: stripContent,
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: stripContent,
                          ),
                          onDragStarted: () {
                            setState(() => _isDragging = true);
                            _dragController.forward();
                            HapticFeedback.mediumImpact();
                          },
                          onDragEnd: (details) {
                            setState(() => _isDragging = false);
                            _dragController.reverse();
                          },
                          child: DragTarget<int>(
                            onWillAcceptWithDetails: (details) => details.data != widget.index,
                            onAcceptWithDetails: (details) {
                              widget.onReorder!(details.data, widget.index!);
                              HapticFeedback.selectionClick();
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                decoration: candidateData.isNotEmpty
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                            _RollerEnhancements
                                                .stripBorderRadius),
                                        border: Border.all(
                                          color: _RollerEnhancements.warmPeach,
                                          width: 3,
                                        ),
                                      )
                                    : null,
                                child: stripContent,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                }

                return stripContent;
              },
            ),
          ),
        );
      },
    );
  }

  void _showEnhancedActionMenu(BuildContext context) {
    if (widget.paint == null) return;

    // Dismiss any existing overlay
    _dismissActionMenu();

    _actionMenuOverlay = OverlayEntry(
      builder: (context) => ColorStripActionMenu(
        paint: widget.paint!,
        onDelete: widget.onDelete,
        onDetails: () => _showActionSheet(context),
        onCopy: () => _copyPaintData(),
        onPin: () => _pinColor(),
        onReplace: widget.onRefine,
        onDismiss: _dismissActionMenu,
      ),
    );

    Overlay.of(context).insert(_actionMenuOverlay!);
  }

  void _dismissActionMenu() {
    _actionMenuOverlay?.remove();
    _actionMenuOverlay = null;
  }

  void _copyPaintData() {
    if (widget.paint == null) return;
    
    final data = '${widget.paint!.name}\n${widget.paint!.brandName}\n${widget.paint!.code}\n${widget.paint!.hex}';
    Clipboard.setData(ClipboardData(text: data));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paint info copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _pinColor() {
    // Placeholder for pin/favorite functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Color pinned'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    if (widget.paint == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PaintActionSheet(
        paint: widget.paint!,
        onRefine: widget.onRefine,
      ),
    );
  }
}
