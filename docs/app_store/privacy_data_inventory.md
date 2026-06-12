# App Store Privacy Data Inventory

Engineering inventory for SwingLens AI App Store Connect privacy answers. Legal/product review is required before external TestFlight or App Store submission.

## Data Collected

- Contact info: account email.
- Identifiers: internal user UUID and RevenueCat App User ID.
- User content: private swing videos, capture metadata, club/location fields, optional notes.
- Motion/analysis data: pose landmarks, keyframes, swing metrics, event reviews, and provisional reports.
- Purchases: RevenueCat entitlement state, product ID, store, and expiration when subscriptions are enabled.
- Diagnostics: upload status, analysis job status, and user-visible audit events.

## In-App Controls

- Delete video from Swing Detail.
- Delete account from Settings.
- Privacy inventory from Settings -> Privacy and Data.
- Subscription status and App Store subscription management from Settings -> Subscription.

## Submission Notes

- Replace placeholder policy URLs in backend env before production.
- Include RevenueCat as a third-party data processor when purchases are enabled.
- Describe analysis outputs as user content/motion-derived app functionality data, not coach-grade diagnosis.
