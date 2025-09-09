// Test file to verify package imports
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

void main() {
  // Set up logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  testImports();
}

void testImports() {
  final logger = Logger('Test');
  logger.info('Packages are working correctly');

  // Test rootBundle access (verify it's accessible)
  try {
    final bundle = rootBundle;
    logger
        .info('rootBundle is available and accessible: ${bundle.runtimeType}');
  } catch (e) {
    logger.warning('rootBundle access failed: $e');
  }
}
