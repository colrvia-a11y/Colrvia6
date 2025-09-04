# Firebase Permanent Setup Guide

This guide helps you set up Firebase with real credentials for long-term use, replacing the current placeholder configuration.

## Overview

Currently, the app uses placeholder Firebase credentials that don't work with real authentication. You have two options:

1. **Runtime Override** (temporary) - Use `--dart-define-from-file=firebase.env` 
2. **Permanent Setup** (recommended) - Replace placeholder configs with real ones

This guide covers the **permanent setup** for production use.

## Prerequisites

- A real Firebase project (create one at https://console.firebase.google.com)
- Flutter and Dart installed
- FlutterFire CLI

## Step 1: Install FlutterFire CLI

```bash
# Activate the FlutterFire CLI
dart pub global activate flutterfire_cli

# Verify installation
flutterfire --version
```

## Step 2: Login to Firebase

```bash
# Login to your Google account that has access to your Firebase project
firebase login
```

## Step 3: Configure FlutterFire

Run the FlutterFire configuration tool:

```bash
# Navigate to your project root
cd /path/to/your/flutter/project

# Configure Firebase
flutterfire configure
```

This will:
1. Show you a list of your Firebase projects
2. Let you select which project to use
3. Ask which platforms to configure (select all: Android, iOS, Web, macOS, Windows)
4. Generate new `lib/firebase_options.dart` with real credentials
5. Download platform-specific config files

## Step 4: Verify Generated Files

After running `flutterfire configure`, verify these files were updated:

### Generated Files:
- `lib/firebase_options.dart` - Contains real Firebase options for all platforms
- `android/app/google-services.json` - Android configuration
- `ios/Runner/GoogleService-Info.plist` - iOS configuration  
- `macos/Runner/GoogleService-Info.plist` - macOS configuration (if selected)

### Check the content:
- Open `lib/firebase_options.dart` and verify `projectId` is your real project ID (not `v29bvc2fec6tbbyy7j9h4tddz1dq28`)
- Open `android/app/google-services.json` and verify `project_id` matches your project
- Open `ios/Runner/GoogleService-Info.plist` and verify `PROJECT_ID` matches your project

## Step 5: Enable Required Firebase Services

In the Firebase Console (https://console.firebase.google.com):

1. **Authentication**:
   - Go to Authentication > Sign-in method
   - Enable "Email/Password" provider
   - Optionally enable other providers you need

2. **Firestore Database**:
   - Go to Firestore Database
   - Create database (start in test mode, secure later)

3. **Storage** (if using file uploads):
   - Go to Storage
   - Get started with default settings

4. **Identity Toolkit API** (automatic):
   - This should be enabled automatically when you enable Authentication
   - If you see API key errors, verify this is enabled in Google Cloud Console

## Step 6: Test the Configuration

1. Remove any existing `firebase.env` file (no longer needed)
2. Run your app normally without `--dart-define-from-file`:

```bash
# Test on different platforms
flutter run -d android
flutter run -d chrome
flutter run -d ios  # if on macOS
```

3. Try to sign up/sign in to verify authentication works

## Step 7: Update Security Rules (Important!)

Once everything works, secure your Firestore and Storage:

### Firestore Rules (`firestore.rules`):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Add other collection rules as needed
    match /palettes/{paletteId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Rules (`storage.rules`):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules,storage
```

## Troubleshooting

### "API key not valid" errors:
- Verify `flutterfire configure` completed successfully
- Check that `lib/firebase_options.dart` has real values (not placeholder `v29bvc2...`)
- Ensure Identity Toolkit API is enabled in Google Cloud Console

### Platform-specific issues:
- **Android**: Verify `android/app/google-services.json` exists and has correct `project_id`
- **iOS**: Verify `ios/Runner/GoogleService-Info.plist` exists and has correct `PROJECT_ID`
- **Web**: Verify web configuration in `lib/firebase_options.dart` includes `authDomain`

### Build errors:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Rollback (if needed)

If you need to rollback to the runtime override approach:

1. Restore the original placeholder files from git:
```bash
git checkout lib/firebase_options.dart
git checkout android/app/google-services.json  
git checkout ios/Runner/GoogleService-Info.plist
```

2. Use runtime configuration:
```bash
flutter run --dart-define-from-file=firebase.env
```

## Summary

After completing this setup:
- ✅ Your app will work with real Firebase authentication
- ✅ No need for `--dart-define-from-file=firebase.env` anymore  
- ✅ All platforms (Android, iOS, Web) will use proper credentials
- ✅ Ready for production deployment

The runtime override in `lib/firebase_config.dart` will still work as a fallback, but won't be needed for normal development and production use.
