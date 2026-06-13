# Frontend Repo Summary

## 2026-06-13 Shot Tracer Camera Flow Correction

- Removed the separate `/tracer/camera` screen and restored Shot Tracer start behavior to the existing tracer capture pipeline.
- Kept `/tracer/new` as the start alias, now redirecting into `/capture/tracer?camera=1`, while `IMPORT VIDEO` remains on the intro and continues to open `/capture/tracer`.
- Added a camera-first presentation inside `UploadScreen(mode: tracer)`: large SwingLens-style preview, status/timer HUD, readiness chips, record deck, guide-lock controls, no duplicate import/choose-video controls in camera-first entry, and the existing upload/session/offline metadata path remains intact.
- Preserved the original import/review tracer upload screen for gallery imports and regression coverage.
- Validated with focused tracer tests, `flutter analyze`, full `flutter test` (`79 passed`), `git diff --check`, and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Full-Screen Shot Tracer Camera (Superseded)

- Superseded by the Shot Tracer Camera Flow Correction above; the separate route was removed in favor of the existing tracer capture pipeline.
- Added a dedicated full-screen `/tracer/camera` route and changed `/tracer/new` to enter that camera-style recorder instead of the form-heavy tracer upload screen.
- Updated the Shot Tracer intro `START TRACER CAMERA` CTA to open the full-screen camera surface; `IMPORT VIDEO` remains on the intro and continues to use `/capture/tracer`.
- Built the camera surface with rear-camera preview when available, simulator-safe image fallback, immersive system UI, timer/status HUD, guide overlay, impact-lock/tracer arc states, high-FPS readiness indicators, and a SmoothSwing-style bottom record deck.
- Added widget coverage proving the camera route hides the app bottom nav/import button, enters waiting-for-impact state, and transitions to impact detected.
- Validated with focused tracer tests, `flutter analyze`, full `flutter test` (`79 passed`), `git diff --check`, and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Shot Tracer Camera-First Intro

- Rebuilt the `/tracer` tab landing page into a camera-first Shot Tracer starter screen using the uploaded `shot_tracer.png` asset copied into `assets/home/`.
- Added a large live-preview hero with green framing box, dashed target line, ball anchor, target marker, flight arc, quality checklist, flip control, and white `START TRACER CAMERA` / ghost `IMPORT VIDEO` CTAs wired to the existing tracer capture route.
- Replaced backend-looking recent tracer rows with horizontal visual thumbnail cards using polished statuses such as `Auto Tracked` and `Needs Review`, confidence coloring, club badges, and routes back to existing swing/tracer detail surfaces.
- Added widget coverage for the camera-first intro, hero image, overlay, CTAs, visual recent cards, and removal of debug status copy.
- Validated with focused tracer/bottom-nav widget tests, `flutter analyze`, full `flutter test` (`78 passed`), `git diff --check`, and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Home Performance Hero And Quick Actions Polish

- Removed the bordered `SWING CONSISTENCY` pill from the Home Performance Lab and replaced it with a text-only metric stack under the golfer image.
- Lowered the central golfer asset slightly and added honest trend rendering: green up arrow or red down arrow only when Home data provides a real trend/delta; otherwise the caption remains.
- Reworked Quick Actions into a tighter aligned row with centered icons, labels, subtitles, consistent height, and smaller gaps.
- Extended Home widget coverage for the trend arrow state.
- Validated with focused Home widget tests, `flutter analyze`, full `flutter test` (`77 passed`), `git diff --check`, and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Last Game Text Fit Patch

- Reduced Last Game banner title, meta, stat, label, and `VIEW RECAP` pill typography so the uploaded reference layout fits cleanly on iPhone widths.
- Shortened the compact stats zone, reduced stat gaps, forced stat labels to a single line, and moved the recap pill lower-right so it no longer crowds `FAIRWAYS` / `PUTTS`.
- Validated with `flutter analyze`, full `flutter test` (`77 passed`), and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Last Game Banner Spacing Patch

- Tightened the Home Last Game card to match the uploaded wide recap reference: taller 192/202px responsive banner, full-card course image, stronger left readability gradient, and wider rounded corners.
- Split the banner into positioned header, stats, and recap-button zones so the title/meta, `SCORE` / `FAIRWAYS` / `PUTTS`, and `VIEW RECAP` pill no longer crowd each other.
- Made the stats row use flexible columns with fixed gaps to prevent iPhone-width RenderFlex overflow while preserving large value typography.
- Extended Home widget coverage to assert the card stays at least 190px tall.
- Validated with `flutter analyze`, full `flutter test` (`77 passed`), and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Last Game Course Image Patch

