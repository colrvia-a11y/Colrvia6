import 'dart:math';
import 'dart:io';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/features/roller/paint_repository.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

Future<void> main() async {
  final repo = PaintRepository();
  final svc = PaletteService();
  final all = await repo.getAll();
  final rand = Random(42);
  Duration total = Duration.zero;
  const runs = 10;

  for (var i = 0; i < runs; i++) {
    final anchors = List<Paint?>.filled(5, null);
    // random single anchor ~30% of time
    if (rand.nextDouble() < 0.3) anchors[rand.nextInt(5)] = all[rand.nextInt(all.length)];
    final sw = Stopwatch()..start();
    final out = await svc.generate(available: all, anchors: anchors, diversifyBrands: true);
    sw.stop();
    total += sw.elapsed;
    stdout.writeln('Run ${i + 1}: ${sw.elapsed.inMilliseconds} ms (first=${out.first.id})');
  }

  stdout.writeln('Avg: ${(total.inMilliseconds / runs).toStringAsFixed(1)} ms over $runs runs');
}

