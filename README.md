# Color Canvas

A Flutter app for color palette management and visualization.

## Firebase Setup

This app uses Firebase for authentication and data storage. You have two options:

### Option 1: Quick Start (Runtime Configuration)
For immediate testing with your own Firebase project:

1. Copy `firebase.env.example` to `firebase.env`
2. Fill in your Firebase project credentials
3. Run with: `flutter run --dart-define-from-file=firebase.env`

### Option 2: Permanent Setup (Recommended)
For long-term development and production use:

1. **Automated Setup** (Windows):
   ```bash
   .\setup_firebase_permanent.ps1
   ```

2. **Manual Setup**:
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase
   flutterfire configure
   
   # Select your project and platforms
   ```

3. **Enable Authentication**:
   - Go to Firebase Console > Authentication > Sign-in method
   - Enable "Email/Password" provider

For detailed instructions, see [FIREBASE_PERMANENT_SETUP.md](FIREBASE_PERMANENT_SETUP.md).

## Getting Started

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Set up Firebase** (see above)

3. **Run the app**:
   ```bash
   flutter run
   ```

## Features

- Color palette creation and management
- Firebase authentication (email/password)
- Cross-platform support (Android, iOS, Web)
- Color visualization and editing

## AI Visualizer Workflow

The Visualizer lets you upload a photo of a space and preview paint colors on detected surfaces with photorealistic results.

1. Open Visualizer: From Home, navigate to the Visualizer tab.
2. Upload Your Photo: Tap the upload card and select an image.
   - The app automatically starts analysis after selection.
3. Analysis (AI): The app sends the photo + a structured prompt to Gemini.
   - Returns JSON with `space_type`, `paintable_surfaces`, `lighting_conditions`, etc.
4. Surface & Color Selection: Toggle detected surfaces and pick colors (from your palette or defaults).
5. Generate: The app sends your photo + per-surface color instructions to an image-capable Gemini model.
   - Receives a photorealistic image and shows the result.

Key files:
- `lib/screens/visualizer_screen.dart`: Orchestrates the flow and UI.
- `lib/services/gemini_ai_service.dart`: Wraps Firebase AI Logic calls (analysis + image render).
- Optional server path: `lib/services/visualizer_service.dart` with Cloud Functions in `functions-visualizer/index.js`.

Notes:
- If AI is temporarily unavailable, analysis returns a safe fallback JSON and generation returns the original image to keep UX flowing.
- You can iterate by changing surfaces/colors and generating again.

## Development

This project uses:
- Flutter/Dart
- Firebase (Auth, Firestore, Storage)
- Material Design 3

## Troubleshooting

### "API key not valid" errors
- Make sure you've completed Firebase setup (see above)
- Verify your Firebase project has Authentication enabled
- Check that Identity Toolkit API is enabled in Google Cloud Console

### Build issues
```bash
flutter clean
flutter pub get
flutter run
```

For more troubleshooting, see [FIREBASE_PERMANENT_SETUP.md](FIREBASE_PERMANENT_SETUP.md).

## Runbook

### Setup

```bash
flutter pub get
# copy credentials if not using permanent setup
cp firebase.env.example firebase.env
```

### Emulators

```bash
firebase emulators:start
```

### Functions deploy (exportColorStory)

```bash
cd functions
firebase deploy --only functions:exportColorStory
cd ..
```

### Rules & Indexes deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Running the app

```bash
flutter run --dart-define-from-file=firebase.env
```

### CI

Runs `flutter analyze` and `flutter test` via GitHub Actions on each push.

## AI Architecture & Models

We use Firebase AI Logic (client SDK) to call Gemini models directly from the app via Firebase’s secure proxy and App Check.

- Provider: Gemini Developer API (recommended to start). You can later switch to Vertex with minimal code changes.
- Initialization: See `lib/main.dart` (Firebase initialization and AI SDK readiness).
- Client models used:
  - Analysis (JSON output): `gemini-2.5-flash`
  - Image render (photorealistic edits): `gemini-2.5-flash-image-preview` with `responseModalities: [TEXT, IMAGE]`
- Security: Firebase App Check is enabled to protect the AI endpoint from unauthorized clients.

Optional server-side generation
- Cloud Function: `functions-visualizer/index.js` exposes `visualizerGenerate`, which uses `gemini-2.5-flash-image-preview` server-side and saves PNGs to Cloud Storage (returns signed URLs).
- Use when you want tighter quota/billing control, publicly shareable asset URLs, or to keep all image generation off-device.

Switching providers (Developer API ↔ Vertex)
- Developer API (current): `FirebaseAI.googleAI()`
- Vertex AI: `FirebaseAI.vertexAI(project: '<project-id>', location: 'us-central1')`

Run requirements
- Enable Firebase AI Logic in Firebase Console and select your provider (Developer API recommended initially).
- No `--dart-define` for a Gemini key is needed when using Firebase AI Logic.
