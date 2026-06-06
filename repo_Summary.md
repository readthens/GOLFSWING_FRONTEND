# Frontend Repo Summary

## 2026-06-06 Keyboard Overflow Fix

- Updated auth and onboarding shells to use keyboard-aware scroll layouts instead of fixed-height columns that could overflow when iOS keyboard appears.
- Added widget regression coverage for sign-in and sign-up forms under a compact phone viewport with simulated keyboard insets.
- Validated with `flutter analyze`, `flutter test`, and iOS simulator launch on iPhone 17 Pro.

## 2026-06-06 Phase 1 Foundation

- Added Flutter iOS/Android scaffold for SwingLens AI.
- Added dependencies for routing, Riverpod state, Dio API calls, secure token storage, video picking, and video playback.
- Added black-and-white premium golf design direction under `docs/design/`.
- Implemented app shell, auth screens, onboarding profile/handedness/goals/privacy consent, home, upload, swing library, and swing detail screens.
- Integrated Phase 1 backend API client for auth, consent, presigned video upload, upload completion, swing-session creation, and video attachment.
- Deferred AI analysis, payments, native high-FPS camera modules, coach/admin surfaces, and shot tracer.
