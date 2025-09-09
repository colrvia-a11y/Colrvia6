// lib/widgets/hero_sliver_header.dart
import 'package:flutter/material.dart';

/// Reusable sliver hero header with a background image, centered title/subtitle,
/// and an optional bottom child (usually the TabBar). Use inside a
/// NestedScrollView.headerSliverBuilder.
class HeroSliverHeader {
  /// Returns a sliver representing the hero area.
  ///
  /// [imageUrl] - background image URL
  /// [title]/[subtitle] - centered text shown when expanded
  /// [expandedHeight] - height when expanded
  /// [bottomChild] - widget placed near the bottom of the hero (tab bar)
  static SliverAppBar build({
    required String imageUrl,
    String? title,
    String? subtitle,
    required double expandedHeight,
    Widget? bottomChild,
  }) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: false,
      floating: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ThemeData.light().colorScheme.surface.withAlpha((0.18 * 255).round()),
                      Colors.transparent,
                      Colors.black.withAlpha((0.22 * 255).round()),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              if (title != null || subtitle != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null)
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                          if (subtitle != null) const SizedBox(height: 6),
                          if (subtitle != null)
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (bottomChild != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: bottomChild,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delegate to render a sticky TabBar below the sliver hero. Use with
/// SliverPersistentHeader.pinned = true.
class SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  SliverTabBarDelegate({required this.child, required this.height});

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverTabBarDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}
