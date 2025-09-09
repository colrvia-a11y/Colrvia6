import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/roller_controller.dart';
import 'package:color_canvas/features/roller/roller_state.dart';

/// Provides a reactive boolean indicating whether the current visible
/// palette (from `rollerControllerProvider`) is saved as a favorite.
///
/// It listens to changes in the roller state (visible page / pages)
/// and queries `FavoritesRepository.isFavorite(key)` to emit the
/// current value. The stream will re-query whenever the roller
/// state's relevant properties change.
final favoriteStatusProvider = StreamProvider<bool>((ref) {
  // create a controller to emit boolean updates
  final controller = StreamController<bool>();

  // helper: query current state and add to stream
  Future<void> emitCurrent() async {
    try {
      final ctrl = ref.read(rollerControllerProvider.notifier);
      final isFav = await ctrl.isCurrentFavorite();
      if (!controller.isClosed) controller.add(isFav);
    } catch (_) {
      if (!controller.isClosed) controller.add(false);
    }
  }

  // Emit initial value
  emitCurrent();

  // Re-emit whenever roller controller state object changes.
  // ref.listen is scoped and will be cleaned up automatically when
  // this provider is disposed, so we don't need to store/close a
  // subscription here.
  ref.listen<AsyncValue<RollerState>>(rollerControllerProvider, (_, __) {
    emitCurrent();
  });

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});
