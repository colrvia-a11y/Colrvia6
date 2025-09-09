// Test Firebase AI service using Cloud Functions
import 'package:logging/logging.dart';
import 'lib/services/firebase_ai_service.dart';
import 'lib/firestore/firestore_data_schema.dart';

void main() async {
  // Set up logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Using stdout.writeln instead of print for logging output
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('FirebaseAITest');

  try {
    logger.info('Testing Firebase AI service...');

    // Initialize Firebase AI service
    await FirebaseAIService.initialize();
    logger.info('Firebase AI service initialized');

    // Test connection
    logger.info('Testing Firebase AI connection...');
    final connected = await FirebaseAIService.testConnection();
    logger.info('Firebase AI connection: ${connected ? 'SUCCESS' : 'FAILED'}');

    // Test color story generation with sample data
    logger.info('Testing color story generation...');
    try {
      final sampleColors = [
        Paint(
          id: '1',
          brandId: 'sw',
          brandName: 'Sherwin-Williams',
          name: 'Agreeable Gray',
          code: 'SW 7029',
          hex: '#D4C4A8',
          rgb: [212, 196, 168],
          lab: [80.0, 2.0, 15.0],
          lch: [80.0, 15.1, 82.9],
          finish: 'eggshell',
        ),
        Paint(
          id: '2',
          brandId: 'bm',
          brandName: 'Benjamin Moore',
          name: 'Classic Gray',
          code: 'OC-23',
          hex: '#B8B7A8',
          rgb: [184, 183, 168],
          lab: [75.0, 0.0, 8.0],
          lch: [75.0, 8.0, 90.0],
          finish: 'satin',
        ),
      ];

      final story = await FirebaseAIService.generateColorStory(
        colors: sampleColors,
        room: 'living room',
        style: 'modern',
        vibeWords: ['cozy', 'elegant', 'sophisticated'],
      );
      logger.info(
          'Color story generated successfully: ${story.substring(0, 50)}...');
    } catch (e) {
      logger.warning(
          'Color story generation failed (expected if Cloud Functions not deployed): $e');
    }

    logger.info('Firebase AI service test completed!');
  } catch (e) {
    logger.severe('Error testing Firebase AI service: $e');
  }
}
