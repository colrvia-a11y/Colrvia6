import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (rect) {
            final g = LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _c.value, 0),
              end: Alignment(1.0 + 2.0 * _c.value, 0),
              colors: [Colors.transparent, Colors.white.withValues(alpha: .35), Colors.transparent],
              stops: const [0.25, 0.5, 0.75],
            );
            return g.createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class ShimmerGrid extends StatelessWidget {
  final int crossAxisCount;
  final double mainAxisExtent;
  final EdgeInsets padding;
  const ShimmerGrid({super.key, this.crossAxisCount = 2, this.mainAxisExtent = 220, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: mainAxisExtent),
      itemBuilder: (_, __) => const _SkeletonCard(),
      itemCount: 8,
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .6);
    return Shimmer(
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Container(height: 140, decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 14, width: 120, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 12, width: 160, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6))),
            ]),
          )),
        ]),
      ),
    );
  }
}
