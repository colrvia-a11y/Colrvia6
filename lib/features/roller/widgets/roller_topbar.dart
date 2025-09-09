import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_ui_mode.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/favorites/favorite_status_provider.dart';
import 'package:color_canvas/features/favorites/favorites_screen.dart';

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
          final isFav = ref.watch(favoriteStatusProvider).asData?.value ?? false;
          final ctrl = ref.read(rollerControllerProvider.notifier);
          return IconButton(
            tooltip: isFav ? 'Unfavorite' : 'Favorite',
            onPressed: () async {
              await ctrl.toggleFavoriteCurrent();
              // invalidate the favoriteStatusProvider so it re-queries
              ref.invalidate(favoriteStatusProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isFav ? 'Removed from favorites' : 'Added to favorites')),
                );
              }
            },
            onLongPress: () {
              // open favorites list
              Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
            },
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
          );
        }),
        Consumer(builder: (context, ref, _) {
          final ctrl = ref.read(rollerControllerProvider.notifier);
          return PopupMenuButton<String>(
            tooltip: 'Copy HEX list',
            onSelected: (value) async {
              if (value == 'comma') {
                await ctrl.copyCurrentHexesToClipboard(CopyFormat.comma);
              } else if (value == 'newline') {
                await ctrl.copyCurrentHexesToClipboard(CopyFormat.newline);
              } else if (value == 'labeled') {
                await ctrl.copyCurrentHexesToClipboard(CopyFormat.labeled);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('HEX codes copied')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'comma', child: Text('Comma-separated')),
              PopupMenuItem(value: 'newline', child: Text('New lines')),
              PopupMenuItem(value: 'labeled', child: Text('Labeled (brand · name (code) — hex)')),
            ],
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
