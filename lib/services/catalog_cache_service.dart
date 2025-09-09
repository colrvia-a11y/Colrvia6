import 'dart:async';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  final int version;
  _CacheEntry(
      {required this.value, required this.expiresAt, required this.version});

  Map<String, dynamic> toJson() => {
        'value': value,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'version': version,
      };

  static _CacheEntry? from(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    return _CacheEntry(
      value: json['value'],
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
      version: json['version'] as int,
    );
  }
}

class CatalogCacheService {
  CatalogCacheService._();
  static final CatalogCacheService instance = CatalogCacheService._();

  final Map<String, _CacheEntry> _memory = {};
  final Map<String, Future> _inflight = {};
  Box<Map>? _box;

  Future<void> _ensureBox() async {
    if (_box != null) return;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }
    _box = await Hive.openBox<Map>('catalog_cache');
  }

  Future<T> get<T>(String key, Future<T> Function() loader,
      {Duration ttl = const Duration(hours: 1), int version = 1}) async {
    await _ensureBox();
    final now = DateTime.now();

    final mem = _memory[key];
    if (mem != null && mem.version == version && mem.expiresAt.isAfter(now)) {
      AnalyticsService.instance.logEvent('perf_cache_hit', {'type': 'catalog'});
      return mem.value as T;
    }

    final persisted = _CacheEntry.from(_box!.get(key));
    if (persisted != null &&
        persisted.version == version &&
        persisted.expiresAt.isAfter(now)) {
      _memory[key] = persisted;
      AnalyticsService.instance.logEvent('perf_cache_hit', {'type': 'catalog'});
      return persisted.value as T;
    }

    AnalyticsService.instance.logEvent('perf_cache_miss', {'type': 'catalog'});
    if (_inflight.containsKey(key)) {
      return await _inflight[key] as T;
    }

    final future = loader().then((value) {
      final entry =
          _CacheEntry(value: value, expiresAt: now.add(ttl), version: version);
      _memory[key] = entry;
      _box!.put(key, entry.toJson());
      return value;
    });
    _inflight[key] = future;
    final result = await future;
    _inflight.remove(key);
    return result;
  }
}
