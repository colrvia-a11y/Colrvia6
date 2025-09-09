import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/roller/roller_state.dart';
import 'package:color_canvas/widgets/paint_column.dart';

/// Minimal feed UI that delegates generation & state to [RollerController].
class RollerFeed extends ConsumerStatefulWidget {
  const RollerFeed({super.key});

  @override
  ConsumerState<RollerFeed> createState() => _RollerFeedState();
}

class _RollerFeedState extends ConsumerState<RollerFeed> {
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    // ensure first page exists
    Future.microtask(() => ref.read(rollerControllerProvider.notifier).initIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rollerControllerProvider);

    return async.when(
      data: (s) => _buildBody(context, s),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
    );
  }

  Widget _buildBody(BuildContext context, RollerState s) {
    if (!s.hasPages && s.status == RollerStatus.idle) {
      // Kick first roll
      Future.microtask(() => ref.read(rollerControllerProvider.notifier).rollNext());
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      onPageChanged: (i) => ref.read(rollerControllerProvider.notifier).onPageChanged(i),
      itemCount: s.pages.length,
      itemBuilder: (context, index) {
        final page = s.pages[index];
        return Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < page.strips.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () => ref
                            .read(rollerControllerProvider.notifier)
                            .useNextAlternateForStrip(i),
                        child: Semantics(
                          label: 'Strip ${i + 1}: ${page.locks[i] ? 'locked' : 'unlocked'}',
                          button: true,
                          child: Tooltip(
                            message: 'Tap to lock/unlock · Double-tap for alternate',
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: PaintStripe(
                                    paint: page.strips[i],
                                    isLocked: page.locks[i],
                                    onTap: () => ref.read(rollerControllerProvider.notifier).toggleLock(i),
                                    onLongPress: () => ref.read(rollerControllerProvider.notifier).toggleLock(i),
                                  ),
                                ),
                                if (page.locks[i])
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.lock, size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BottomBar(index: index, isBusy: s.generatingPages.contains(index)),
          ],
        );
      },
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final int index;
  final bool isBusy;
  const _BottomBar({required this.index, required this.isBusy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: isBusy ? null : () => ref.read(rollerControllerProvider.notifier).rerollCurrent(),
            icon: const Icon(Icons.casino),
            label: Text(isBusy ? 'Rolling…' : 'Roll'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => ref.read(rollerControllerProvider.notifier).rollNext(),
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Next'),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showFilters(context, ref),
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context, WidgetRef ref) {
    final s = ref.read(rollerControllerProvider).valueOrNull;
    if (s == null) return;
    final TextEditingController brandsCtrl =
        TextEditingController(text: s.filters.brandIds.join(','));
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

class _ErrorView extends ConsumerWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                ref.read(rollerControllerProvider.notifier).clearError();
                await ref.read(rollerControllerProvider.notifier).rollNext();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
