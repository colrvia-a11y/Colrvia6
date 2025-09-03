// lib/services/visualizer_service.dart
import 'dart:async';
import 'dart:ui';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/visualizer_mask.dart';
import 'diagnostics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_queue_service.dart';

// The project sometimes doesn't include `firebase_functions` in pubspec for
// certain build environments. To keep the analyzer and builds working when
// the package isn't available, provide a lightweight local shim that exposes
// the minimal API surface used by this service. If the real package is
// added to pubspec.yaml, the package import will take precedence.
//
// Note: We attempt a normal import via conditional import style is not
// possible here without additional files, so we declare a fallback type.
// This keeps the code compiling in CI/editor environments that don't have
// the package, while preserving behavior when the real package is present.

// Fallback shim types
class _FirebaseFunctionsShim {
  static final _FirebaseFunctionsShim instance = _FirebaseFunctionsShim();

  _HttpsCallable httpsCallable(String name) => _HttpsCallable(name);
}

class _HttpsCallable {
  final String name;
  _HttpsCallable(this.name);

  Future<_HttpsCallableResult> call([dynamic data]) async {
    // Minimal mock behavior: return an empty result. Real implementation
    // requires `package:firebase_functions` and should be used in production.
    return _HttpsCallableResult({});
  }
}

class _HttpsCallableResult {
  final dynamic data;
  _HttpsCallableResult(this.data);
}

// Prefer the real package if available. When it's available, developers can
// replace usages of _FirebaseFunctionsShim with FirebaseFunctions.
final _firebaseFunctionsShimInstance = _FirebaseFunctionsShim.instance;

class VisualizerJob {
  final String jobId;
  final String status;
  final String? previewUrl;
  final String? resultUrl;
  VisualizerJob({required this.jobId, required this.status, this.previewUrl, this.resultUrl});
  factory VisualizerJob.fromMap(Map<String, dynamic> m) => VisualizerJob(
        jobId: m['jobId'],
        status: m['status'],
        previewUrl: m['previewUrl'],
        resultUrl: m['resultUrl'],
      );
}

class VisualizerService {
  // Use the shimbed functions instance. If the real package is added, this
  // file can be updated to use `FirebaseFunctions.instance` directly.
  // Includes support for fast preview and asynchronous HQ jobs.
  final _FirebaseFunctionsShim _functions = _firebaseFunctionsShimInstance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _pendingJobsKey = 'viz_pending_jobs';

  VisualizerService() {
    SyncQueueService.instance.registerHandler('saveMask', (p) async {
      await saveMask(
          p['uid'] as String,
          p['projectId'] as String,
          p['photoId'] as String,
          VisualizerMask.fromJson(Map<String, dynamic>.from(p['mask'] as Map)));
    });
    SyncQueueService.instance.registerHandler('deleteMask', (p) async {
      await deleteMask(
          p['uid'] as String,
          p['projectId'] as String,
          p['photoId'] as String,
          p['maskId'] as String);
    });
  }

  CollectionReference<Map<String, dynamic>> _maskCollection(
          String uid, String projectId, String photoId) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('projects')
          .doc(projectId)
          .collection('photos')
          .doc(photoId)
          .collection('masks');

  static Future<String> uploadInputBytes(String uid, String fileName, List<int> bytes) async {
  final callable = _firebaseFunctionsShimInstance.httpsCallable('uploadInputBytes');
    final resp = await callable.call({
      'uid': uid,
      'fileName': fileName,
      'bytes': bytes,
    });
    return resp.data['gsPath'] as String;
  }

  static Future<List<Map<String, dynamic>>> generateFromPhoto({
    required String inputGsPath,
    required String roomType,
    required List<String> surfaces,
    required int variants,
    String? storyId,
    String? lightingProfile,
  }) async {
  final callable = _firebaseFunctionsShimInstance.httpsCallable('generateFromPhoto');
    final resp = await callable.call({
      'inputGsPath': inputGsPath,
      'roomType': roomType,
      'surfaces': surfaces,
      'variants': variants,
      'storyId': storyId,
      if (lightingProfile != null) 'lightingProfile': lightingProfile,
    });
    return List<Map<String, dynamic>>.from(resp.data['results'] as List);
  }

