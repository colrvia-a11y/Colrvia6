# Firebase Setup Instructions - REAL PROJECT NEEDED

## Current Issue
The Firebase configuration in your project appears to use placeholder/example values, not a real Firebase project. This is why email/password authentication fails with "API key not valid".

## Evidence of Placeholder Config
- Project ID: `v29bvc2fec6tbbyy7j9h4tddz1dq28` (appears random/generated)
- Client ID: `596436988958-example.apps.googleusercontent.com` (contains "example")
- These are not real Firebase project credentials

## Solution: Create Real Firebase Project

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com/
2. Click "Create a project" or "Add project"
3. Enter a project name (e.g., "colrvia5-prod")
4. Enable Google Analytics if desired
5. Create the project

### Step 2: Enable Authentication
1. In Firebase Console, go to **Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Enable **Email/Password** provider
5. Save changes

### Step 3: Add Android App
1. In Firebase Console, click **Add app** → **Android**
2. Android package name: `com.example.color_canvas`
3. Download the **real** `google-services.json`
4. Replace `android/app/google-services.json`

### Step 4: Add Web App (if needed)
1. Click **Add app** → **Web**
2. App nickname: "colrvia5-web"
3. Copy the Firebase config

### Step 5: Update Flutter Configuration
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Run: `flutterfire configure` (from project root)
4. Select your new Firebase project
5. Select platforms (Android, Web, etc.)
6. This will update `firebase_options.dart` with real values

### Step 6: Add Firestore (if needed)
1. In Firebase Console, go to **Firestore Database**
2. Click **Create database**
3. Choose production mode or test mode
4. Select a location

## Quick Test After Setup
```dart
// Test in your app
FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: "test@example.com", 
  password: "password123"
);
```

This should work without SHA-1 fingerprints for basic email/password auth.
