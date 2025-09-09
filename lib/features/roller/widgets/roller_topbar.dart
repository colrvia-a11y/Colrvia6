import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_ui_mode.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';

class RollerTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const RollerTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(rollerModeProvider);

    return AppBar(
      title: const Text('Roller'),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ToggleButtons(
            isSelected: [mode == RollerMode.explore, mode == RollerMode.edit],
            onPressed: (i) => ref.read(rollerModeProvider.notifier).state =
                i == 0 ? RollerMode.explore : RollerMode.edit,
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 72),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Explore')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Edit')),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Help',
          onPressed: () => _showHelp(context),
          icon: const Icon(Icons.help_outline),
        ),
        Consumer(builder: (context, ref, _) {
          final ctrl = ref.read(rollerControllerProvider.notifier);
          return FutureBuilder<bool>(
            future: ctrl.isCurrentFavorite(),
            builder: (context, snap) {
              final fav = snap.data == true;
              return IconButton(
                tooltip: fav ? 'Unfavorite' : 'Favorite',
                onPressed: () async {
                  await ctrl.toggleFavoriteCurrent();
                  // Force rebuild to reflect new state
                  (context as Element).markNeedsBuild();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(fav ? 'Removed from favorites' : 'Added to favorites')),
                    );
                  }
                },
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
              );
            },
          );
        }),
        Consumer(builder: (context, ref, _) {
          return IconButton(
            tooltip: 'Copy HEX list',
            onPressed: () async {
              await ref.read(rollerControllerProvider.notifier).copyCurrentHexesToClipboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('HEX codes copied')),
                );
              }
            },
            icon: const Icon(Icons.copy),
          );
        }),
      ],
    );
  }
}

void _showHelp(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _HelpDialog(),
  );
}

class _HelpDialog extends StatelessWidget {
  const _HelpDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Roller tips'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• Swipe vertically to browse history.'),
          SizedBox(height: 4),
          Text('• Tap a strip to lock/unlock it.'),
          SizedBox(height: 4),
          Text('• Double‑tap a strip to try another option (or reroll that strip).'),
          SizedBox(height: 4),
          Text('• Use Edit mode for quick actions and filters.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
      ],
    );
  }
}