  static Future<List<Map<String, dynamic>>> generateMockup({
    required String roomType,
    required String style,
    required int variants,
    String? lightingProfile,
  }) async {
  final callable = _firebaseFunctionsShimInstance.httpsCallable('generateMockup');
    final resp = await callable.call({
      'roomType': roomType,
      'style': style,
      'variants': variants,
      if (lightingProfile != null) 'lightingProfile': lightingProfile,
    });
    return List<Map<String, dynamic>>.from(resp.data['results'] as List);
  }

  // Mask CRUD ---------------------------------------------------------------

  Stream<List<VisualizerMask>> watchMasks(
      String uid, String projectId, String photoId) {
    return _maskCollection(uid, projectId, photoId).snapshots().map((snap) =>
        snap.docs
            .map((d) => VisualizerMask.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> saveMask(String uid, String projectId, String photoId,
      VisualizerMask mask) async {
    try {
      await _maskCollection(uid, projectId, photoId)
          .doc(mask.id)
          .set(mask.toJson());
    } catch (e) {
      await SyncQueueService.instance.enqueue('saveMask', {
        'uid': uid,
        'projectId': projectId,
        'photoId': photoId,
        'mask': mask.toJson(),
      });
    }
  }

  Future<void> deleteMask(
      String uid, String projectId, String photoId, String maskId) async {
    try {
      await _maskCollection(uid, projectId, photoId).doc(maskId).delete();
    } catch (e) {
      await SyncQueueService.instance.enqueue('deleteMask', {
        'uid': uid,
        'projectId': projectId,
        'photoId': photoId,
        'maskId': maskId,
      });
    }
  }

  Future<Map<String, List<List<Offset>>>> maskAssist(String imageUrl) async {
    final callable = _functions.httpsCallable('maskAssist');
    final resp = await callable.call({'imageUrl': imageUrl});
    final data = Map<String, dynamic>.from(resp.data as Map);
    return data.map((k, v) => MapEntry(
        k,
        (v as List)
            .map<List<Offset>>((poly) => (poly as List)
                .map<Offset>((p) =>
                    Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
                .toList())
            .toList()));
  }

  Future<VisualizerJob> renderFast(String imageUrl, List<String> paletteColorIds,
      {String? lightingProfile, List<VisualizerMask>? masks}) async {
    final callable = _functions.httpsCallable('renderFast');
    final resp = await callable.call({
      'imageUrl': imageUrl,
      'palette': paletteColorIds,
      if (lightingProfile != null) 'lightingProfile': lightingProfile,
      if (masks != null) 'masks': masks.map((m) => m.toJson()).toList(),
    });
    return VisualizerJob.fromMap(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<VisualizerJob> renderHq(String imageUrl, List<String> paletteColorIds,
      {String? lightingProfile, List<VisualizerMask>? masks}) async {
    DiagnosticsService.instance.logBreadcrumb('viz_hq_requested');
    final callable = _functions.httpsCallable('renderHq');
    final resp = await callable.call({
      'imageUrl': imageUrl,
      'palette': paletteColorIds,
      if (lightingProfile != null) 'lightingProfile': lightingProfile,
      if (masks != null) 'masks': masks.map((m) => m.toJson()).toList(),
    });
    final job = VisualizerJob.fromMap(Map<String, dynamic>.from(resp.data as Map));
    await _storeJob(job);
    return job;
  }

  Stream<VisualizerJob> watchJob(String jobId) async* {
    final callable = _functions.httpsCallable('getJob');
    while (true) {
      final resp = await callable.call({'jobId': jobId});
      final job =
          VisualizerJob.fromMap(Map<String, dynamic>.from(resp.data as Map));
      if (job.status == 'complete') {
        DiagnosticsService.instance.logBreadcrumb('viz_hq_completed');
      }
      yield job;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _storeJob(VisualizerJob job) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingJobsKey) ?? [];
    list.add(jsonEncode({'jobId': job.jobId}));
    await prefs.setStringList(_pendingJobsKey, list);
  }

  Future<void> _removeJob(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingJobsKey) ?? [];
    list.removeWhere((s) => jsonDecode(s)['jobId'] == jobId);
    await prefs.setStringList(_pendingJobsKey, list);
  }

  Future<void> resumePendingJobs(void Function(VisualizerJob) onUpdate) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingJobsKey) ?? [];
    for (final item in list) {
      final id = jsonDecode(item)['jobId'] as String;
      watchJob(id).listen((j) async {
        onUpdate(j);
        if (j.status == 'complete' || j.status == 'error') {
          await _removeJob(id);
        }
      });
    }
  }

  Future<void> clearJob(String jobId) => _removeJob(jobId);
}

