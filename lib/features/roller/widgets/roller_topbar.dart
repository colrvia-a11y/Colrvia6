import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_ui_mode.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/favorites/favorite_status_provider.dart';
import 'package:color_canvas/features/favorites/favorites_screen.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';
import 'package:color_canvas/utils/palette_generator.dart';

class RollerTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const RollerTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(rollerModeProvider);
    final rollerState = ref.watch(rollerControllerProvider).valueOrNull;
    final currentThemeLabel = rollerState?.themeSpec?.label ?? 'All';

    return AppBar(
      centerTitle: false,
      titleSpacing: 8,
      title: SizedBox(
        height: kToolbarHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Text('Roller',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ToggleButtons(
                isSelected: [
                  mode == RollerMode.explore,
                  mode == RollerMode.edit
                ],
                onPressed: (i) => ref.read(rollerModeProvider.notifier).state =
                    i == 0 ? RollerMode.explore : RollerMode.edit,
                borderRadius: BorderRadius.circular(12),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 72),
                children: const [
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Explore')),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Edit')),
                ],
              ),
              const SizedBox(width: 8),
              // Theme selector menu
              Consumer(builder: (context, ref, _) {
                final labels = ThemeService.instance.themeLabels();
                final ctrl = ref.read(rollerControllerProvider.notifier);
                return PopupMenuButton<String>(
                  tooltip: 'Theme',
                  onSelected: (value) async {
                    final id = value == 'all' ? null : value;
                    await ctrl.setThemeById(id);
                  },
                  itemBuilder: (_) => [
                    for (final m in labels)
                      PopupMenuItem<String>(
                        value: m['id']!,
                        child: Text(m['label']!),
                      )
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.style),
                        const SizedBox(width: 6),
                        Text('Theme: $currentThemeLabel'),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // NEW: Color Theory picker
              Consumer(builder: (context, ref, _) {
                final s = ref.watch(rollerControllerProvider).valueOrNull;
                final mode = s?.filters.harmonyMode;
                final ctrl = ref.read(rollerControllerProvider.notifier);
                return PopupMenuButton<HarmonyMode>(
                  tooltip: 'Color',
                  onSelected: (m) => ctrl.setHarmonyMode(m),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: HarmonyMode.colrvia, child: Text('ColrVia')),
                    const PopupMenuItem(
                        value: HarmonyMode.analogous, child: Text('Analogous')),
                    const PopupMenuItem(
                        value: HarmonyMode.complementary,
                        child: Text('Complementary')),
                    const PopupMenuItem(
                        value: HarmonyMode.triad, child: Text('Triadic')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Color${mode == null ? '' : ''}'),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // NEW: Count (1..9)
              Consumer(builder: (context, ref, _) {
                final s = ref.watch(rollerControllerProvider).valueOrNull;
                final count = s?.filters.stripCount ?? 5;
                final ctrl = ref.read(rollerControllerProvider.notifier);
                return PopupMenuButton<int>(
                  tooltip: 'Count',
                  onSelected: (v) => ctrl.setStripCount(v),
                  itemBuilder: (_) => [
                    for (int i = 1; i <= 9; i++)
                      PopupMenuItem<int>(value: i, child: Text('$i strips')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Count: $count'),
                  ),
                );
              }),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Help',
                onPressed: () => _showHelp(context),
                icon: const Icon(Icons.help_outline),
              ),
              const SizedBox(width: 8),
              Consumer(builder: (context, ref, _) {
                final isFav =
                    ref.watch(favoriteStatusProvider).asData?.value ?? false;
                final ctrl = ref.read(rollerControllerProvider.notifier);
                return IconButton(
                  tooltip: isFav ? 'Unfavorite' : 'Favorite',
                  onPressed: () async {
                    await ctrl.toggleFavoriteCurrent();
                    // invalidate the favoriteStatusProvider so it re-queries
                    ref.invalidate(favoriteStatusProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isFav
                                ? 'Removed from favorites'
                                : 'Added to favorites')),
                      );
                    }
                  },
                  onLongPress: () {
                    // open favorites list
                    Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FavoritesScreen()));
                  },
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                );
              }),
              const SizedBox(width: 8),
              Consumer(builder: (context, ref, _) {
                final ctrl = ref.read(rollerControllerProvider.notifier);
                return PopupMenuButton<String>(
                  tooltip: 'Copy HEX list',
                  onSelected: (value) async {
                    if (value == 'comma') {
                      await ctrl.copyCurrentHexesToClipboard(CopyFormat.comma);
                    } else if (value == 'newline') {
                      await ctrl
                          .copyCurrentHexesToClipboard(CopyFormat.newline);
                    } else if (value == 'labeled') {
                      await ctrl
                          .copyCurrentHexesToClipboard(CopyFormat.labeled);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('HEX codes copied')),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'comma', child: Text('Comma-separated')),
                    PopupMenuItem(value: 'newline', child: Text('New lines')),
                    PopupMenuItem(
                        value: 'labeled',
                        child: Text('Labeled (brand · name (code) — hex)')),
                  ],
                  icon: const Icon(Icons.copy),
                );
              }),
            ],
          ),
        ),
      ),
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
          Text(
              '• Double‑tap a strip to try another option (or reroll that strip).'),
          SizedBox(height: 4),
          Text('• Use Edit mode for quick actions and filters.'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it')),
      ],
    );
  }
}
