# Firebase Auth SHA-1 Configuration Fix

## Issue
Getting "API key not valid" error when trying to log in on Android.

## Root Cause
The SHA-1 fingerprint for the debug build is not registered in Firebase Console.

## Debug SHA-1 Fingerprint
```
A4:DA:E3:7A:D1:EA:DA:3C:9C:E4:62:0F:53:CA:86:0A:E1:22:60:11
```

## Fix Steps

### 1. Add SHA-1 to Firebase Console
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select project: `v29bvc2fec6tbbyy7j9h4tddz1dq28`
3. Project Settings → General → Your apps → Android app
4. Click "Add fingerprint"
5. Add the SHA-1 above
6. Download new google-services.json
7. Replace android/app/google-services.json

### 2. Verify API Key Restrictions
1. Go to Google Cloud Console: https://console.cloud.google.com/
2. Navigate to APIs & Services → Credentials
3. Find your Android API key
4. Ensure it allows:
   - Firebase Authentication API
   - Firebase Installations API
   - Identity Toolkit API

### 3. Test
After adding SHA-1, clean and rebuild:
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## Alternative: Use Firebase CLI
```bash
firebase apps:sdkconfig android
```
