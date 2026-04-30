# SERVIO Mobile vs Website Feature Gap Report

**Generated:** 2026-04-29  
**Branch:** mostafabdelaal/backend-test  
**Analyst:** Claude Code (automated analysis)

---

## 1. Executive Summary

| Metric | Count |
|--------|-------|
| Total website pages | 22 |
| Total mobile screens | 37 (including 7 design-system/utility screens) |
| Mobile screens aligned to a website page | 20 |
| Fully implemented (mobile matches website) | 9 |
| Partially implemented (UI exists, mock data only) | 11 |
| Missing in mobile (website page has no mobile counterpart) | 7 |
| Mobile-only screens (no website equivalent) | 10 |

**Critical finding:** The mobile app has zero live backend integration. Every single screen uses hardcoded demo data, local SharedPreferences storage, or in-memory mock objects. No `http` or `dio` package calls exist anywhere in the codebase. The app is a polished prototype/demo, not a production-connected client.

---

## 2. Page/Screen Inventory

### Website Pages (22 total)

| # | Page | File Path |
|---|------|-----------|
| 1 | Home (Landing) | `servio_frontend/html/index.html` |
| 2 | Services Marketplace | `servio_frontend/html/services-marketplace.html` |
| 3 | Service Details | `servio_frontend/html/service-details.html` |
| 4 | Technician Listing | `servio_frontend/html/technician-listing.html` |
| 5 | Technician Profile | `servio_frontend/html/technician-profile.html` |
| 6 | Booking Form | `servio_frontend/html/booking.html` |
| 7 | Booking Confirmation | `servio_frontend/html/booking-confirmation.html` |
| 8 | Booking Details | `servio_frontend/html/booking-details.html` |
| 9 | Customer Dashboard | `servio_frontend/html/customer-dashboard.html` |
| 10 | Technician Dashboard | `servio_frontend/html/technician-dashboard.html` |
| 11 | Admin Dashboard | `servio_frontend/html/admin-dashboard.html` |
| 12 | Messages / Chat | `servio_frontend/html/messages.html` |
| 13 | Smart Match (AI) | `servio_frontend/html/smart-match.html` |
| 14 | AI Cost Estimator | `servio_frontend/html/ai-estimator.html` |
| 15 | Login | `servio_frontend/html/login.html` |
| 16 | Sign Up | `servio_frontend/html/signup.html` |
| 17 | Forgot Password | `servio_frontend/html/forgot-password.html` |
| 18 | Reset Password | `servio_frontend/html/reset-password.html` |
| 19 | Join as Technician | `servio_frontend/html/join-as-technician.html` |
| 20 | About | `servio_frontend/html/about.html` |
| 21 | Contact | `servio_frontend/html/contact.html` |
| 22 | 404 Error | `servio_frontend/html/404.html` |

### Mobile Screens (37 total — 30 feature screens + 7 design/utility)

| # | Screen | File Path |
|---|--------|-----------|
| 1 | Splash Screen | `mobile-app/lib/src/features/onboarding/splash_screen.dart` |
| 2 | Onboarding | `mobile-app/lib/src/features/onboarding/onboarding_screen.dart` |
| 3 | Role Selection | `mobile-app/lib/src/features/auth/role_selection_screen.dart` |
| 4 | Login | `mobile-app/lib/src/features/auth/login_screen.dart` |
| 5 | Sign Up (multi-step) | `mobile-app/lib/src/features/auth/sign_up_screen.dart` |
| 6 | Customer Home | `mobile-app/lib/src/features/customer/customer_home_screen.dart` |
| 7 | Customer Dashboard | `mobile-app/lib/src/features/customer/customer_dashboard_screen.dart` |
| 8 | Services Marketplace | `mobile-app/lib/src/features/customer/services_marketplace_screen.dart` |
| 9 | Service Detail | `mobile-app/lib/src/features/customer/service_detail_screen.dart` |
| 10 | Technician Listing | `mobile-app/lib/src/features/customer/technician_listing_screen.dart` |
| 11 | Technician Profile (Customer view) | `mobile-app/lib/src/features/customer/technician_profile_screen.dart` |
| 12 | Booking Step 1 – Review | `mobile-app/lib/src/features/booking/booking_step_one_screen.dart` |
| 13 | Booking Step 2 – Date/Payment | `mobile-app/lib/src/features/booking/booking_step_two_screen.dart` |
| 14 | Booking Step 3 – Confirm | `mobile-app/lib/src/features/booking/booking_step_three_screen.dart` |
| 15 | Booking Confirmation | `mobile-app/lib/src/features/booking/booking_confirmation_screen.dart` |
| 16 | My Bookings | `mobile-app/lib/src/features/customer/my_bookings_screen.dart` |
| 17 | Booking Details | `mobile-app/lib/src/features/customer/my_bookings_screen.dart` (nested class `BookingDetailsScreen`) |
| 18 | Write Review | `mobile-app/lib/src/features/customer/write_review_screen.dart` |
| 19 | Messages List | `mobile-app/lib/src/features/messages/messages_screen.dart` |
| 20 | Chat Screen | `mobile-app/lib/src/features/messages/chat_screen.dart` |
| 21 | AI Smart Match | `mobile-app/lib/src/features/customer/ai_smart_match_screen.dart` |
| 22 | AI Finishing Estimator | `mobile-app/lib/src/features/customer/ai_finishing_estimator_screen.dart` |
| 23 | Customer Profile & Settings | `mobile-app/lib/src/features/customer/customer_profile_screen.dart` |
| 24 | Notifications | `mobile-app/lib/src/features/shared/notifications_screen.dart` |
| 25 | Search Results | `mobile-app/lib/src/features/shared/search_results_screen.dart` |
| 26 | Technician Dashboard | `mobile-app/lib/src/features/technician/technician_dashboard_screen.dart` |
| 27 | Job Queue | `mobile-app/lib/src/features/technician/job_queue_screen.dart` |
| 28 | Job Details | `mobile-app/lib/src/features/technician/job_details_screen.dart` |
| 29 | Earnings | `mobile-app/lib/src/features/technician/earnings_screen.dart` |
| 30 | Availability Manager | `mobile-app/lib/src/features/technician/availability_manager_screen.dart` |
| 31 | Technician Profile/Settings | `mobile-app/lib/src/features/technician/technician_profile_screen.dart` |
| 32 | Verification Upload | `mobile-app/lib/src/features/technician/verification_upload_screen.dart` |
| 33 | About | `mobile-app/lib/src/features/marketing/about_screen.dart` |
| 34 | Contact | `mobile-app/lib/src/features/marketing/contact_screen.dart` |
| 35 | Error Screen | `mobile-app/lib/src/features/shared/error_screen.dart` |
| 36 | Design Showcase | `mobile-app/lib/src/features/design_showcase/design_showcase_screen.dart` |
| 37 | App State + Routing | `mobile-app/lib/src/app.dart` |

