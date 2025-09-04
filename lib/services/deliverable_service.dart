import 'package:cloud_functions/cloud_functions.dart';
import 'package:logging/logging.dart';

import 'analytics_service.dart';
import 'journey/journey_service.dart';

class DeliverableService {
  DeliverableService._();
  static final DeliverableService instance = DeliverableService._();

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final _log = Logger('DeliverableService');

  Future<String> exportGuide(String projectId) async {
    final callable = _functions.httpsCallable('exportColorStory');
    try {
      final resp = await callable.call({'projectId': projectId});
      final data = Map<String, dynamic>.from(resp.data as Map);
      final url = data['url'] as String;
      await JourneyService.instance.setArtifact('guideUrl', url);
      await AnalyticsService.instance.logEvent('guide_export_success');
      await JourneyService.instance.completeCurrentStep();
      _log.info('guide_export_success');
      return url;
    } catch (e, st) {
      await AnalyticsService.instance.logEvent('guide_export_fail');
      _log.severe('guide_export_fail', e, st);
      rethrow;
    }
  }
}