- Added `assets/home/golfcourse.png` from the uploaded Home assets as the default Last Game recap background.
- Reworked the Home Last Game card only: course image on the right, dark left-to-right gradient, tracer overlay, right-side `VIEW RECAP` pill, and aligned `SCORE` / `FAIRWAYS` / `PUTTS` columns.
- Added clean fallback behavior for missing course image/title/date/stats and mapped the local demo placeholder round to the approved Riverside recap copy.
- Updated Home widget coverage to assert the course-image fallback and `LAST GAME` label.
- Validated with `flutter analyze`, full `flutter test` (`77 passed`), demo reseed, and live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator.

## 2026-06-13 Premium Home Floating Metrics Correction

- Refined `/home` after the approved premium dashboard review so the Performance Lab uses floating metric text groups instead of individual boxed stat cards.
- Enlarged the central golfer hero treatment with a darker cinematic surface, larger analytics halo, dotted ring detail, and a glowing base platform.
- Polished the Last Game/Last Shot card with an asset-backed visual layer, softer border treatment, tracer styling, and clean round stat fallbacks.
- Removed user-facing debug copy from the Home hero such as `POSE BASED`, `NOT ENOUGH`, `Rounds v2`, and `Open stats`; unavailable metrics now render as `--`, `No club`, or concise track-more copy.
- Validated with `flutter analyze`, full `flutter test` (`77 passed`), live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator, demo reseed, and simulator screenshot review.

## 2026-06-13 Asset-Backed Home Dashboard

- Reworked `/home` around the uploaded `swinglens_home_exact_ui_orientation.md` direction: brand row, notification/avatar controls, greeting, honest weather-off pill, priority row, Last Game recap, central Performance Lab, quick actions, and recent activity.
- Copied the uploaded golfer/avatar PNGs into `assets/home/` and registered them in `pubspec.yaml`; Home now uses the behind-the-back golfer asset as the central performance visual and asset-backed activity cards.
- Kept metrics honest: weather remains disabled until an API exists, unavailable round/club metrics use clean empty fallbacks, and tracer values remain visual-only/confidence-oriented.
- Updated Home/widget expectations and live dashboard smoke markers for the new Home hierarchy.
- Validated with `flutter analyze`, full `flutter test` (`77 passed`), live `dashboard_nav_smoke_test.dart` on the iPhone 17 Pro Max simulator, demo reseed, and simulator screenshot review.

## 2026-06-13 Bottom Navigation Visual Polish

- Updated the persistent bottom navigation to a lighter translucent dark surface with a soft selected capsule, thin top border, and higher-contrast icon/label colors.
- Moved icon/label state styling into a local `NavigationBarTheme` so the selected and unselected states remain readable on dark simulator/device chrome.
- Added widget coverage for the updated bottom navigation height, transparent bar background, selected pill color/border, and icon/label contrast.
- Validated with focused bottom navigation widget coverage, `flutter analyze`, and full `flutter test` (`77 passed`).

## 2026-06-12 Production Hardening

- Added GitHub Actions frontend CI for Flutter 3.41.1 with `flutter analyze` and `flutter test`.
- Added Phase 7 release notes covering offline sync scope, validated gates, demo credentials, release checklist, and known gaps.
- Updated the TestFlight flow to include the Phase 7 live sync smoke and Sync Center validation.

## 2026-06-12 Phase 7 Sync Center Cleanup

- Added failed-work accounting to the offline queue and a `clearFailed` cleanup path that preserves pending/syncable items.
- Added a Sync Center `CLEAR FAILED` action for retry records that cannot proceed, keeping the existing compact black-and-white panel style.
- Added release documentation at `docs/release/phase7_live_sync_validation.md` with backend, simulator, automatic sync, reseed, and cleanup-command smoke steps.
- Added unit/widget coverage proving failed rows can be cleared without removing pending work.
- Validated with `flutter analyze`, targeted Sync Center cleanup tests, full `flutter test` (`77 passed`), and `git diff --check`.

## 2026-06-11 Phase 7 Automatic Sync Polish