---

## 3. Feature Mapping Table

| Website Page | Website File | Mobile Screen | Mobile File | Status | Notes |
|---|---|---|---|---|---|
| Home / Landing | `html/index.html` | Customer Home | `customer/customer_home_screen.dart` | ⚠️ Partial | Mobile home is more of an entry dashboard. No hero section, no marketing copy. Service grid and technician cards are present but load from mock data (`kDemoTechnicians`). |
| Services Marketplace | `html/services-marketplace.html` | Services Marketplace | `customer/services_marketplace_screen.dart` | ⚠️ Partial | UI exists. Data is hardcoded demo services. No API call to `GET /api/v1/services`. |
| Service Details | `html/service-details.html` | Service Detail | `customer/service_detail_screen.dart` | ⚠️ Partial | UI exists. Data hardcoded; `serviceId` parameter passed but not used to fetch from backend. |
| Technician Listing | `html/technician-listing.html` | Technician Listing | `customer/technician_listing_screen.dart` | ⚠️ Partial | UI exists, uses `kDemoTechnicians` list. No call to `GET /api/v1/users/workers`. |
| Technician Profile | `html/technician-profile.html` | Technician Profile | `customer/technician_profile_screen.dart` | ⚠️ Partial | UI exists, uses `kDemoTechnicians`. No call to `GET /api/v1/users/workers/:id`. |
| Booking Form | `html/booking.html` | Booking Step 1–3 | `booking/booking_step_one_screen.dart`, `booking_step_two_screen.dart`, `booking_step_three_screen.dart` | ⚠️ Partial | 3-step flow exists. On confirm, writes to local `BookingsProvider` (SharedPreferences). Does NOT call `POST /api/v1/bookings`. |
| Booking Confirmation | `html/booking-confirmation.html` | Booking Confirmation | `booking/booking_confirmation_screen.dart` | ✅ Full | UI is complete. Generates local reference and PIN. No backend dependency. |
| Booking Details | `html/booking-details.html` | Booking Details | nested `BookingDetailsScreen` in `my_bookings_screen.dart` | ⚠️ Partial | UI shows progress tracker, technician card, map placeholder. "Map Preview" is a static placeholder. No real-time status from backend. |
| Customer Dashboard | `html/customer-dashboard.html` | Customer Dashboard | `customer/customer_dashboard_screen.dart` | ⚠️ Partial | Rich UI with Overview/Bookings/History/Favourites tabs. Uses local `BookingsProvider` + `kDemoTechnicians`. No live data from backend. |
| Technician Dashboard | `html/technician-dashboard.html` | Technician Dashboard | `technician/technician_dashboard_screen.dart` | ⚠️ Partial | UI shows earnings summary, job queue preview. All data hardcoded inline in the screen. No API calls. |
| Admin Dashboard | `html/admin-dashboard.html` | (none) | — | ❌ Missing | No admin panel in mobile. Admin portal is web-only. |
| Messages / Chat | `html/messages.html` | Messages List + Chat Screen | `messages/messages_screen.dart`, `messages/chat_screen.dart` | ⚠️ Partial | UI is complete with conversation list and chat bubbles. Uses in-memory `MessagesProvider` with demo conversations and auto-reply bot. No real API. |
| Smart Match (AI) | `html/smart-match.html` | AI Smart Match | `customer/ai_smart_match_screen.dart` | ⚠️ Partial | UI accepts text input and shows hardcoded mock results ("Ahmed Nabil, 97% match"). Does NOT call `POST /api/v1/ai/recommend`. |
| AI Cost Estimator | `html/ai-estimator.html` | AI Finishing Estimator | `customer/ai_finishing_estimator_screen.dart` | ⚠️ Partial | Multi-step wizard UI complete. Results screen shows hardcoded cost range "3,250–3,800 EGP". No real AI computation. |
| Login | `html/login.html` | Login | `auth/login_screen.dart` | ⚠️ Partial | UI complete with "Remember me" and demo credential hint. Login calls `validateDemoLogin()` against a hardcoded list of accounts. Does NOT call `POST /api/v1/auth/login`. |
| Sign Up | `html/signup.html` | Sign Up | `auth/sign_up_screen.dart` | ⚠️ Partial | Multi-step registration (3 steps for customer, 7 for technician). Creates a local `UserAccount` object. Does NOT call `POST /api/v1/auth/register`. OTP step is simulated (30-second countdown, any 6-digit input accepted). |
| Forgot Password | `html/forgot-password.html` | (none — button in login) | — | ❌ Missing | "Forgot password?" button in `LoginScreen` has `onPressed: () {}` (no-op). No screen or API call to `POST /api/v1/auth/forgot-password`. |
| Reset Password | `html/reset-password.html` | (none) | — | ❌ Missing | No screen exists. Backend has `POST /api/v1/auth/reset-password/:token`. |
| Join as Technician | `html/join-as-technician.html` | Role Selection + Sign Up (technician path) | `auth/role_selection_screen.dart`, `auth/sign_up_screen.dart` | ✅ Full | Mobile has a dedicated multi-step technician signup (7 steps) including document upload via `VerificationUploadScreen`. Functionally equivalent to the website page. |
| About | `html/about.html` | About | `marketing/about_screen.dart` | ✅ Full | Both exist and are informational/static. |
| Contact | `html/contact.html` | Contact | `marketing/contact_screen.dart` | ✅ Full | Both exist and are informational/static. |
| 404 Error | `html/404.html` | Error Screen | `shared/error_screen.dart` | ✅ Full | Both handle error states. |

