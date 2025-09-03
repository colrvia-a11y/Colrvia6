// lib/services/performance_service.dart
import 'package:firebase_performance/firebase_performance.dart';

class Perf {
  static Future<T> traceAsync<T>(String name, Future<T> Function() fn) async {
    final t = FirebasePerformance.instance.newTrace(name);
    await t.start();
    try {
      return await fn();
    } finally {
      await t.stop();
    }
  }
}
