import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/widgets/roller_feed.dart';
import 'package:color_canvas/features/roller/widgets/roller_topbar.dart';
import 'package:color_canvas/features/roller/widgets/editor_panel.dart';
import 'package:color_canvas/features/roller/roller_ui_mode.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';

class RollerScreen extends ConsumerWidget {
  const RollerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(rollerModeProvider);

  // Load themes once on open; tolerate missing assets
  Future.microtask(() => ThemeService.instance.loadFromAssetIfNeeded());

    return Scaffold(
      appBar: const RollerTopBar(),
      body: Stack(
        children: [
          const RollerFeed(),
          // Slide-up editor when in Edit mode
          EditorPanel(visible: mode == RollerMode.edit),
        ],
      ),
    );
  }
}
