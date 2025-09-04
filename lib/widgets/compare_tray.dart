import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';

class CompareTray extends StatelessWidget {
  final List<Paint> items;
  final VoidCallback onCompare;
  final VoidCallback onClear;
  final void Function(Paint p)? onRemoveOne;
  final void Function(Paint p)? onTapPaint;

  const CompareTray({
    super.key,
    required this.items,
    required this.onCompare,
    required this.onClear,
    this.onRemoveOne,
    this.onTapPaint,
  });

  static const double height = 66;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.18)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 22, offset: const Offset(0, 14))],
            ),
            child: Column(
              children: [
                // soft ridge
                Container(height: 4, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                    Colors.black.withValues(alpha: .06), Colors.transparent
                  ]),
                )),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // mini carousel
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final p = items[i];
                          final c = ColorUtils.getPaintColor(p.hex);
                          return GestureDetector(
                            onTap: onTapPaint == null ? null : () => onTapPaint!(p),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                                  ),
                                ),
                                if (onRemoveOne != null)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: InkWell(
                                      onTap: () => onRemoveOne!(p),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
                                        ),
                                        child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    // actions
                    OutlinedButton(
                      onPressed: onClear,
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: items.length >= 2 ? onCompare : null,
                      icon: const Icon(Icons.compare),
                      label: Text('Compare (${items.length})'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