- Added `OfflineSyncCoordinator` at the app root to retry queued offline work after app launch/auth restore, new queue items, and app resume without requiring the user to open Sync Center.
- Added per-item queue status derivation (`PENDING`, `SYNCING`, `FAILED`) and surfaced status in Sync Center rows while preserving the black-and-white panel style.
- Hardened retained upload retry handling so missing queued video files stay queued with a clear failed-state message instead of throwing opaque file errors.
- Added tests for missing retained upload files and automatic app-level sync retry, plus `integration_test/phase7_sync_smoke_test.dart` for live simulator/API validation of favorite, round, upload, and failed-file queue states.
- Validated with `flutter analyze`, targeted sync/queue tests, full `flutter test` (`75 passed`), live `dashboard_nav_smoke_test.dart`, live `phase7_sync_smoke_test.dart` on iPhone 17 Pro Max simulator, demo reseed, and `git diff --check`.

## 2026-06-10 Phase 7 Upload Queue And Sync Center

- Extended `ApiClient.uploadSwingVideo` with per-step idempotency keys for presign, complete, session creation, and video attach retries.
- Added `upload.swing_video` support to `OfflineQueueStore`, including app-owned retained video files, upload retry dispatch, and retained-file cleanup after successful sync.
- Updated guided capture upload failure handling so network-only failures enqueue the selected video, preserve capture metadata, notify the user, and open `/profile/sync`.
- Added `/profile/sync` Sync Center UI plus a Profile hub entry showing pending device-local work for uploads, scorecard edits, and favorite changes.
- Added widget/unit coverage for retained upload retry idempotency and visible Sync Center queued state.
- Validated with `flutter analyze`, targeted upload/sync tests, and full `flutter test` (`73 passed`).

## 2026-06-10 Phase 7 Offline Queue Foundation

- Added a file-backed `OfflineQueueStore` with in-memory test persistence, queued item metadata, retry dispatch, and network-only failure detection.
- Added idempotency-key support to retryable favorite and round API client writes so queued actions can replay safely against the backend.
- Queued favorite save/remove actions from favorite toggles when the device cannot reach the API, with a visible `SYNC QUEUED` state.
- Queued round edit and hole-score saves on network failure, plus a compact pending-sync panel and retry action on round detail screens.
- Added widget/unit coverage for queue retry dispatch, favorite offline queueing, and round-hole offline queueing.
- Validated with `flutter analyze` and full `flutter test` (`71 passed`).

## 2026-06-10 Phase 4-6 Release Hardening

- Made Favorites, Notifications, and Activity short/empty lists refreshable with always-scrollable physics and consistent empty-state layout.
- Hardened notification preference loading so the preferences sheet fetches preferences independently from notification-list failures.
- Expanded allowed dashboard route handling for `/activity`, nested Profile paths, and nested Rounds paths so backend notification/activity/favorite routes open real app surfaces.
- Added a full-row notification tap target plus stable keys for notification row actions and round detail screens to improve simulator/device navigation coverage.
- Added widget coverage for unread empty notifications, empty activity, and notification-to-round-detail navigation.
- Validated with `flutter analyze`, full `flutter test` (`68 passed`), and `flutter test integration_test/dashboard_nav_smoke_test.dart -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=SMOKE_EMAIL=swinglens.demo.local@example.com --dart-define=SMOKE_PASSWORD=LocalSwing!2026-Demo`.

## 2026-06-09 Phase 6 Notifications And Activity UI

- Added frontend models/API client methods for notifications, unread counts, notification preferences, and the normalized `/v1/activity` feed.
- Replaced the Notifications placeholder with a real screen supporting All/Unread filters, unread summary, mark-read, read-all, delete, preference toggles, empty states, and route-open actions.
- Added a Home notification bell unread badge and a `/activity` screen for recent swings, tracers, rounds, favorites, and notifications while preserving the existing bottom-tab route structure.
- Extended widget coverage for notification read/preference flows and activity feed rendering, and updated the live dashboard smoke to verify seeded notifications.
- Validated with `flutter analyze`, full `flutter test` (`65 passed`), and `flutter test integration_test/dashboard_nav_smoke_test.dart -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=SMOKE_EMAIL=swinglens.demo.local@example.com --dart-define=SMOKE_PASSWORD=LocalSwing!2026-Demo`.

## 2026-06-09 Phase 5 Rounds MVP

