import 'package:flutter/material.dart';
import 'package:color_canvas/models/user_palette.dart';
import 'package:color_canvas/services/analytics_service.dart';

class CompareScreen extends StatelessWidget {
  final UserPalette? comparePalette;

  const CompareScreen({
    super.key,
    this.comparePalette,
  });

  @override
  Widget build(BuildContext context) {
    // Track screen view
    AnalyticsService.instance.logScreenView('Compare Colors');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Colors'),
      ),
      body: comparePalette == null
          ? const Center(
              child: Text('No palette selected for comparison'),
            )
          : ColorPaletteView(palette: comparePalette!),
    );
  }
}

class ColorPaletteView extends StatelessWidget {
  final UserPalette palette;

  const ColorPaletteView({
    super.key,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: palette.colors.length,
      itemBuilder: (context, index) {
        return ColorTile(color: palette.colors[index]);
      },
    );
  }
}

class ColorTile extends StatelessWidget {
  final Color color;

  const ColorTile({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
