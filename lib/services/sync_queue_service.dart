import 'dart:async';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'analytics_service.dart';

typedef SyncHandler = Future<void> Function(Map<String, dynamic> payload);

class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService instance = SyncQueueService._();

  final Map<String, SyncHandler> _handlers = {};
  Box<Map>? _box;

  Future<void> _ensureBox() async {
    if (_box != null) return;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }
    _box = await Hive.openBox<Map>('sync_queue');
  }

  void registerHandler(String opType, SyncHandler handler) {
    _handlers[opType] = handler;
  }

  Future<void> enqueue(String opType, Map<String, dynamic> payload) async {
    await _ensureBox();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _box!.put(id, {
      'id': id,
      'opType': opType,
      'payload': payload,
      'retries': 0,
    });
    AnalyticsService.instance
        .log('offline_enqueued', {'opType': opType});
    final context = MyApp.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved offline; will sync later')),
      );
    }
  }

  Future<void> replay() async {
    await _ensureBox();
    final entries = _box!.values.toList();
    for (final e in entries) {
      final opType = e['opType'] as String;
      final handler = _handlers[opType];
      if (handler == null) continue;
      try {
        await handler(Map<String, dynamic>.from(e['payload'] as Map));
        await _box!.delete(e['id']);
        AnalyticsService.instance
            .log('offline_replayed', {'opType': opType, 'success': true});
      } catch (err) {
        final retries = (e['retries'] as int) + 1;
        await _box!.put(e['id'], {
          ...e,
          'retries': retries,
          'lastError': err.toString(),
        });
        AnalyticsService.instance.log(
            'offline_replayed', {'opType': opType, 'success': false});
      }
    }
  }

  Future<List<Map<String, dynamic>>> listPending() async {
    await _ensureBox();
    return _box!.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