- Added Rounds API models/client methods, `/rounds`, `/rounds/start`, and `/rounds/:roundId` routes for scorecard list, start form, detail, hole editing, complete/reopen/delete, and round favorite toggle.
- Updated Stats detail routing to use real Round Stats and Club Stats APIs, while keeping scorecard copy explicit about no GPS, handicap, carry, speed, spin, or launch-monitor estimates.
- Extended widget fakes and coverage for Rounds list, start, detail hole editing, lifecycle actions, and updated dashboard/stat smoke coverage.
- Updated the live dashboard integration smoke to verify persisted Phase 4/5 screens with seeded demo credentials on the iOS simulator.
- Validated with `flutter analyze`, `flutter test` (`63 passed`), and `flutter test integration_test/dashboard_nav_smoke_test.dart -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=SMOKE_EMAIL=swinglens.demo.local@example.com --dart-define=SMOKE_PASSWORD=LocalSwing!2026-Demo`.

## 2026-06-09 Phase 4 Profile, Club Bag, Favorites UI

- Added frontend models/API methods for profile preference fields, club bag items, favorite folders, and favorites.
- Replaced the Profile placeholder hub with actionable Golf Profile, Club Bag, Favorites, Subscription, Privacy, and Sign Out panels.
- Added `/profile/preferences` and `/profile/club-bag` screens for units/default capture/profile edits and active club distance presets.
- Replaced `/favorites` with a real list using folder filters, create/delete folder actions, favorite open/remove actions, and empty states.
- Added save/unsave controls on Swing Detail, Swing Report, and tracer results; capture club selection now loads active club bag items with hardcoded fallback.
- Validated with `flutter analyze`, full `flutter test` (`60 passed`), and live iOS dashboard smoke with demo credentials covering Home, Stats, Profile, Club Bag, Favorites, Rounds, and Notifications.

## 2026-06-09 Stats V1 UI And Demo Simulator Smoke

- Reworked `/stats`, `/stats/swings`, `/stats/tracer`, and `/stats/faults` to use cached dashboard futures, backend-provided titles/body copy, compact route tiles, section metrics, and section activity rows.
- Fixed `StatsDetailScreen` future caching so changing between swings, tracer, and faults reloads the correct endpoint for the same authenticated token.
- Tightened metric and activity-row overflow behavior for long labels, values, deltas, and fault names on compact viewports.
- Added stable `stats-route-*` keys for Stats route tiles and extended the live dashboard smoke to tap Overview, Swings, Tracer, and Faults.
- Expanded widget fixtures/tests for backend `sections`, tracer/fault direct routes, route-specific empty states, and narrow-viewport long metric labels.
- Built, installed, and launched the iOS simulator app against the rebuilt local backend with demo credentials; screenshot confirmed the seeded Home dashboard with tracer review priority and quick actions.
- Validated with `flutter analyze`, full `flutter test` (`51 passed`), and live `flutter test integration_test/dashboard_nav_smoke_test.dart -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 --dart-define=API_BASE_URL=http://localhost:8000`.

## 2026-06-09 Dashboard Audit And Simulator Smoke

- Fixed Home dashboard pull-to-refresh so it refetches `/v1/home`, added a real loading state, and routes expired dashboard auth errors back through logout instead of showing an offline fallback.
- Tightened dashboard UI resilience: metric tiles now size from local layout constraints, long status/text rows ellipsize safely, unsupported backend-provided routes are blocked, and long email-derived dev names collapse to `Golfer`.
- Switched the Performance Snapshot screen to the dedicated `/v1/performance-snapshot` endpoint and made `/stats/faults` API-backed while keeping rounds/clubs as honest placeholders.
- Added widget coverage for refresh, loading, header shortcuts, stats metric routes, empty stats states, and the dedicated performance-snapshot endpoint.
- Added `integration_test/dashboard_nav_smoke_test.dart` to log into the local test account and live-smoke Home, Stats, Tracer, Profile, Rounds, and Notifications on the iOS simulator.
- Validated with `flutter analyze`, full `flutter test` (`50 passed`), and `flutter test integration_test/dashboard_nav_smoke_test.dart -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 --dart-define=API_BASE_URL=http://localhost:8000`.

## 2026-06-09 Local Dev Login Relaunch

