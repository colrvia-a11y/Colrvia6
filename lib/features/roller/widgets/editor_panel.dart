import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';

class EditorPanel extends ConsumerWidget {
  final bool visible;
  const EditorPanel({super.key, required this.visible});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(rollerControllerProvider).valueOrNull;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1 : 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 200, maxHeight: 380),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, size: 18),
                            const SizedBox(width: 8),
                            Text('Editor', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Filters',
                              onPressed: () => _openFilters(context, ref),
                              icon: const Icon(Icons.filter_alt_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => ref.read(rollerControllerProvider.notifier).rerollCurrent(),
                              icon: const Icon(Icons.casino),
                              label: const Text('Roll'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => ref.read(rollerControllerProvider.notifier).rollNext(),
                              icon: const Icon(Icons.arrow_downward),
                              label: const Text('Next'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => ref.read(rollerControllerProvider.notifier).unlockAll(),
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Unlock all'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await ref.read(rollerControllerProvider.notifier).toggleFavoriteCurrent();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Toggled favorite for current palette')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.favorite_border),
                              label: const Text('Favorite'),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Copy HEX',
                              onSelected: (value) async {
                                final ctrl = ref.read(rollerControllerProvider.notifier);
                                if (value == 'comma') {
                                  await ctrl.copyCurrentHexesToClipboard(CopyFormat.comma);
                                } else if (value == 'newline') {
                                  await ctrl.copyCurrentHexesToClipboard(CopyFormat.newline);
                                } else if (value == 'labeled') {
                                  await ctrl.copyCurrentHexesToClipboard(CopyFormat.labeled);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('HEX copied')),
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'comma', child: Text('Comma-separated')),
                                PopupMenuItem(value: 'newline', child: Text('New lines')),
                                PopupMenuItem(value: 'labeled', child: Text('Labeled (brand · name (code) — hex)')),
                              ],
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy HEX'),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (s?.currentPage != null)
                          Expanded(
                            child: ListView.separated(
                              itemCount: s!.currentPage!.strips.length,
                              separatorBuilder: (_, __) => const Divider(height: 12),
                              itemBuilder: (context, i) {
                                final isLocked = s.currentPage!.locks[i];
                                return Row(
                                  children: [
                                    Text('Strip ${i + 1}'),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: isLocked ? 'Unlock' : 'Lock',
                                      onPressed: () => ref.read(rollerControllerProvider.notifier).toggleLock(i),
                                      icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                                    ),
                                    IconButton(
                                      tooltip: 'Alternate',
                                      onPressed: () => ref.read(rollerControllerProvider.notifier).useNextAlternateForStrip(i),
                                      icon: const Icon(Icons.swap_horiz),
                                    ),
                                    IconButton(
                                      tooltip: 'Reroll this strip',
                                      onPressed: () => ref.read(rollerControllerProvider.notifier).rerollStrip(i),
                                      icon: const Icon(Icons.autorenew),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFilters(BuildContext context, WidgetRef ref) {
    // Reuse the feed's bottom sheet by calling the same method if it is public, or replicate a minimal version.
    final s = ref.read(rollerControllerProvider).valueOrNull;
    if (s == null) return;
    final TextEditingController brandsCtrl = TextEditingController(text: s.filters.brandIds.join(','));
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Brand IDs (comma-separated)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: brandsCtrl),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final ids = brandsCtrl.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet();
                  ref.read(rollerControllerProvider.notifier).setFilters(
                        s.filters.copyWith(brandIds: ids),
                      );
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }
}
