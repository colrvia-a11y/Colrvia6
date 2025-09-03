// lib/widgets/staggered_entrance.dart
import 'package:flutter/material.dart';

class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double verticalOffset;
  final double initialScale;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 0),
    this.duration = const Duration(milliseconds: 380),
    this.verticalOffset = 18.0,
    this.initialScale = 0.98,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) {
        final p = _t.value;
        final dy = (1 - p) * widget.verticalOffset;
        final scale = widget.initialScale + (1 - widget.initialScale) * p;
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
