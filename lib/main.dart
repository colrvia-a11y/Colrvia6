import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:color_canvas/screens/compare_screen.dart';
// REGION: CODEX-ADD compare-colors-import
import 'package:color_canvas/screens/compare_colors_screen.dart';
// END REGION: CODEX-ADD compare-colors-import
import 'package:color_canvas/widgets/more_menu_sheet.dart';
import 'package:color_canvas/firebase_config.dart';
import 'package:color_canvas/theme.dart';
import 'package:color_canvas/screens/auth_wrapper.dart';
import 'package:color_canvas/screens/home_screen.dart';
import 'package:color_canvas/screens/login_screen.dart';
import 'package:color_canvas/screens/color_plan_detail_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';
import 'package:color_canvas/screens/color_plan_screen.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/network_utils.dart';
import 'package:color_canvas/utils/debug_logger.dart';
import 'package:color_canvas/models/user_palette.dart';
import 'services/feature_flags.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/sync_queue_service.dart';
import 'services/notifications_service.dart';


// Global Firebase state
bool isFirebaseInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded(() async {
    Debug.info('App', 'main', 'Flutter bindings initialized');

    // Initialize Firebase with platform-specific options
    try {
    Debug.info('App', 'main', 'Starting Firebase initialization');
    
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseConfig.options,
      );
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      Debug.info('App', 'main', 'Firebase app initialized');
    } else {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      Debug.info('App', 'main', 'Firebase app already initialized');
    }
    Debug.info('App', 'main', 'Firebase project: \'${Firebase.app().options.projectId}\'');
    
    // REGION: app-check-setup
    const bool enableAppCheck =
        bool.fromEnvironment('ENABLE_APPCHECK', defaultValue: true);
    if (enableAppCheck) {
      // Production reCAPTCHA site key for ColorCanvas app
      const String recaptchaSiteKey =
          '6LfLm7grAAAAALy7wXUidR9yilxtIggw4SJNfci4'; // PRODUCTION KEY

      await FirebaseAppCheck.instance.activate(
        // For web: Using production reCAPTCHA v3 site key
        webProvider: ReCaptchaV3Provider(recaptchaSiteKey),

        // For Android: Use debug provider for development, Play Integrity for production
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,

        // For iOS: Use debug provider for development, DeviceCheck for production
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );

      Debug.info('App', 'main',
          'Firebase App Check activated with PRODUCTION reCAPTCHA key');
    }
    // END REGION: app-check-setup
    
    // Initialize the Gemini Developer API backend service
    // Create a `GenerativeModel` instance with a model that supports your use case
    FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
    Debug.info('App', 'main', 'Firebase AI GenerativeModel initialized with gemini-2.5-flash');
    
    await FirebaseService.enableOfflineSupport();
    isFirebaseInitialized = true;
    Debug.info('App', 'main', 'Firebase initialized successfully');

    // Initialize NetworkGuard and clear session overrides
    NetworkGuard.clearSessionOverrides();
    Debug.info('App', 'main', 'NetworkGuard initialized');

    await FeatureFlags.instance.init();

    Connectivity().onConnectivityChanged.listen((status) {
      if (!status.contains(ConnectivityResult.none)) {
        SyncQueueService.instance.replay();
      }
    });

    await NotificationsService.instance.init();

    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    FirebasePerformance.instance; // warm up

    Debug.info('App', 'main', 'Running app');
    runApp(const MyApp());
  } catch (e, stack) {
    // Handle Firebase initialization errors
    isFirebaseInitialized = false;
    Debug.error('App', 'main', 'Firebase initialization error: $e');
    FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
  }
}, (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    Debug.build('MyApp', 'build', details: 'Building main app widget');
    AnalyticsService.instance.logAppOpen();
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            // Show More menu with autofocus search using global navigator key
            final currentContext = navigatorKey.currentContext;
            if (currentContext != null) {
              showModalBottomSheet(
                context: currentContext,
                useSafeArea: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                barrierColor: Colors.black.withValues(alpha: 0.2),
                builder: (_) => const MoreMenuSheet(autofocusSearch: true),
              );
            }
            return null;
          }),
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
            // Close any open sheet/dialog if present
            navigatorKey.currentState?.maybePop();
            return null;
          }),
        },
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Paint Roller',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scale = media.textScaler.clamp(maxScaleFactor: 1.3);
            return MediaQuery(
              data: media.copyWith(textScaler: scale),
              child: child ?? const SizedBox(),
            );
          },
          home: const AuthCheckScreen(),
          routes: {
            '/auth': (context) => const AuthWrapper(),
            '/home': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/colorPlan': (context) {
              final args =
                  ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return ColorPlanScreen(
                projectId: args['projectId'] as String,
                paletteColorIds:
                    (args['paletteColorIds'] as List<dynamic>?)?.cast<String>(),
              );
            },
            '/visualize': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
              return VisualizerScreen(
                storyId: args?['storyId'] as String?
              );
            },
            '/compare': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, UserPalette>?;
              return CompareScreen(
                comparePalette: args?['palette']
              );
            },
            // REGION: CODEX-ADD compare-colors-route
            '/compareColors': (context) {
              final args =
                  ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              final ids =
                  (args['paletteColorIds'] as List<dynamic>? ?? []).cast<String>();
              return CompareColorsScreen(paletteColorIds: ids);
            },
            // END REGION: CODEX-ADD compare-colors-route
            '/colorPlanDetail': (context) {
              final storyId =
                  ModalRoute.of(context)!.settings.arguments as String;
              debugPrint(
                  '🐛 Route: NavigatingTo ColorPlanDetailScreen with storyId = $storyId');
              return ColorPlanDetailScreen(storyId: storyId);
            },
            
          },
        ),
      ),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  Timer? _debugTimer;

  @override
  void initState() {
    super.initState();
    Debug.info(
        'AuthCheckScreen', 'initState', 'Auth check screen initializing');
    _checkAuthState();
    _startDebugTimer();
  }

  void _startDebugTimer() {
    // Print debug summary every 10 seconds to track infinite loop patterns
    _debugTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Debug.summary();
    });
  }

  @override
  void dispose() {
    _debugTimer?.cancel();
    super.dispose();
  }

  void _checkAuthState() {
    // Give users immediate access to the app
    // They can choose to sign in later from settings
    Debug.postFrameCallback('AuthCheckScreen', '_checkAuthState',
        details: 'Checking auth state');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Debug.info(
          'AuthCheckScreen', '_checkAuthState', 'PostFrameCallback executing');
      if (FirebaseService.currentUser != null) {
        Debug.info('AuthCheckScreen', '_checkAuthState',
            'User signed in, navigating to home');
        // User is already signed in, go to home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Debug.info('AuthCheckScreen', '_checkAuthState',
            'User not signed in, navigating to home anyway');
        // User not signed in, but allow app access
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.palette,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ColorCanvas',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
