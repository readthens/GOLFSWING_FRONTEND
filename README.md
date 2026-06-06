# GOLFSWING_FRONTEND

Flutter mobile app for SwingLens AI. Phase 1 is iOS-first and focuses on auth,
onboarding, video-processing consent, video upload, and the swing library.

## Stack

- Flutter
- `go_router` for routes
- `flutter_riverpod` for app state
- `dio` for API calls
- `flutter_secure_storage` for token storage
- `image_picker` for Phase 1 video selection
- `video_player` reserved for swing playback surfaces

## Run

Start the backend at `http://localhost:8000`, then:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

For an iOS simulator talking to a host-machine backend, keep `localhost`. For a
physical device, pass the host machine LAN IP as `API_BASE_URL`.

## Validate

```bash
flutter analyze
flutter test
```

## Design

Follow the workspace design guide:

- `docs/design/Golf_AI_App_DESIGN.md`
- `docs/design/login_signup_mockups.svg`

The app should remain cinematic, black-and-white, minimal, and technical.