- Added debug-build default local login credentials for the Phase 6 tracer validation account while preserving `DEV_LOGIN_EMAIL` and `DEV_LOGIN_PASSWORD` Dart-define overrides.
- Ensured the `USE LOCAL TEST ACCOUNT` button is always available on the sign-in screen during local debug runs and fills the configured local account credentials.
- Relaunched the iPhone 17 Pro Max simulator build against `http://127.0.0.1:8000` with the dev profile defines after confirming backend `/health` was OK.
- Validated with `flutter analyze`, targeted auth/widget coverage, and full `flutter test test/widget_test.dart` (`44 passed`).

## 2026-06-09 Dashboard And Bottom Navigation Rollout

- Replaced the old Home command screen with an API-backed SwingLens command-center dashboard covering header actions, priority status, hero result, quick actions, performance snapshot, focus, favorites preview, and recent activity.
- Added Material 3 bottom navigation with persistent tabs for Rounds, Swing, Home, Tracer, and Profile while preserving `/home`, `/capture/review`, `/capture/tracer`, `/swings`, and swing detail/report routes.
- Added frontend dashboard/stats models and API client methods for `/v1/home` and `/v1/stats/*`, with honest planned placeholders for rounds, favorites, notifications, and unsupported stats domains.
- Updated smoke/widget expectations to use stable dashboard and navigation keys instead of old Home copy.
- Validated with `flutter analyze` and full `flutter test` (`43 passed`).

## 2026-06-09 Phase 6.13 Native iPhone High-FPS Tracer Capture

- Replaced the old native capture stub with a Swift AVFoundation bridge on `com.readthens.swinglensai/capture` for capability scanning, start capture, stop capture, and live diagnostics.
- Added runtime rear-camera format ranking for `1080p240`, `4K120`, `1080p120`, `4K60`, and diagnostic lower modes, with tracer tier labels based on actual supported formats instead of hard-coded model names.
- Native capture attempts to lock focus, exposure, and white balance, disables Flutter camera before native recording, and returns file path plus measured FPS, selected format, lens, timestamps, sample count, dropped frames, device model, and iOS version.
- Updated the guided tracer capture UI to show `HIGH FPS READY`, `STANDARD READY`, or `DIAGNOSTIC ONLY`, use native capture when trusted high-FPS support is available, and serialize native diagnostics into tracer upload metadata.
- Snapshot tracer readiness at record start so native recording can dispose the Flutter camera controller without losing `auto_eligible=true` upload metadata after capture.
- Moved Home quick actions above the performance hero and made the Home/Profile surfaces fully scrollable on compact viewports so guided capture entry points remain tappable.
- Added frontend model/guidance support for native capture gate failures and widget coverage for high-FPS capability classification.
- Validated with `flutter analyze`, full `flutter test` (`43 passed`), `flutter build ios --simulator --debug`, and `flutter build ios --debug --no-codesign`; signed device install remains blocked by missing local Apple development signing credentials.

## 2026-06-09 Real-Range Shot Tracer Readiness UI

- Expanded tracer readiness with launch-zone, forward-target, and one-second stable-hold checks so guided capture has an explicit `RANGE READY` gate before real auto-tracer recordings.
- Added visible capture rows for `BALL IN LAUNCH ZONE`, `TARGET FORWARD`, `HELD STILL 1 SEC`, and `RANGE READY`, plus review-panel metadata showing `AUTO ELIGIBLE` and stable-hold duration.
- Serialized `phase6_12_range_tracer_guide_v1`, `stable_duration_ms`, stricter readiness checks, and richer capture-quality data into tracer upload metadata for backend enforcement.
- Added frontend guidance strings for the new backend reject reasons and widget/unit coverage for poor range geometry and short stable holds.
- Validated with `flutter analyze` and full `flutter test` (`37 passed`).

## 2026-06-09 Shot Tracer Line Presets

- Updated the tracer capture style selector to the MVP visual-system presets: `signature`, `broadcast_white`, and `power_red`.
- Changed the default new-capture tracer style to `signature`, which the backend normalizes to the Signature Green Gold renderer preset.
- Updated the capture guide accent preview for Signature Green Gold and Power Red while keeping legacy saved tracer styles backend-compatible.
- Validated with `flutter analyze lib/src/screens/upload_screens.dart test/widget_test.dart` and `flutter test test/widget_test.dart` (`35 passed`).

## 2026-06-08 Phase 6.11 Trusted Tracer Render Metadata UI