---

## 4. Missing Mobile Features

### 4.1 Admin Dashboard

- **Website file:** `servio_frontend/html/admin-dashboard.html`
- **Website UI/features:** Full admin control panel with: user management table, worker verification queue, booking overview, revenue analytics, dispute management, audit log, platform settings, and ability to create/edit/delete services.
- **What's needed in mobile:** This is intentionally web-only for administrators. A minimal read-only admin view could be added, but is generally low-priority for a mobile release.
- **Backend endpoints needed:**
  - `GET /api/v1/users` (list all users)
  - `PATCH /api/v1/users/:id/status` (activate/deactivate)
  - `PATCH /api/v1/users/workers/:id/verify` (approve/reject worker)
  - `DELETE /api/v1/users/:id`
  - `GET /api/v1/users/analytics`
  - `GET /api/v1/users/analytics/payments`
  - `GET /api/v1/bookings` (all bookings — admin)
  - `GET /api/v1/payments/disputes`
  - `PATCH /api/v1/payments/disputes/:id/resolve`
  - `POST /api/v1/payments/refund/:paymentId`
  - `GET /api/v1/admin/audit`
  - `GET /api/v1/services` / `POST /api/v1/services` / `PUT /api/v1/services/:id` / `DELETE /api/v1/services/:id`

### 4.2 Forgot Password Flow

- **Website file:** `servio_frontend/html/forgot-password.html`
- **Mobile gap:** `LoginScreen` has a "Forgot password?" `TextButton` with an empty `onPressed: () {}`. No screen navigated to.
- **What's needed in mobile:** A screen with an email input field that calls the backend, then redirects to a confirmation state. Also need a deep-link handler for the reset token emailed by the backend.
- **Backend endpoints needed:**
  - `POST /api/v1/auth/forgot-password`
  - `POST /api/v1/auth/reset-password/:token`

### 4.3 Reset Password Screen

- **Website file:** `servio_frontend/html/reset-password.html`
- **Mobile gap:** No screen exists. This would be opened via a deep link (universal link/app link from the password reset email).
- **Backend endpoints needed:**
  - `POST /api/v1/auth/reset-password/:token`

### 4.4 Payment Gateway / Stripe Integration

- **Website:** Payments are processed via Stripe on the backend. The website's booking confirmation flow can trigger payment.
- **Mobile gap:** No Stripe payment UI, no Stripe SDK integration. `BookingStepThreeScreen` shows a "terms accepted" confirmation only. No `POST /api/v1/payments/intent` call, no card input form.
- **Backend endpoints needed:**
  - `POST /api/v1/payments/intent`
  - `POST /api/v1/payments/confirm/:bookingId`
  - `GET /api/v1/payments/booking/:bookingId`

