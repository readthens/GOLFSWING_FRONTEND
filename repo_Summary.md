# Frontend Repo Summary

## 2026-06-07 Phase 4.5 Visual Evidence Layer

- Added skeleton and guide-line rendering over analysis keyframes using backend `visual_evidence` normalized points and segments.
- Updated keyframe cards to use analyzed video aspect ratio instead of fixed 16:9 cropping so overlays align with portrait swing videos.
- Added visual state coverage for upload, pending analysis, and final diagnosis through `integration_test/visual_phase45_smoke_test.dart`.
- Added widget coverage for skeleton labels and guide-line metadata in the succeeded analysis state.
- Captured simulator screenshots and validation logs under root `tests/test_20260607_01`.

## 2026-06-07 Phase 4 MVP Diagnosis

- Added an MVP Diagnosis panel to swing detail that renders primary fault, confidence, evidence, one drill, next practice goal, supporting watch items, and diagnosis limitations from `analysis_results.report.diagnosis`.
- Kept the existing Analysis Prototype panel and keyframes in place while updating copy to make Phase 4 diagnosis explicitly pose-based and not coach-grade.
- Fixed active-job polling failures so users see an error and can check status again instead of staring at frozen progress.
- Delayed secure token persistence until login/register hydration succeeds; failed `/me` or consent hydration now clears local token storage.
- Added widget coverage for diagnosis rendering, polling-error visibility, and hydration-failure token cleanup.

## 2026-06-07 Phase 3 Hardening

- Hydrated `/me` profile and video consent immediately after login/register so returning onboarded users land on Home instead of being routed back into onboarding.
- Added a live Phase 3 integration smoke test that logs into the real local backend, opens Swing Library, and verifies the analysis detail panel.
- Extended analysis job models with attempt metadata, added a delete-video API client method, and improved failed-analysis copy for unsupported/bad/short videos, storage issues, and timeouts.
- Validated with `flutter analyze`, `flutter test`, and live iOS simulator smoke against `http://127.0.0.1:8000`.

## 2026-06-06 Phase 3 AI Analysis Prototype

- Added analysis job/result/keyframe models and API client methods for starting analysis, polling jobs, fetching latest session analysis, and loading authenticated keyframe images.
- Replaced the Phase 2 “AI not enabled” swing detail placeholder with an Analysis Prototype panel covering no-result, pending/running, failed/retry, and succeeded result states.
- Rendered provisional summary, prototype score, confidence, pose coverage, warnings, limitations, next-capture recommendation, rough phases, and private keyframes in the existing swing detail route.
- Added widget coverage for no-analysis, running, failed, and succeeded/keyframe states, and extended the iOS simulator smoke to verify the Phase 3 analysis detail panel.
- Validated with `flutter analyze`, `flutter test`, and `flutter test integration_test/phase2_capture_smoke_test.dart -d 1F342B58-618D-4AF8-A0D9-A9A0DABBAED3`.

## 2026-06-06 Phase 2 Guided Capture Quality

- Replaced the Phase 1 gallery-only upload screen with a guided capture/review flow using `camera`, retained gallery import through `image_picker`, and kept `video_player` for local preview metadata.
- Added face-on/down-the-line capture overlays, source actions, club/location choices, advisory quality checks, disabled trim placeholders, and hard-failure upload blocking.
- Added Phase 2 upload metadata for location, duration, resolution, capture source, guide overlay, platform, camera lens, native high-FPS capability, and file extension.
- Added iOS camera/microphone privacy strings, Android camera/audio/network permissions, and native platform-channel capability stubs with high-FPS disabled.
- Updated swing library/detail quality display and added widget tests for consent gate, capture controls, quality rendering, and metadata serialization.
- Added an iOS simulator integration smoke test for the Phase 2 consent gate, capture controls, simulator camera fallback, and quality detail rendering.
- Validated with `flutter analyze`, `flutter test`, `flutter test integration_test/phase2_capture_smoke_test.dart -d <iPhone 17 Pro simulator>`, and `flutter build ios --simulator --debug`; Android debug APK validation was attempted but Gradle hung and was stopped after an extended wait.

## 2026-06-06 Auth Error Detail Fix

- Updated auth error handling to surface backend/Dio response details such as duplicate email, invalid credentials, validation failures, and backend connectivity.
- Added controller tests for duplicate-email and validation guidance so create-account failures are no longer hidden behind a generic request error.

## 2026-06-06 Onboarding Navigation Fix

- Fixed onboarding getting stuck on the first screen by separating startup session restoration from form-submit loading state.
- Made `GoRouter` stable across auth state notifications so onboarding submit events do not reset the router back to `/splash`.
- Added a widget regression test that verifies profile onboarding advances to handedness after Continue.

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
