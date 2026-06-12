# TestFlight Flow

## Local Gates

```bash
flutter analyze
flutter test
flutter build ios --simulator --debug
```

For Phase 7 offline sync, also run the live simulator smoke from `docs/release/phase7_live_sync_validation.md`.

## Release Build

Use a production HTTPS backend URL. Do not ship `localhost`.

```bash
flutter build ipa \
  --release \
  --build-name 1.0.0 \
  --build-number 1 \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=APPLE_SIGN_IN_ENABLED=true \
  --dart-define=REVENUECAT_IOS_API_KEY=<public_ios_key>
```

## App Store Connect Checklist

- App ID has Sign in with Apple enabled.
- In-App Purchase capability is enabled when RevenueCat products are live.
- Subscription products, entitlement, offering, sandbox tester, tax/banking/agreements are configured.
- Privacy policy URL and terms URL are production URLs.
- App privacy answers include account, user content, analysis, diagnostics, and purchase data.
- External TestFlight build is submitted for beta review if external testers are invited.

## Smoke Test

- Launch build.
- Register/sign in and verify Sign in with Apple when `APPLE_SIGN_IN_ENABLED=true`.
- Complete onboarding and video consent.
- Upload a video.
- Run analysis.
- Open Swing Film Room.
- Delete a video.
- Open Settings -> Privacy and Subscription.
- Restore purchases and confirm entitlement sync.
- Confirm Delete Account screen requires typed confirmation.
- Open Sync Center and confirm pending/failed offline work renders correctly.