### 4.5 Disputes Screen (Customer)

- **Website:** Customer dashboard has a dispute/issue flow.
- **Mobile gap:** No dispute screen in mobile. The `BookingDetailsScreen` has a "Cancel Booking" button but no way to open a formal dispute.
- **Backend endpoints needed:**
  - `POST /api/v1/payments/disputes` (open dispute)

### 4.6 Worker Earnings with Wallet/Payout

- **Website:** Technician dashboard shows detailed earnings breakdown including payout history.
- **Mobile status:** `EarningsScreen` exists but shows completely hardcoded data (no `GET /api/v1/payments/earnings` call). See Section 5 for details.

### 4.7 Notifications (Push)

- **Website:** Has a notification bell UI (no real-time implementation visible in static HTML).
- **Mobile status:** `NotificationsScreen` exists but all notifications are a hardcoded static list (`_kNotifications`). No Firebase Cloud Messaging or real-time backend subscription. See Section 5.

---

## 5. Partially Implemented Features

### 5.1 Authentication (Login)
- **Website file:** `servio_frontend/html/login.html`
- **Mobile file:** `mobile-app/lib/src/features/auth/login_screen.dart`
- **Implemented in mobile:** Email/password form, "Remember me" toggle, role-aware greeting, "Forgot password?" button (dead), social login buttons (dead), link to sign up.
- **What's missing:** Actual API call. Login calls `validateDemoLogin(email, password)` from `core/data/demo_accounts.dart` — a hardcoded list of 4 test accounts.
- **Mock data:** Demo credentials hardcoded (`ahmed@test.com / test1234`, `khaled@test.com / test1234`).
- **Blocking issue:** Replace `validateDemoLogin()` with `POST /api/v1/auth/login` HTTP call; store JWT token in `StorageService`.

### 5.2 Sign Up / Registration
- **Website file:** `servio_frontend/html/signup.html`
- **Mobile file:** `mobile-app/lib/src/features/auth/sign_up_screen.dart`
- **Implemented in mobile:** 3-step customer flow (basic info → OTP → city/terms), 7-step technician flow (basic info → OTP → skills → availability → pricing → document upload → submitted). OTP countdown timer is real but accepts any 6-digit input.
- **What's missing:** Real backend calls. `_createCustomerAccount()` calls `SessionProvider.registerCustomer()` which only creates a local `UserAccount` object (no HTTP). Document upload via `VerificationUploadStep` is UI-complete but does not call `POST /api/v1/uploads`.
- **Mock data:** OTP not verified against any server; user ID is `user_<milliseconds>`.

### 5.3 Services Marketplace
- **Website file:** `servio_frontend/html/services-marketplace.html`
- **Mobile file:** `mobile-app/lib/src/features/customer/services_marketplace_screen.dart`
- **Implemented in mobile:** Category filter chips, service grid cards, search bar.
- **What's missing:** Data from `GET /api/v1/services`. Currently uses `core/data/demo_services.dart`.
- **Mock data:** `demo_services.dart` with hardcoded services.

### 5.4 Technician Listing
- **Website file:** `servio_frontend/html/technician-listing.html`
- **Mobile file:** `mobile-app/lib/src/features/customer/technician_listing_screen.dart`
- **Implemented in mobile:** Filter chips, technician cards with rating, specialty, distance.
- **What's missing:** Data from `GET /api/v1/users/workers`. Uses `kDemoTechnicians` from `core/data/demo_technicians.dart`.
- **Mock data:** 5 hardcoded technicians in `demo_technicians.dart`.

### 5.5 Technician Profile
- **Website file:** `servio_frontend/html/technician-profile.html`
- **Mobile file:** `mobile-app/lib/src/features/customer/technician_profile_screen.dart`
- **Implemented in mobile:** Bio, services list with prices, rating display, "Book Now" and "Message" CTAs, reviews section.
- **What's missing:** `technicianId` parameter is accepted but used only to look up in `kDemoTechnicians`. No `GET /api/v1/users/workers/:id` call. Reviews not fetched from `GET /api/v1/reviews/worker/:workerId`.
- **Mock data:** Reviews are hardcoded inline.

### 5.6 Booking Flow (3-step)
- **Website file:** `servio_frontend/html/booking.html`
- **Mobile files:** `booking/booking_step_one_screen.dart`, `booking/booking_step_two_screen.dart`, `booking/booking_step_three_screen.dart`
- **Implemented in mobile:** Step 1 (service + technician review, job description), Step 2 (date picker, time slot, payment method), Step 3 (order summary, terms, confirm).
- **What's missing:** On `_confirmBooking()` in Step 3, the app saves a `BookingModel` to local `BookingsProvider` (SharedPreferences). No `POST /api/v1/bookings` call. No `POST /api/v1/payments/intent` for Stripe.
- **Mock data:** PIN generated as `(1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString()`.

