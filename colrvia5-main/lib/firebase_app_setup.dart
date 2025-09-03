import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

// NOTE: This expects a valid FlutterFire-generated options file at
// lib/firebase_options.dart. Regenerate with `flutterfire configure` if missing.
import 'firebase_config.dart';

class FirebaseAppSetup {
  static bool _initialized = false;

  /// Ensures Firebase is initialized exactly once across the app.
  /// Always call this before any FirebaseAuth/FirebaseFirestore usage.
  static Future<FirebaseApp> ensureInitialized() async {
    if (_initialized && Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }

    WidgetsFlutterBinding.ensureInitialized();

    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: FirebaseConfig.options,
          )
        : Firebase.app();

    _initialized = true;
    return app;
  }

  /// Optional: call after initialization to quickly confirm the options in use.
  static void logActiveOptions() {
    if (Firebase.apps.isEmpty) return;
    final o = Firebase.app().options;
    final apiKey = (o.apiKey.length > 8)
        ? '${o.apiKey.substring(0, 8)}…'
        : o.apiKey;
    // Print minimal identifying info; avoid leaking full API key in logs.
    debugPrint('[Firebase] projectId=${o.projectId} appId=${o.appId} apiKey=$apiKey');
  }
}
