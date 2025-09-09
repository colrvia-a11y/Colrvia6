import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:color_canvas/features/favorites/favorites_repository.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesRepository _repo = FavoritesRepository();
  late Future<List<FavoritePalette>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getAll();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: FutureBuilder<List<FavoritePalette>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No favorites yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              return Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Swatches
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: it.hexes.map((hex) {
                          Color color;
                          try {
                            final cleaned = hex.replaceAll('#', '');
                            color = Color(int.parse('FF$cleaned', radix: 16));
                          } catch (_) {
                            color = Colors.grey;
                          }
                          return Container(
                            width: 36,
                            height: 24,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black12),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 12),
                      // HEXs + date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: it.hexes
                                  .map((h) => Chip(label: Text(h)))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Saved ${DateFormat.yMMMd().add_jm().format(it.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // Delete
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete favorite?'),
                              content: const Text(
                                  'Remove this palette from favorites?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            // remove by toggling (repo toggles existence by key)
                            await _repo.toggle(it);
                            if (mounted) await _reload();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