### 5.7 Customer Dashboard
- **Website file:** `servio_frontend/html/customer-dashboard.html`
- **Mobile file:** `mobile-app/lib/src/features/customer/customer_dashboard_screen.dart`
- **Implemented in mobile:** Overview (KPI cards, recent bookings, upcoming schedule), Bookings tab (filterable list with invoice expand), History tab (completed/cancelled), Favourites tab (saved technicians from demo list). Cancel booking UI exists.
- **What's missing:** Live data from `GET /api/v1/bookings/my`. `_demoBookings` list is used when `BookingsProvider` is empty. Cancellation updates only local state, not `PATCH /api/v1/bookings/:id/status`.
- **Mock data:** 4 hardcoded demo bookings in the dashboard screen file.

### 5.8 Messages / Chat
- **Website file:** `servio_frontend/html/messages.html`
- **Mobile files:** `messages/messages_screen.dart`, `messages/chat_screen.dart`
- **Implemented in mobile:** Conversation list with unread badge counts, individual chat with message bubbles, search in conversations, auto-reply bot.
- **What's missing:** Real messages from `GET /api/v1/messages/:bookingId`. No `POST /api/v1/messages` to send. Uses in-memory `MessagesProvider` with 2 hardcoded demo conversations.
- **Mock data:** 2 hardcoded conversations in `MessagesProvider._initDemoConversations()`.

### 5.9 AI Smart Match
- **Website file:** `servio_frontend/html/smart-match.html`
- **Mobile file:** `mobile-app/lib/src/features/customer/ai_smart_match_screen.dart`
- **Implemented in mobile:** Text input, suggestion chips, "Analyze" button, results showing matched service and top technicians.
- **What's missing:** `_analyze()` just calls `setState(() => _showResults = true)`. No `POST /api/v1/ai/recommend` call. Results show "Ahmed Nabil 97%" regardless of input.
- **Mock data:** Hardcoded results for all inputs.

### 5.10 AI Finishing Estimator
- **Website file:** `servio_frontend/html/ai-estimator.html`
- **Mobile file:** `mobile-app/lib/src/features/customer/ai_finishing_estimator_screen.dart`
- **Implemented in mobile:** 4-step wizard (room type → dimensions → budget/finish → results). Results screen shows cost breakdown, material list, vendor quotes.
- **What's missing:** No real computation. Results always show "3,250–3,800 EGP" regardless of inputs. No backend endpoint currently — AI service is a placeholder.
- **Mock data:** All result values hardcoded.

### 5.11 Technician Dashboard / Earnings / Jobs
- **Website file:** `servio_frontend/html/technician-dashboard.html`
- **Mobile files:** `technician/technician_dashboard_screen.dart`, `technician/earnings_screen.dart`, `technician/job_queue_screen.dart`, `technician/job_details_screen.dart`, `technician/availability_manager_screen.dart`
- **Implemented in mobile:** 5-tab bottom navigation (Dashboard, Jobs, Earnings, Availability, Profile). Job queue has Pending/Confirmed/In Progress/Completed tabs. Earnings screen has period selector (Week/Month/All Time).
- **What's missing:** All data hardcoded inline. No `GET /api/v1/bookings/worker`, no `GET /api/v1/payments/earnings`, no `PATCH /api/v1/users/me/availability`.
- **Mock data:** Hardcoded earnings and job data in each screen.

---

## 6. Mobile-Only Features

These screens exist in the mobile app but have no direct equivalent website page:

| Mobile Screen | File | Description |
|---|---|---|
| Splash Screen | `onboarding/splash_screen.dart` | App loading animation, not applicable to web |
| Onboarding | `onboarding/onboarding_screen.dart` | First-launch tutorial slides |
| Role Selection | `auth/role_selection_screen.dart` | Customer vs. Technician role picker before login/signup |
| Customer Home | `customer/customer_home_screen.dart` | Personalized home feed (post-login landing) distinct from marketing homepage |
| My Bookings | `customer/my_bookings_screen.dart` | Dedicated bookings tab with Active/History/Favourites (subset of dashboard but as standalone screen) |
| Write Review | `customer/write_review_screen.dart` | Star rating, tag chips, photo upload (UI only) |
| Search Results | `shared/search_results_screen.dart` | Global search results screen |
| Notifications | `shared/notifications_screen.dart` | Categorized notification list (booking, payment, system, AI) |
| Job Details | `technician/job_details_screen.dart` | Individual job view for technician |
| Verification Upload | `technician/verification_upload_screen.dart` | ID front/back, selfie, portfolio, CV upload during technician signup |

---

## 7. Integration Readiness (per module)

### 7.1 Auth Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/forgot-password`, `POST /api/v1/auth/reset-password/:token` |
| Mobile connected to backend | **No.** Login uses `validateDemoLogin()` against a hardcoded demo account list. Register creates a local object only. |
| Blocking issues | No HTTP client package in use. Must add `dio` or `http`. Must store JWT token and attach it to all subsequent requests. |

### 7.2 Services Module

