// Test Firebase AI services integration
import 'package:logging/logging.dart';
import 'lib/services/firebase_ai_service.dart';
import 'lib/services/google_ai_service.dart';

void main() async {
  // Set up logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Use debugPrint for test output instead of print
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('AITest');

  try {
    logger.info('Testing Firebase AI services integration...');

    // Note: Firebase initialization would normally be done in main.dart
    // await Firebase.initializeApp();

    // Initialize AI services
    await FirebaseAIService.initialize();
    await GoogleAIService.initialize();

    logger.info('Firebase AI services initialized successfully!');

    // Test connection to both services
    logger.info('Testing Firebase AI connection...');
    final firebaseConnected = await FirebaseAIService.testConnection();
    logger.info(
        'Firebase AI connection: ${firebaseConnected ? 'SUCCESS' : 'FAILED'}');

    logger.info('Testing Google AI connection...');
    final googleConnected = await GoogleAIService.testConnection();
    logger.info(
        'Google AI connection: ${googleConnected ? 'SUCCESS' : 'FAILED'}');

    logger.info('AI services test completed!');
  } catch (e) {
    logger.severe('Error testing AI services: $e');
  }
}
