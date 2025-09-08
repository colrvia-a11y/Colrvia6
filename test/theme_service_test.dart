import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/roller_theme/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeService loads themes from asset', () async {
    await ThemeService.instance.loadFromAssetIfNeeded();
    final all = ThemeService.instance.all();
    expect(all.length, 5);
    final coastal = ThemeService.instance.byId('coastal');
    expect(coastal, isNotNull);
    expect(coastal!.label, 'Coastal');
  });
}
