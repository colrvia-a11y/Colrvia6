import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/widgets/roller_feed.dart';
import 'package:color_canvas/features/roller/widgets/roller_topbar.dart';
import 'package:color_canvas/features/roller/widgets/editor_panel.dart';
import 'package:color_canvas/features/roller/roller_ui_mode.dart';

class RollerScreen extends ConsumerWidget {
  const RollerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(rollerModeProvider);

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
