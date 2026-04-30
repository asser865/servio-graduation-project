# Mobile Auth Persistence — Design Spec
**Date:** 2026-04-30  
**Branch:** mostafabdelaal/mobile-app-enhancements-3  
**Scope:** Mobile-only signup/login integration with MongoDB persistence

---

## Problem Statement

The Flutter mobile app's auth/signup screens send data to the backend, but two gaps prevent the full flow from working correctly during manual verification:

1. **`status` field mismatch** — `UserAccount.fromBackend` reads `json['status']`, but the backend returns `verificationStatus`. Pending technician accounts always appear as `'active'` in the mobile, so the "Account Under Review" dialog never fires.
2. **`GET /auth/me` missing** — The task spec requires this endpoint for session restore. The mobile currently calls `/users/me` (which works), but `/auth/me` does not exist.
3. **Demo credential hints** — `login_screen.dart` shows hardcoded demo email/password hints (`ahmed@test.com / test1234`) that reference users who may not exist in MongoDB, misleading testers.

---

## Approach Selected

**Approach 2 — Fix + remove demo hints.**  
Surgical patches only. No new modules, no new services, no architecture changes.

---

## Changes

### 1. Backend — Add `GET /api/v1/auth/me`

**File:** `backend/src/modules/auth/auth.routes.js`

Import `protect` from `../../middleware/auth.middleware` and `getMe` from `../users/user.controller`. Add:

```js
router.get('/me', protect, userController.getMe);
```

`getMe` already exists in `user.controller.js`:
- Requires JWT via `protect` middleware
- Finds the user by `req.user.id`
- Returns `ApiResponse.success(res, 200, 'Profile retrieved.', user)` with password stripped (toJSON transform)

Both `/auth/me` and `/users/me` will coexist. Mobile continues to call `/users/me`; the new route satisfies the spec and is available for future use.

---

### 2. Mobile — Fix `status` field in `UserAccount.fromBackend`

**File:** `mobile-app/lib/src/core/models/user_account.dart`

**Before:**
```dart
status: (json['status'] as String?) ?? 'active',
```

**After:**
```dart
status: (json['verificationStatus'] as String?) ??
        (json['status'] as String?) ?? 'active',
```

**Why:** The backend User document has a `verificationStatus` field (`'pending'|'approved'|'rejected'`), not a top-level `status` field. Without this fix, `account.status` is always `'active'`, and the "Account Under Review" dialog in `login_screen.dart` (which checks `account.status == 'pending'`) never triggers for pending technicians.

---

### 3. Mobile — Remove demo credential hints

**File:** `mobile-app/lib/src/features/auth/login_screen.dart`

Remove the `Container` widget that displays:
- Customer: `'Demo: ahmed@test.com / test1234'`
- Technician: `'Demo: khaled@test.com / test1234'`

These reference users that do not exist in a fresh MongoDB instance and confuse manual testers. The surrounding `SizedBox(height: 20)` before the error block and `SizedBox(height: 16)` after remain for spacing.

---

## Data Flows (confirmed working, no changes needed)

### Customer Signup
```
POST /api/v1/auth/register
{ name, email, password, phone, role: "user", address: { city } }

→ validate: name/email/password required, role in allowed list (HTTP 422 on fail)
→ duplicate email check → HTTP 409
→ User.create({ ..., role:"user", isVerified:true, verificationStatus:"approved" })
→ bcrypt hash via pre-save hook
→ return { token, user }

Mobile:
AuthSession.fromApi → token stored in flutter_secure_storage
UserAccount.fromBackend: role:"user" → UserRole.customer, status:"approved"
Navigate to CustomerHomeScreen
```

### Technician Signup
```
POST /api/v1/auth/register
{ name, email, password, phone, role: "worker",
  skills, locationLabel, hourlyRate, availabilityType }

→ skills auto-mapped to categories enum
→ User.create({ ..., role:"worker", isVerified:false,
                verificationStatus:"pending",
                verificationSubmittedAt: now,
                skills, categories, locationLabel, hourlyRate, availabilityType })
→ return { token, user }

Mobile (after fix):
UserAccount.fromBackend: role:"worker" → UserRole.technician
                         verificationStatus:"pending" → status:"pending"
Login screen: account.status == 'pending' → shows "Account Under Review" dialog ✓
Navigate to TechnicianDashboardScreen
```

### Login
```
POST /api/v1/auth/login
{ email, password }

→ findOne by email → 401 if not found
→ check isActive → 403 if deactivated
→ bcrypt.compare → 401 if wrong password
→ return { token, user }
Never creates users automatically.
```

### Session Restore (new endpoint)
```
GET /api/v1/auth/me
Authorization: Bearer <token>

→ protect middleware: verify JWT, load user from DB
→ return { success, message, data: <user> }
```

---

## Files Changed

| File | Type | Change |
|------|------|--------|
| `backend/src/modules/auth/auth.routes.js` | Backend | Add `GET /me` route |
| `mobile-app/lib/src/core/models/user_account.dart` | Mobile | Fix `status` field mapping |
| `mobile-app/lib/src/features/auth/login_screen.dart` | Mobile | Remove demo credential hints |

---

## Validation

- `node --check` on `auth.routes.js` after change
- `flutter analyze` on changed Dart files
- Backend startup check (`npm run dev`)

---

## Manual Test Steps

1. Start backend (`npm run dev` in `backend/`)
2. Register customer from mobile → check MongoDB Compass for `{ role:"user", verificationStatus:"approved" }`
3. Login as that customer → confirm navigates to `CustomerHomeScreen`
4. Register technician from mobile → check Compass for `{ role:"worker", verificationStatus:"pending", skills:[...], hourlyRate, locationLabel }`
5. Login as that technician → confirm "Account Under Review" dialog appears (not redirect)
6. Call `GET /api/v1/auth/me` with the stored token (Postman or curl) → confirm user object returned
7. Attempt login with unregistered email → confirm 401 error in mobile
8. Attempt login with wrong password → confirm 401 error in mobile

---

## Out of Scope

- OTP backend verification (currently UI-only; not mentioned in task requirements)
- Password strength enforcement in mobile (Approach 3, deferred)
- Social auth (Google/Apple buttons are no-ops)
- Website frontend (untouched)
