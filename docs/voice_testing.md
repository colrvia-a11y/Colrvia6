# Live Talk (Via) – QA Testing Guide

This guide helps QA validate the Live Talk (Via) voice experience across devices and core flows: connect, interrupt, silence-based turn taking, and transcript persistence.

## Overview

- Transport: WebRTC first, automatic fallback to WebSocket when WebRTC is blocked.
- Auth: Client obtains a Firebase ID token; the app calls a Firebase Function (`issueVoiceGatewayToken`) which mints an OpenAI Realtime ephemeral session. The client never sees the OpenAI API key.
- Turn taking: Server VAD is enabled via `session.update` so the assistant responds after user silence.
- Persistence: A transcript is buffered during the call and saved to Firestore (plus optional JSON uploaded to Cloud Storage) when the session ends.

Key files:
- `lib/services/live_talk_service.dart` – WebRTC path and UX notifiers
- `lib/services/live_talk_service_ws.dart` – Fallback WS path
- `functions/src/talk.ts` – `issueVoiceGatewayToken` callable (uses `OPENAI_API_KEY`)
- `lib/services/live_talk_recorder.dart` and `lib/services/interview_shared_engine.dart` – transcript persistence

## Device Matrix

Test on a minimum of the following:

- iOS
  - iPhone 12/13/14 (iOS 16–17)
  - Built‑in mic and Bluetooth headset
- Android
  - Pixel 6/7 (Android 13–14)
  - Samsung Galaxy S21/S22 (Android 12–14)
  - Built‑in mic and wired/Bluetooth headset

Notes:
- Ensure app has mic permission and the device volume is audible.
- If a corporate network blocks WebRTC, the app should fall back to WS; the status pill shows “• Fallback WS”.

## Pre‑Test Setup

1. Deploy the token function with your OpenAI key
   - Set environment var `OPENAI_API_KEY` for the function (Cloud Functions 2nd gen):
     - Via Google Cloud Console (Cloud Run service env vars) or `gcloud` CLI.
   - Deploy the callable:
     - `firebase deploy --only functions:issueVoiceGatewayToken`
   - Function URL: `https://us-central1-<your-project>.cloudfunctions.net/issueVoiceGatewayToken`

2. Point the app to your function URL
   - Update the constant in:
     - `lib/screens/interview_voice_setup_screen.dart` → `kIssueTokenUrl`
     - `lib/widgets/via_overlay.dart` → `_kIssueTokenUrl`

3. Enable the feature flag (to surface UI entry points)
   - Firebase Remote Config: set key `voiceInterview = true` (publish)
   - Optional per-user Labs toggle: set Firestore `users/{uid}/meta/prefs.features.voiceInterview = true`

4. Sign in to the app (Firebase Auth) and run on device.

## Test Scenarios

1) Connect
- Navigate: Create → Interview → “Start with Via (Voice)” → Voice Setup → “Continue with Voice”.
- Accept mic permission if prompted.
- Verify status pill:
  - Shows “Connecting” then “Listening” when connected.
  - If fallback engaged, label includes “• Fallback WS”.
  - On failures (mic blocked, token error), an error banner appears with a friendly message and a Retry button. Mic errors also show “Open Settings”.

2) Interrupt
- While the assistant is speaking, tap “Interrupt”.
- Expected: Assistant stops and yields a new prompt shortly. Status pill toggles to “Listening” (or “Speaking” when the assistant resumes).

3) Silence timeout (server VAD)
- After the assistant finishes, answer briefly, then stop speaking.
- Expected: After a short silence, the assistant responds automatically (no manual tap required). Status transitions Speaking → Listening appropriately.

4) Press‑to‑Talk (PTT)
- Tap mic (center button) to toggle mute/unmute; long‑press to talk while held.
- Expected: Short‑press toggles mute state; long‑press unmutes for the hold duration and mutes on release.

5) Save transcript
- Tap “Stop” to end the session.
- Verify Firestore:
  - Collection `interviewSessions`: a new document with `userId`, `startedAt/endedAt`, `durationSec`, `model`, `voice`.
  - Subcollection `turns`: each assistant/user turn with `role`, `text`, `ts`.
- Verify optional JSON transcript in Storage:
  - Path `users/{uid}/transcripts/{sessionId}.json`.

## Optional Error Handling Checks

- Mic blocked: Deny mic permission → error banner with “Open Settings” + “Retry”.
- Token failure: Temporarily misconfigure function URL → friendly error + Retry.
- Negotiation timeout: Simulate poor network → should either retry or fall back to WS, status pill updates accordingly.
- WS closed mid‑call: Disable network → banner with reconnect/Retry; status shows “Reconnecting”.

## Tips

- Analytics hooks fire on session start/stop; use logs to confirm.
- If WebRTC audio output is quiet, verify device output (ringer vs media volume) and that the hidden `RTCVideoView` is present (1×1 view in the screen).