| Item | Status |
|------|--------|
| Backend endpoints available | `GET /api/v1/services`, `GET /api/v1/services/:id`, `POST /api/v1/services` (admin), `PUT /api/v1/services/:id` (admin), `DELETE /api/v1/services/:id` (admin) |
| Mobile connected to backend | **No.** Uses `core/data/demo_services.dart`. |
| Blocking issues | Need HTTP client + auth token from login. Service categories must match enum values in backend: `plumbing`, `electrical`, `painting`, `flooring`, `carpentry`, `cleaning`, `hvac`, `other`. |

### 7.3 Bookings Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/bookings`, `GET /api/v1/bookings/my`, `GET /api/v1/bookings/worker`, `GET /api/v1/bookings/:id`, `PATCH /api/v1/bookings/:id/status` |
| Mobile connected to backend | **No.** Booking creation writes to local `SharedPreferences`. My bookings reads from `BookingsProvider` (local). |
| Blocking issues | Backend requires `workerId` (MongoDB ObjectId), `serviceId` (MongoDB ObjectId), `scheduledDate` (ISO8601), `address`. Mobile currently stores only display strings, not MongoDB IDs. Must store real IDs after fetching from backend API. |

### 7.4 Users / Workers Module

| Item | Status |
|------|--------|
| Backend endpoints available | `GET /api/v1/users/workers`, `GET /api/v1/users/workers/:id`, `GET /api/v1/users/me`, `PATCH /api/v1/users/me`, `PATCH /api/v1/users/me/password`, `DELETE /api/v1/users/me`, `PATCH /api/v1/users/me/availability` |
| Mobile connected to backend | **No.** Technician listing and profiles use `kDemoTechnicians`. User profile reads from local `SessionProvider`. |
| Blocking issues | Profile screen has no "edit profile" form that calls `PATCH /api/v1/users/me`. Availability manager UI exists but does not call `PATCH /api/v1/users/me/availability`. |

### 7.5 Reviews Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/reviews`, `GET /api/v1/reviews/worker/:workerId`, `DELETE /api/v1/reviews/:id` (admin) |
| Mobile connected to backend | **No.** `WriteReviewScreen` calls `ScaffoldMessenger.showSnackBar` and pops the screen with `Navigator.pop(true)` — no HTTP call. Technician profile shows hardcoded inline reviews. |
| Blocking issues | Review creation requires a `bookingId` (MongoDB ObjectId). Mobile must pass the real backend booking ID, not a local reference string. |

### 7.6 Payments / Stripe Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/payments/intent`, `POST /api/v1/payments/confirm/:bookingId`, `GET /api/v1/payments/booking/:bookingId`, `GET /api/v1/payments/earnings` (worker), `POST /api/v1/payments/refund/:paymentId` (admin), `POST /api/v1/payments/disputes`, `PATCH /api/v1/payments/disputes/:id/resolve` (admin), `POST /api/v1/payments/webhook` |
| Mobile connected to backend | **No.** No Stripe Flutter SDK (`flutter_stripe` or `stripe_checkout`). No payment intent creation. Booking Step 3 shows "Cash on Completion" as a static label. |
| Blocking issues | Must add `flutter_stripe` package. Must create PaymentIntent on backend before showing Stripe payment sheet. Earnings screen has no connection to `GET /api/v1/payments/earnings`. |

### 7.7 Messaging Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/messages`, `GET /api/v1/messages/conversations`, `GET /api/v1/messages/unread`, `GET /api/v1/messages/:bookingId` |
| Mobile connected to backend | **No.** In-memory `MessagesProvider` with 2 hardcoded conversations and an auto-reply bot. |
| Blocking issues | Message sending calls `MessagesProvider.sendMessage()` which only mutates the local list. Real-time delivery would ideally require WebSocket/Socket.IO, but the backend currently only exposes REST endpoints. |

### 7.8 Notifications Module

| Item | Status |
|------|--------|
| Backend endpoints available | None. No notification routes in backend. |
| Mobile connected to backend | **No.** `NotificationsScreen` uses a static `_kNotifications` list defined inline. |
| Blocking issues | Backend has no notification endpoint or push notification integration. Need Firebase Cloud Messaging (FCM) setup on both backend and mobile, or polling via a to-be-built notifications endpoint. |

### 7.9 AI Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/ai/recommend` (single endpoint; routes to an external AI microservice) |
| Mobile connected to backend | **No.** AI Smart Match calls `setState(() => _showResults = true)`. AI Estimator results are all hardcoded. |
| Blocking issues | The AI microservice (`ai-service/`) is described as "placeholder, not yet implemented" in CLAUDE.md. Until it responds correctly, connecting mobile would only return errors. However, `POST /api/v1/ai/recommend` could return a mock/stub response from the controller for early integration testing. |

### 7.10 File Upload Module

| Item | Status |
|------|--------|
| Backend endpoints available | `POST /api/v1/uploads?kind={avatar|idFront|idBack|idSelfie|portfolio|cv}&filename=` |
| Mobile connected to backend | **No.** `VerificationUploadStep` in sign up lets users pick/simulate files, but stores only local `File` references. No HTTP call to upload. |
| Blocking issues | Need `image_picker` or `file_picker` package to select real files, then upload via raw body to `POST /api/v1/uploads`. |