- Added `TracerResult.render` parsing so the app can honor backend render availability metadata instead of treating legacy private render keys as proof of a playable tracer.
- Updated model fallback rules so weak `needs_review` / `NEEDS BETTER CAPTURE` results with stale render keys still report no playable render when backend metadata says unavailable.
- Added widget/model coverage for render metadata overriding legacy private-key fallbacks.
- Validated with `flutter analyze` and full `flutter test` (`35 passed`).

## 2026-06-08 Phase 6.7-6.10 Tracer Trust And Redaction UI

- Added structured capture-gate parsing for tracer results so `NEEDS BETTER CAPTURE` now shows exact `FIX BEFORE RETRY` guidance from backend failed checks.
- Kept manual tracer edit controls hidden and updated weak-capture UI to focus on guided recapture instead of a video surface/HUD when no trusted render exists.
- Updated models to use `has_render_video` / `has_thumbnail` and opaque ids, not private render object keys.
- Removed `SwingVideo.storageKey` usage and the Swing Detail `OBJECT KEY` display; Film Room temp files now use safe id-based filenames with authenticated video downloads.
- Added widget coverage proving storage keys are not displayed and failed capture-gate guidance renders.
- Validated with `flutter analyze` and full `flutter test` (`34 passed`).

## 2026-06-08 Phase 6.6 Guided Shot Tracer Capture Enforcement UI

- Added `sensors_plus` and a reusable tracer readiness helper for rear-camera, guide overlay, ball anchor, target line, white-ball confirmation, phone-level, and one-second stability checks.
- Shot tracer capture now disables `RECORD VIDEO` until readiness passes; simulator/no-sensor environments are explicitly labeled `UNVERIFIED TEST CAPTURE` and serialize non-auto-eligible metadata.
- Added iOS `NSMotionUsageDescription` while keeping existing camera/microphone permissions.
- Tracer upload metadata now includes `auto_eligible`, `readiness_checks`, `phone_level_degrees`, `stability_score`, `stability_samples`, `white_ball_confirmed`, `capture_source`, `guide_version`, and `simulator_or_unverified`.
- Tracer Film Room weak results now include a direct `RECORD GUIDED TRACER` action and keep manual tracer edit controls hidden.
- Added widget/unit coverage for the readiness gate, unverified simulator capture behavior, white-ball blocking, and needs-better-capture result UI.
- Validated with `flutter analyze` and full `flutter test` (`34 passed`).

## 2026-06-08 Phase 6.5 Shot Tracer Accuracy Gate UI

- Removed user-facing manual tracer edit controls from Tracer Film Room; weak results now show `NEEDS BETTER CAPTURE` with guided recapture guidance instead of editable path sliders.
- Added `TracerResult` helpers for `needsBetterCapture`, impact/apex/landing timestamps, and auto-only status labels.
- Added a broadcast-style tracer HUD with impact, apex, landing, and a compact timeline under the rendered tracer video.
- Updated tracer upload copy and metadata so guided rear-camera captures are marked `auto_eligible`, while gallery imports remain useful for testing but are treated conservatively.
- Updated widget coverage to assert the manual edit UI stays hidden and needs-better-capture copy is shown.
- Validated with `flutter analyze` and full `flutter test` (`31 passed`).

## 2026-06-08 Phase 6.3 Visual Flight Metrics UI

- Extended `TracerResult` with `metrics.flight` helpers for visual launch, start-line delta, apex rise, curve bias, status, and summary copy.
- Added a compact `VISUAL FLIGHT` block to Tracer Film Room that shows image-space flight metrics while keeping the no-launch-monitor disclaimer visible.
- Kept curve wording screen-relative and avoided slice/draw/fade labels until calibrated or trained shot-shape analysis exists.
- Updated widget fixtures and coverage for flight metrics in the tracer result panel.
- Validated with `flutter analyze` and full `flutter test` (`31 passed`).

## 2026-06-08 Phase 6.1 Accurate Ball Tracking UI

- Extended tracer result models with `tracking`, `pathSource`, `trackingLabel`, observed/interpolated point counts, gap count, and tracking failure reasons from backend `metrics.tracking`.
- Updated Tracer Film Room status copy to show `AUTO TRACKED`, `NEEDS REVIEW`, or `MANUAL REVIEWED`, plus confidence, detected/interpolated/gap counts, and review notes instead of shot-shape labels.
- Updated manual tracer edit payloads to include timestamped start/mid/end control points so reviewed paths can rerender progressively.
- Expanded widget coverage for needs-review tracking details and timestamped manual control-point save behavior.
- Validated with `flutter analyze` and full `flutter test` (`31 passed`).

