import 'package:firebase_core/firebase_core.dart';

/// Resolves the HTTPS Cloud Functions URL for issuing the Live Talk ephemeral token.
/// Uses the current Firebase app's projectId and the default region.
class VoiceTokenEndpoint {
  /// Default region used by the deployed functions.
  static const String _region = 'us-central1';

  /// Returns the HTTPS URL for the callable gateway that mints the OpenAI
  /// Realtime ephemeral session token.
  /// Example: https://us-central1-<projectId>.cloudfunctions.net/issueVoiceGatewayToken
  static Uri issueVoiceGatewayToken() {
    final opts = Firebase.app().options;
    final projectId = opts.projectId;
    if (projectId.isEmpty) {
      // Fallback to a dummy host to make failures obvious at callsite
      return Uri.parse(
          'https://us-central1-INVALID.cloudfunctions.net/issueVoiceGatewayToken');
    }
    return Uri.parse(
        'https://$_region-$projectId.cloudfunctions.net/issueVoiceGatewayToken');
  }
}
