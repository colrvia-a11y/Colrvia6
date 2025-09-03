import 'package:cloud_functions/cloud_functions.dart';
import 'diagnostics_service.dart';

/// Service for interacting with the Via assistant cloud function.
class ViaService {
  static final ViaService _instance = ViaService._();
  factory ViaService() => _instance;
  ViaService._();

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Fetches a suggestion for the given [contextLabel] and [state].
  Future<String> reply(String contextLabel, Map<String, dynamic> state) async {
    DiagnosticsService.instance.logBreadcrumb('via_used');
    final callable = _functions.httpsCallable('viaReply');
    final resp = await callable.call({'context': contextLabel, 'state': state});
    final data = Map<String, dynamic>.from(resp.data as Map);
    return data['text'] as String? ?? '';
  }
}
