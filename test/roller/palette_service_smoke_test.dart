import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate returns 5 paints and respects anchors', () async {
    final repo = PaintRepository();
    final svc = PaletteService();
    final all = await repo.getAll();
    final anchors = List<Paint?>.filled(5, null);
    anchors[0] = all.first; // lock first strip

    final out = await svc.generate(
      available: all,
      anchors: anchors,
      diversifyBrands: true,
      mode: HarmonyMode.colrvia,
    );
    expect(out.length, 5);
    expect(out.first.id, anchors[0]!.id);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