---

## 8. Recommended Next Steps

Ordered by: backend availability, user importance, and dependency chain.

### Priority 1 — Foundation (blocks everything else)

**1.1 Add HTTP Client and API Service Layer**
- Add `dio: ^5.x` to `mobile-app/pubspec.yaml`.
- Create `mobile-app/lib/src/core/services/api_service.dart` with base URL from config.
- Create `mobile-app/lib/src/core/services/auth_token_service.dart` to store and attach JWT via `StorageService`.
- All subsequent integration tasks depend on this.

**1.2 Connect Login to Backend**
- Replace `validateDemoLogin()` in `SessionProvider.login()` with `POST /api/v1/auth/login`.
- Store JWT in `StorageService` on success; parse user role from response.
- Handle `401` errors with appropriate user feedback.
- Files: `mobile-app/lib/src/core/state/app_state.dart`, `mobile-app/lib/src/features/auth/login_screen.dart`

**1.3 Connect Register to Backend**
- Replace `registerCustomer()` and `registerTechnician()` in `SessionProvider` with `POST /api/v1/auth/register`.
- The OTP step in the mobile UI is currently fake — either remove it or integrate a real OTP service (backend does not currently provide one).
- Files: `mobile-app/lib/src/core/state/app_state.dart`, `mobile-app/lib/src/features/auth/sign_up_screen.dart`

### Priority 2 — Core Customer Features

**2.1 Connect Services Listing**
- Call `GET /api/v1/services` in `ServicesMarketplaceScreen` and `ServiceDetailScreen`.
- Replace `demo_services.dart` with API responses mapped to `ServiceModel`.
- Files: `customer/services_marketplace_screen.dart`, `customer/service_detail_screen.dart`, `core/data/demo_services.dart`

**2.2 Connect Technician Listing and Profile**
- Call `GET /api/v1/users/workers` in `TechnicianListingScreen`.
- Call `GET /api/v1/users/workers/:id` in `TechnicianProfileScreen` using `technicianId`.
- Call `GET /api/v1/reviews/worker/:workerId` to show real reviews in profile.
- Replace `kDemoTechnicians` throughout.
- Files: `customer/technician_listing_screen.dart`, `customer/technician_profile_screen.dart`, `core/data/demo_technicians.dart`

**2.3 Connect Booking Creation**
- After user confirms in `BookingStepThreeScreen._confirmBooking()`, call `POST /api/v1/bookings` with real MongoDB IDs for `workerId` and `serviceId`.
- Store the returned backend booking ID for use in payment and review flows.
- Files: `booking/booking_step_three_screen.dart`, `booking/booking_confirmation_screen.dart`

**2.4 Connect My Bookings**
- Call `GET /api/v1/bookings/my` in `MyBookingsScreen` and `CustomerDashboardScreen`.
- Replace `BookingsProvider` local-only storage with API-backed data.
- Connect cancel action to `PATCH /api/v1/bookings/:id/status` with `status: "cancelled"`.
- Files: `customer/my_bookings_screen.dart`, `customer/customer_dashboard_screen.dart`, `core/state/app_state.dart`

### Priority 3 — Payments and Reviews

**3.1 Stripe Payment Integration**
- Add `flutter_stripe` to `pubspec.yaml`.
- In booking confirmation step, call `POST /api/v1/payments/intent` to get a `client_secret`.
- Present Stripe payment sheet using the client secret.
- Files: `booking/booking_step_three_screen.dart`, new `services/payment_service.dart`

**3.2 Connect Review Submission**
- In `WriteReviewScreen._submit()`, call `POST /api/v1/reviews` with the real `bookingId`, `rating`, and `comment`.
- Files: `customer/write_review_screen.dart`

**3.3 Implement Forgot Password + Reset Password**
- Add a `ForgotPasswordScreen` with email input and call `POST /api/v1/auth/forgot-password`.
- Add deep-link handling for the `reset-password/:token` URL from the email, landing on a `ResetPasswordScreen`.
- Wire `onPressed` for "Forgot password?" in `LoginScreen`.
- Files: `auth/login_screen.dart` (new screens needed)

### Priority 4 — Technician Side

**4.1 Connect Technician Job Queue**
- Call `GET /api/v1/bookings/worker` in `JobQueueScreen`.
- Connect accept/reject actions to `PATCH /api/v1/bookings/:id/status`.
- Files: `technician/job_queue_screen.dart`, `technician/job_details_screen.dart`

**4.2 Connect Technician Earnings**
- Call `GET /api/v1/payments/earnings` in `EarningsScreen`.
- Replace hardcoded earning figures.
- Files: `technician/earnings_screen.dart`

**4.3 Connect Availability Manager**
- Call `PATCH /api/v1/users/me/availability` when user saves availability in `AvailabilityManagerScreen`.
- Files: `technician/availability_manager_screen.dart`

### Priority 5 — Messaging and Notifications

