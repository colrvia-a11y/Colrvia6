# Firebase App Check Production Setup

## 🔐 Required Steps for Production Firebase App Check

### 1. Get reCAPTCHA v3 Site Key (REQUIRED)

1. Go to https://www.google.com/recaptcha/admin
2. Click "Create" to add a new site
3. Choose **reCAPTCHA v3**
4. Add your domains:
   - `localhost` (for testing)
   - Your production domain (e.g., `yourapp.com`)
5. Copy the **Site Key** (starts with `6L...`)

### 2. Update Your App Configuration

Replace `YOUR_RECAPTCHA_SITE_KEY` in these files with your actual site key:

**lib/main.dart:**
```dart
webProvider: ReCaptchaV3Provider('YOUR_ACTUAL_SITE_KEY_HERE'),
```

**web/index.html:**
```javascript
appCheck.activate('YOUR_ACTUAL_SITE_KEY_HERE');
```

### 3. Firebase Console Setup

1. Go to Firebase Console → Project Settings → App Check
2. Register your apps:
   - **Web app**: Add your reCAPTCHA site key
   - **Android app**: Enable Play Integrity
   - **iOS app**: Enable DeviceCheck

### 4. Current Configuration Status

✅ Play Integrity enabled for Android (production-ready)
✅ DeviceCheck enabled for iOS (production-ready)  
⚠️  **PENDING**: Replace reCAPTCHA site key with real key

### 5. Testing

After updating the site key:
1. Clean build: `flutter clean && flutter pub get`
2. Test authentication on all platforms
3. Check Firebase Console App Check dashboard for verification

## 🚨 Important Notes

- **Debug providers removed** - using production App Check providers
- **Play Integrity** requires app to be signed and published to Play Store for full functionality
- **reCAPTCHA key is required** - app will fail authentication without it

## 🔧 Quick Fix Commands

```bash
# 1. Get your reCAPTCHA site key from Google
# 2. Replace in main.dart:
# webProvider: ReCaptchaV3Provider('YOUR_REAL_SITE_KEY'),

# 3. Replace in web/index.html:
# appCheck.activate('YOUR_REAL_SITE_KEY');

# 4. Clean and rebuild
flutter clean
flutter pub get
flutter run
```
