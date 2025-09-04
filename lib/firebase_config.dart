import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'firebase_options.dart';

/// Provides FirebaseOptions with support for runtime overrides via --dart-define.
///
/// If the required --dart-define values are provided at launch, those values
/// are used. Otherwise, falls back to the generated DefaultFirebaseOptions.
class FirebaseConfig {
  /// Returns the active FirebaseOptions, preferring runtime overrides.
  static FirebaseOptions get options {
    final override = _readOverrides();
    return override ?? DefaultFirebaseOptions.currentPlatform;
  }

  /// Best-effort detection of placeholder config bundled in the repo.
  static bool get isUsingPlaceholderConfig {
    final o = DefaultFirebaseOptions.currentPlatform;
    return o.projectId == 'v29bvc2fec6tbbyy7j9h4tddz1dq28' ||
        o.appId.contains(':e5a7c74a7c5b7a9e6a0f') ||
        o.appId.contains(':c8a2d9f5b4e3a6c19e6a0f');
  }

  static FirebaseOptions? _readOverrides() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

    // Optional values – used when provided
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const databaseURL = String.fromEnvironment('FIREBASE_DATABASE_URL');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

    // Require core fields to consider overrides valid
    final hasCore =
        apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;
    if (!hasCore) return null;

    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isNotEmpty ? authDomain : null,
        databaseURL: databaseURL.isNotEmpty ? databaseURL : null,
        storageBucket: storageBucket.isNotEmpty ? storageBucket : null,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          databaseURL: databaseURL.isNotEmpty ? databaseURL : null,
          storageBucket: storageBucket.isNotEmpty ? storageBucket : null,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          databaseURL: databaseURL.isNotEmpty ? databaseURL : null,
          storageBucket: storageBucket.isNotEmpty ? storageBucket : null,
          iosBundleId: iosBundleId.isNotEmpty ? iosBundleId : null,
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          authDomain: authDomain.isNotEmpty ? authDomain : null,
          databaseURL: databaseURL.isNotEmpty ? databaseURL : null,
          storageBucket: storageBucket.isNotEmpty ? storageBucket : null,
        );
      default:
        return null;
    }
  }
}