**5.1 Connect Messages to Backend**
- Call `GET /api/v1/messages/conversations` in `MessagesScreen`.
- Call `GET /api/v1/messages/:bookingId` in `ChatScreen`.
- Replace `MessagesProvider.sendMessage()` with `POST /api/v1/messages`.
- Files: `messages/messages_screen.dart`, `messages/chat_screen.dart`, `core/state/app_state.dart`

**5.2 Implement Push Notifications**
- Set up Firebase Cloud Messaging on backend (requires `firebase-admin` npm package).
- Add `firebase_messaging` and `flutter_local_notifications` Flutter packages.
- Replace `NotificationsScreen` static list with real notifications stored/fetched from backend.
- Files: `shared/notifications_screen.dart` (new backend endpoint needed)

### Priority 6 — AI and File Uploads

**6.1 Connect AI Smart Match**
- Once the AI microservice (`ai-service/`) is operational, replace `_analyze()` stub with `POST /api/v1/ai/recommend`.
- Files: `customer/ai_smart_match_screen.dart`

**6.2 Connect File Upload in Technician Signup**
- Use `image_picker` or `file_picker` to select files in `VerificationUploadStep`.
- Upload selected files to `POST /api/v1/uploads?kind=idFront&filename=...` etc.
- Files: `technician/verification_upload_screen.dart`

**6.3 Connect AI Estimator**
- Blocked until AI microservice is implemented. Intermediate step: connect to `POST /api/v1/ai/recommend` with room dimensions payload and display the response.
- Files: `customer/ai_finishing_estimator_screen.dart`

---

## Appendix: All Backend Endpoints

| Method | Path | Auth | Role |
|--------|------|------|------|
| POST | `/api/v1/auth/register` | No | — |
| POST | `/api/v1/auth/login` | No | — |
| POST | `/api/v1/auth/forgot-password` | No | — |
| POST | `/api/v1/auth/reset-password/:token` | No | — |
| GET | `/api/v1/users/workers` | No | — |
| GET | `/api/v1/users/workers/:id` | No | — |
| GET | `/api/v1/users/me` | Yes | any |
| PATCH | `/api/v1/users/me` | Yes | any |
| PATCH | `/api/v1/users/me/password` | Yes | any |
| DELETE | `/api/v1/users/me` | Yes | any |
| PATCH | `/api/v1/users/me/availability` | Yes | worker |
| GET | `/api/v1/users` | Yes | admin |
| PATCH | `/api/v1/users/:id/status` | Yes | admin |
| PATCH | `/api/v1/users/workers/:id/verify` | Yes | admin |
| DELETE | `/api/v1/users/:id` | Yes | admin |
| GET | `/api/v1/users/analytics` | Yes | admin |
| GET | `/api/v1/users/analytics/payments` | Yes | admin |
| GET | `/api/v1/services` | No | — |
| GET | `/api/v1/services/:id` | No | — |
| POST | `/api/v1/services` | Yes | admin |
| PUT | `/api/v1/services/:id` | Yes | admin |
| DELETE | `/api/v1/services/:id` | Yes | admin |
| POST | `/api/v1/bookings` | Yes | user |
| GET | `/api/v1/bookings/my` | Yes | any |
| GET | `/api/v1/bookings/worker` | Yes | worker |
| GET | `/api/v1/bookings` | Yes | admin |
| PATCH | `/api/v1/bookings/:id/status` | Yes | worker/admin/user |
| GET | `/api/v1/bookings/:id` | Yes | any |
| POST | `/api/v1/reviews` | Yes | user |
| GET | `/api/v1/reviews/worker/:workerId` | No | — |
| DELETE | `/api/v1/reviews/:id` | Yes | admin |
| POST | `/api/v1/payments/webhook` | No | — (Stripe) |
| POST | `/api/v1/payments/intent` | Yes | user |
| POST | `/api/v1/payments/confirm/:bookingId` | Yes | user |
| GET | `/api/v1/payments/booking/:bookingId` | Yes | user/worker/admin |
| GET | `/api/v1/payments/earnings` | Yes | worker |
| POST | `/api/v1/payments/refund/:paymentId` | Yes | admin |
| POST | `/api/v1/payments/disputes` | Yes | user |
| PATCH | `/api/v1/payments/disputes/:id/resolve` | Yes | admin |
| GET | `/api/v1/payments/disputes` | Yes | admin |
| POST | `/api/v1/ai/recommend` | Yes | any |
| POST | `/api/v1/messages` | Yes | any |
| GET | `/api/v1/messages/conversations` | Yes | any |
| GET | `/api/v1/messages/unread` | Yes | any |
| GET | `/api/v1/messages/:bookingId` | Yes | any |
| POST | `/api/v1/uploads` | No | — |
| GET | `/api/v1/admin/audit` | Yes | admin |
| DELETE | `/api/v1/admin/audit/:id` | Yes | admin |
| GET | `/api/v1/admin/settings` | Yes | admin |
| PUT | `/api/v1/admin/settings` | Yes | admin |