## 2026-06-07 Phase 6 Shot Tracer MVP

- Added a `SHOT TRACER` home entry and `/capture/tracer` route that reuses the existing capture flow in rear-angle tracer mode.
- Added the tracer capture guide with translucent golfer alignment outline, draggable/tappable ball anchor, target-line arrow, style selector (`classic_white`, `green_glow`, `thin_line`), and alignment checklist metadata.
- Uploads from tracer mode now create `session_type=tracer`, attach `angle=rear_tracer`, and serialize tracer setup metadata for the backend worker.
- Added tracer API client methods and models for tracer jobs, results, edits, render jobs, and authenticated private render downloads.
- Updated swing detail to route tracer sessions to a `TRACER FILM ROOM` panel instead of pose analysis, with create/poll states, render playback fallback, visual-only no-launch-monitor copy, manual path edit controls, and rerender.
- Updated privacy inventory UI to show tracer result counts.
- Validated with `flutter analyze` and full `flutter test` (`31 passed`).

## 2026-06-07 Analysis Progress Smoothing

- Added client-side displayed progress for active analysis jobs so sparse backend progress no longer appears stuck at 10%; the UI advances conservatively toward 99% while the job is still active.
- Added a brief `COMPLETE · 100%` processing state before the completed score overview loads, keeping the progress bar, scan overlay, and checklist visually consistent through completion.
- Kept backend/API contracts unchanged; real job success/failure still controls the transition to 100%, overview, retry, and polling-error states.
- Added widget coverage for sparse 10% backend progress smoothing and the 100% completion handoff.
- Validated with `flutter test test/widget_test.dart`, full `flutter test`, and `flutter analyze --no-fatal-infos`.

## 2026-06-07 Simulator Upload Service Confirmation

- Confirmed the local Docker backend stack is running for simulator testing: API, worker, Postgres, Redis, and MinIO.
- Added an explicit `Content-Length` header to presigned object-storage PUT uploads so iOS/Dio stream uploads are accepted reliably by local MinIO.
- Rebuilt and reinstalled the iOS simulator app with local API and test-account dart-defines, then confirmed the app is logged in on the Home screen with video consent accepted.
- Validated with host-side login, presign, MinIO PUT, upload-complete, and video attach smoke checks, plus `flutter test` and `flutter analyze --no-fatal-infos`.

## 2026-06-07 Local Simulator Test Convenience

- Added a debug-only sign-in autofill action that appears when `DEV_LOGIN_EMAIL` and `DEV_LOGIN_PASSWORD` are passed through dart-defines, avoiding manual paste of long local test credentials.
- Rebuilt and installed the iOS simulator app with local API and test-account dart-defines, granted Photos/camera/microphone permissions, and imported the three local MOV sample videos into the booted simulator.
- Validated with `flutter test` and `flutter analyze --no-fatal-infos`.

## 2026-06-07 Phase 5 App Store, Privacy, Subscription, And TestFlight

- Added a hidden-by-default Sign in with Apple UI boundary using `sign_in_with_apple`, wired to backend Apple auth through `AppleSignInService`; email/password remains the visible default until the feature flag is enabled.
- Added RevenueCat client setup with UUID app-user-id configuration, subscription status/sync UI, restore-purchases and purchase service boundaries, backend entitlement sync calls, and App Store subscription management link.
- Added Settings, Privacy Data, Subscription, and Delete Account screens with legal links, typed `DELETE` confirmation, backend privacy inventory display, account deletion, and existing delete-video confirmation coverage.
- Added App Store privacy inventory and TestFlight flow docs under `docs/app_store/` and `docs/release/`, plus iOS entitlement/project updates for Apple sign-in capability.
- Hardened Sign in with Apple to fetch a backend nonce and send it through the native Apple credential request before backend login.
- Validated with `flutter analyze`, full `flutter test` (25 passed), Docker-backed live API smoke via the backend, and artifact output under root `tests/test_20260607_08`.

## 2026-06-07 Analysis Experience Redesign

