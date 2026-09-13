# aadya_plus (Patient App) — Completion Checklist

**Stack:** Flutter · Provider (state) · http · socket_io_client · webview_flutter
**Role:** Consumer app — find doctors, book, consult, prescriptions, pharmacy, labs, physio, records.
**Current state:** Most screens exist and happy-path flows work. Main gaps: no push notifications, no payment SDK, and two screens still use hardcoded mock data.

Legend: 🔴 P0 (launch blocker) · 🟠 P1 (strongly recommended) · 🔵 P2 (fast-follow)

---

## 1. Notifications (biggest gap)
- [ ] 🔴 Add `firebase_messaging` + `flutter_local_notifications` (not in pubspec today).
- [ ] 🔴 Request notification permission; get FCM token; send it to backend (`POST /notifications/device-token`).
- [ ] 🔴 Handle foreground, background and terminated push; deep-link taps to the right screen (appointment/chat/order).
- [ ] 🔴 Keep the existing in-app notifications list, but drive the unread badge from real-time events.
- [ ] 🟠 Local notifications for medicine reminders and appointment reminders.
- [ ] 🔵 Notification preferences screen (per-category toggles).

## 2. Replace Mock Data (must be live before launch)
- [ ] 🔴 `screens/health_records/health_records_screen.dart` — renders hardcoded records. Wire to real backend health-records API + document upload (image_picker/file_picker already in pubspec).
- [ ] 🔴 `screens/payments/payments_screen.dart` — hardcoded transaction list. Fetch real payment history from backend.
- [ ] 🟠 `screens/home/dashboard_screen.dart` — remove/limit placeholder doctor cards; show proper empty/loading states.

## 3. Payments
- [ ] 🔴 Add `razorpay_flutter` (no payment SDK today). Implement checkout for consultation, pharmacy cart, and lab tests.
- [ ] 🔴 Call backend create-order → open Razorpay → verify signature → show success/receipt.
- [ ] 🟠 UPI as the default option; support COD for pharmacy orders.
- [ ] 🟠 Downloadable invoice/receipt after payment.

## 4. Video Consultation
- [ ] 🟠 Current video call is a WebView to an external meeting link. Harden camera/mic permissions & reconnection, or migrate to a proper video SDK (Agora/100ms/Jitsi SDK). Label as beta if kept on WebView.

## 5. New Patient Features (India-market)
- [ ] 🔴 Real ratings & reviews for doctors (post-consult) — `flutter_rating_bar` already available.
- [ ] 🟠 Family / dependent profiles (book for parents, kids, spouse).
- [ ] 🟠 Digital health vault: upload/store/share prescriptions & reports.
- [ ] 🟠 Order & delivery tracking for pharmacy orders.
- [ ] 🟠 Home lab sample-collection booking.
- [ ] 🔵 Auto-refill subscription for chronic meds; membership plan; referral & loyalty.
- [ ] 🔵 AI symptom checker; health feed/articles.

## 6. Localisation & Onboarding
- [ ] 🟠 OTP/phone-first login (phone is primary identity in India).
- [ ] 🟠 Hindi + regional language support (`intl` present — add localisation files + language switcher).
- [ ] 🔵 Onboarding tour on first launch.

## 7. Polish & Store Readiness
- [ ] 🟠 Consistent loading (shimmer/skeleton), empty and error states across all screens.
- [ ] 🟠 Offline/network-failure handling and retry.
- [ ] 🟠 Crash reporting + analytics (e.g. Firebase Crashlytics/Analytics).
- [ ] 🟠 Medical disclaimers + explicit health-data consent at onboarding; account-deletion path (store requirement).
- [ ] 🔴 App icons, splash, store listing assets, permission rationales; test release build on real devices.
- [ ] 🔵 Widget/integration tests for core flows (no tests today).
