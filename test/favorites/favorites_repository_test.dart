import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:color_canvas/features/favorites/favorites_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesRepository', () {
    test('toggle adds and removes favorite', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FavoritesRepository();
      final item = FavoritePalette(key: 'k1', paintIds: ['p1', 'p2'], hexes: ['#111', '#222']);
      await repo.toggle(item);
      var all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.key, 'k1');

      // toggle again should remove
      await repo.toggle(item);
      all = await repo.getAll();
      expect(all.isEmpty, true);
    });

    test('getAll handles empty and malformed prefs gracefully', () async {
      // empty
      SharedPreferences.setMockInitialValues({});
      final repo = FavoritesRepository();
      var all = await repo.getAll();
      expect(all.isEmpty, true);

      // malformed
      SharedPreferences.setMockInitialValues({'roller_favorites_v1': 'not-json'});
      all = await repo.getAll();
      expect(all.isEmpty, true);
    });
  });
}
