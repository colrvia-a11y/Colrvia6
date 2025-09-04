import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'analytics_service.dart';
import 'sync_queue_service.dart';

class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  final List<String> _breadcrumbs = [];

  void logBreadcrumb(String message) {
    final entry = '${DateTime.now().toIso8601String()} $message';
    _breadcrumbs.add(entry);
    if (_breadcrumbs.length > 50) _breadcrumbs.removeAt(0);
    FirebaseCrashlytics.instance.log(message);
  }

  List<String> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  Future<String> buildReport() async {
    final events = AnalyticsService.instance.recentEvents
        .map((e) => '${e['ts']} ${e['name']} ${e['params']}')
        .join('\n');
    final pending = await SyncQueueService.instance.listPending();
    return 'events:\n$events\n\nbreadcrumbs:\n${_breadcrumbs.join('\n')}\n\npending:${pending.length}';
  }
}
