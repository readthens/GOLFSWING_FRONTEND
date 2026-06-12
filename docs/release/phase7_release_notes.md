# Phase 7 Release Notes

## Scope

Phase 7 completes the first offline-sync product layer for SwingLens AI:

- Device-local retry queue for favorites, rounds, and uploads.
- Idempotent backend writes for replay-safe offline retries.
- Automatic sync after auth restore, app launch, new queued work, and app resume.
- Sync Center visibility for pending, syncing, and failed work.
- Failed-item cleanup in Sync Center without removing pending work.
- Manual backend cleanup command for stale idempotency records.

## Validated Locally

Backend:

- `ruff check .`
- `pytest -q`
- Docker API/worker rebuild.
- `GET /health`
- `python -m app.commands.seed_demo`
- `python -m app.commands.cleanup_idempotency --older-than-days 7 --dry-run`

Frontend:

- `flutter analyze`
- `flutter test`
- `integration_test/dashboard_nav_smoke_test.dart` on iPhone 17 Pro Max simulator.
- `integration_test/phase7_sync_smoke_test.dart` on iPhone 17 Pro Max simulator.

## Demo Account

```text
swinglens.demo.local@example.com
LocalSwing!2026-Demo
```

Reseed demo data after running the Phase 7 sync smoke because the smoke mutates favorites, rounds, uploads, and queue state.

## Release Checklist

- Backend CI passes on the release branch.
- Frontend CI passes on the release branch.
- Production backend has a daily scheduler for `python -m app.commands.cleanup_idempotency --older-than-days 7`.
- Production `API_BASE_URL` is HTTPS and not `localhost`.
- TestFlight build uses production API, Apple Sign In flag, and RevenueCat public iOS key.
- App Store Connect privacy, terms, subscriptions, and Sign in with Apple capabilities are configured.
- Real-device smoke confirms camera, Photos, native high-FPS tracer capture, upload, analysis, Sync Center, and subscription restore.

## Known Gaps

- No GPS/course-map, handicap, carry, ball speed, spin, or launch-monitor metrics are claimed.
- Real-device TestFlight signing still depends on local Apple Developer credentials and App Store Connect configuration.
- Production crash/error logging is not wired yet.
