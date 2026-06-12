# Phase 5 TestFlight And App Store Checklist

## Required App Store Connect Setup

- Bundle ID: `com.readthens.swinglensai.swinglensAi`.
- Enable Sign in with Apple for the app identifier.
- Create RevenueCat project, iOS app, offering, products, and entitlement `swinglens_pro`.
- Configure `REVENUECAT_IOS_API_KEY` in TestFlight build settings.
- Configure backend `REVENUECAT_SECRET_API_KEY` and `REVENUECAT_WEBHOOK_AUTH_TOKEN`.
- Add RevenueCat webhook URL: `/v1/webhooks/revenuecat`.
- Set real backend `PRIVACY_POLICY_URL`, `TERMS_URL`, and `SUBSCRIPTION_MANAGEMENT_URL`.

## App Privacy Data Inventory

Declare the app collects or processes:

- Contact info: email address.
- User ID: backend user id / RevenueCat app user id.
- User content: private swing videos and keyframe images.
- Fitness/body-related derived data: pose landmarks, swing metrics, movement findings.
- Purchases: subscription product, store, entitlement, expiration.
- Diagnostics/usage records: audit events and analysis job state.

## TestFlight Smoke

- Build with `flutter build ipa --release --dart-define=API_BASE_URL=<production-api> --dart-define=APPLE_SIGN_IN_ENABLED=true --dart-define=REVENUECAT_IOS_API_KEY=<public-sdk-key>`.
- Upload to App Store Connect and install via TestFlight.
- Sign in with Apple.
- Complete onboarding and video consent.
- Upload a swing video and confirm Swing Library / Film Room.
- Start/restore subscription; verify backend `/v1/revenuecat/customer` shows entitlement.
- Confirm RevenueCat webhook idempotency.
- Open Privacy Policy, Terms, and App Store subscription management links.
- Delete one video and confirm it disappears.
- Delete account and confirm login is blocked afterward.
