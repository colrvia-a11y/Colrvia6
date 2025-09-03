// lib/services/palette_service.dart
import 'package:firebase_functions/firebase_functions.dart';
import 'package:color_canvas/services/journey/journey_service.dart';

class PaletteService {
  PaletteService._();
  static final instance = PaletteService._();

  final _fn = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('generatePaletteOnCall');

  Future<Map<String, dynamic>> generateFromAnswers(Map<String, dynamic> answers) async {
    final res = await _fn.call({ 'answers': answers });
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['ok'] != true) throw Exception('Palette generation failed');
    final palette = (data['palette'] as Map).cast<String, dynamic>();

    await JourneyService.instance.setArtifact('palette', palette);
    return palette;
  }
}
