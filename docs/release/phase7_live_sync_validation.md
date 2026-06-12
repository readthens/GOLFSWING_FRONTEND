# Phase 7 Live Sync Validation

Run this checklist before shipping changes that touch offline queueing, idempotent writes, uploads, rounds, favorites, or Sync Center.

## Backend

```bash
cd /Users/matthew/Documents/AI-APP/GOLF_SWING_AI_APP/GOLFSWING_BACKEND
docker compose up -d
curl -fsS http://localhost:8000/health
docker compose exec -T api python -m app.commands.seed_demo
```

Expected seed account:

- Email: `swinglens.demo.local@example.com`
- Password: `LocalSwing!2026-Demo`

## Simulator

```bash
xcrun simctl boot BE32D424-FA45-4D4B-8EA2-0B09FB582E71 || true
open -a Simulator
xcrun simctl bootstatus BE32D424-FA45-4D4B-8EA2-0B09FB582E71 -b
```

## Smoke Tests

```bash
cd /Users/matthew/Documents/AI-APP/GOLF_SWING_AI_APP/GOLFSWING_FRONTEND
flutter test integration_test/dashboard_nav_smoke_test.dart \
  -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SMOKE_EMAIL=swinglens.demo.local@example.com \
  --dart-define=SMOKE_PASSWORD='LocalSwing!2026-Demo'

flutter test integration_test/phase7_sync_smoke_test.dart \
  -d BE32D424-FA45-4D4B-8EA2-0B09FB582E71 \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SMOKE_EMAIL=swinglens.demo.local@example.com \
  --dart-define=SMOKE_PASSWORD='LocalSwing!2026-Demo'
```

The Phase 7 sync smoke validates:

- Queued favorite auto-syncs through the live API.
- Queued round edit auto-syncs through the live API.
- Queued upload auto-syncs through presign, MinIO PUT, complete, session create, and video attach.
- Upload retry creates exactly one matching session.
- Missing retained upload file enters `FAILED` state and appears in Sync Center.

## Restore Demo Data

The sync smoke creates and mutates demo data. Reseed after the smoke:

```bash
cd /Users/matthew/Documents/AI-APP/GOLF_SWING_AI_APP/GOLFSWING_BACKEND
docker compose exec -T api python -m app.commands.seed_demo
```

## Idempotency Cleanup

For local/manual retention cleanup:

```bash
cd /Users/matthew/Documents/AI-APP/GOLF_SWING_AI_APP/GOLFSWING_BACKEND
docker compose exec -T api python -m app.commands.cleanup_idempotency --older-than-days 7 --dry-run
docker compose exec -T api python -m app.commands.cleanup_idempotency --older-than-days 7
```
