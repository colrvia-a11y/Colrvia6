# Release Plan

## Versioning
- Bump `pubspec.yaml` to `1.0.0+1`.
- Android and iOS pull version and build numbers from `pubspec.yaml`.

## Build Commands
### Android
```bash
flutter build appbundle --release
```
Produces `build/app/outputs/bundle/release/app-release.aab` for Play Store.

### iOS
```bash
flutter build ipa --release
```
Generates an Xcode archive and `build/ios/ipa/Runner.ipa` for App Store.

## Staged Rollout
1. Publish to internal testing tracks.
2. Roll out to ~10% of users and monitor for 24 hours.
3. Increase to 100% if no critical issues.

## Monitoring
- Firebase Crashlytics captures uncaught errors.
- Review analytics dashboards for unusual drops in engagement or spikes in errors.

## Rollback Strategy
- **Android:** Halt the staged rollout or unpublish the release in Play Console. Prepare hotfix (e.g., `1.0.1+2`).
- **iOS:** Remove the version from sale and submit an expedited review for a patched build.

If a critical issue appears, disable affected features remotely (if possible) and ship a hotfix immediately.