- Reworked swing detail analysis into a staged experience: `START ANALYSIS`, cinematic processing checklist, compact score-first overview, and a separate `/swings/:sessionId/report` detailed breakdown.
- Added overview/detailed Film Room modes so the summary keeps replay controls minimal while the breakdown keeps slider, phase chips, speed controls, overlay toggles, event review, and fault evidence.
- Added score/finding/metric fallback logic using existing analysis result, swing report, video quality, pose coverage, and phase data without backend contract changes.
- Updated widget and integration smoke expectations for the new analysis overview, processing checklist, full report route, and compact Film Room mode.
- Validated with `flutter test` and `flutter analyze --no-fatal-infos`; plain `flutter analyze` still exits on pre-existing info-level lints in unrelated files.

## 2026-06-07 Phase 4.9 Deeper Body Metrics

- Updated the Deep Swing Report panel to render the full backend metric-card list instead of truncating after six cards, so new arm, stance, extension, and body-plane metrics remain visible.
- Added Film Room live badges for backend overlay metrics: lead-arm angle, stance width, arm extension, body-plane tilt, and hand-line proxy.
- Expanded widget fixtures and coverage to verify late metric cards and the new live badges render from additive backend JSON without model/schema changes.
- Validated with `flutter analyze` and full `flutter test`.

## 2026-06-07 Phase 4.8 Film Room Aspect Hardening

- Changed the Film Room video layer from stretch-fill rendering to contained rendering so the video is not squeezed when controller metadata and backend display dimensions disagree.
- Added widget/model coverage proving rotated portrait MOV overlay tracks keep a portrait aspect ratio in the Flutter model.
- Validated with full `flutter analyze`, full `flutter test`, and an iOS simulator install/launch on iPhone 17 Pro Max.

## 2026-06-07 Phase 4.8 Deep Swing Metrics And Event Review

- Added event-review API client methods and models for reviewed phase overrides, swing reports, metric cards, and findings.
- Added `ADJUST EVENTS` mode to Swing Film Room so users can select P1/P4/P7/P10, scrub to the intended moment, set the event, save review overrides, or reset back to detection.
- Updated Film Room phase chips and active event badge to show reviewed checkpoint sources while continuing to use detected checkpoints when no review exists.
- Added a Deep Swing Report section to swing detail with provisional movement score, metric cards, primary finding, evidence, drill, next swing goal, and pose-analysis limitations.
- Reloads overlay/report data after saving or resetting event reviews so the slider ticks, labels, fault evidence, and report reflect effective phases.
- Validated with `flutter analyze` and `flutter test`, including widget coverage for adjust/save/reset review and deep report rendering.

## 2026-06-07 Phase 4.7 Swing Event Detection Hardening

- Extended overlay checkpoint models with backend detection method/status metadata.
- Added an active Film Room event confidence badge that shows `EVENT NN%` for detected checkpoints and `NEEDS REVIEW` for low-confidence/fallback events.
- Updated Film Room playback duration so the scrubber and video review stop at the backend clipped swing window instead of continuing into post-finish walk-off footage.
- Added optional API-client support for `force=true` analysis regeneration.
- Added `integration_test/film_room_phase47_smoke_test.dart` to verify corrected P1/P4/P7/P10 checkpoint chips, event confidence, slow-motion controls, and absence of the stale `loss_of_posture` chip on the sample result.
- Validated with `flutter analyze`, `flutter test`, and live iOS simulator artifacts under root `tests/test_20260607_03` and `tests/test_20260607_04`.

## 2026-06-07 Phase 4.6 Fluid Swing Film Room

- Added a Swing Film Room section at the top of Swing Detail that downloads the authenticated private video to a temp file and plays it with `video_player`.
- Added overlay-track models/API methods and a reusable `SwingOverlayPainter` so full-video playback and keyframe cards share the same skeleton/guide rendering.
- Added film-room transport controls: play/pause, 0.1-second stepping, scrubber with phase/fault ticks, phase checkpoint chips, fault checkpoint chips, and `0.25X`/`0.50X`/`1X` speed choices.
- Added overlay toggles for skeleton, spine, hips/shoulders, and fault reference line; fault marker taps now keep the mistake/fix panel visible while playback continues.
- Moved static keyframes under a secondary `KEY MOMENTS` section while keeping the Analysis Prototype and MVP Diagnosis content available below the film room.
- Added `path_provider`, widget coverage for loaded film-room controls/fault panel, and live iOS simulator smoke coverage with screenshots under root `tests/test_20260607_02`.
- Validated with `flutter analyze`, `flutter test`, and `flutter test integration_test/film_room_phase46_smoke_test.dart -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71`.

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
