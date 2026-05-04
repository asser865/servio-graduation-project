# Mobile Auth Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three targeted gaps so that customer and technician signup from the Flutter mobile app persists correctly in MongoDB and the auth session restore endpoint matches the spec.

**Architecture:** All three changes are isolated patches — no new modules or services. Backend gets a new `GET /auth/me` route reusing the existing `getMe` handler. The mobile `UserAccount.fromBackend` factory gets a one-field fix so pending technicians are correctly identified. The hardcoded demo credential hints are removed from the login screen.

**Tech Stack:** Node.js/Express (backend), Flutter/Dart (mobile), MongoDB/Mongoose

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `backend/src/modules/auth/auth.routes.js` | Modify | Add `GET /me` route using `protect` + existing `getMe` handler |
| `mobile-app/lib/src/core/models/user_account.dart` | Modify | Read `verificationStatus` before `status` in `fromBackend` |
| `mobile-app/lib/src/features/auth/login_screen.dart` | Modify | Remove demo credential hint container |

---

## Task 1: Add `GET /api/v1/auth/me` to backend

**Files:**
- Modify: `backend/src/modules/auth/auth.routes.js`

- [ ] **Step 1: Open the file and understand current imports**

  Open `backend/src/modules/auth/auth.routes.js`. It currently imports only from `express-validator`, `./auth.controller`, and `../../middleware/validate.middleware`. It does NOT import `protect` or `getMe` yet.

- [ ] **Step 2: Add the two missing imports**

  After line 9 (`const { validate } = require(...)`), add:

  ```js
  const { protect }        = require('../../middleware/auth.middleware');
  const userController     = require('../users/user.controller');
  ```

  The full import block at the top of the file should now read:

  ```js
  const { Router }        = require('express');
  const { body }          = require('express-validator');
  const authController    = require('./auth.controller');
  const { validate }      = require('../../middleware/validate.middleware');
  const { protect }       = require('../../middleware/auth.middleware');
  const userController    = require('../users/user.controller');
  ```

- [ ] **Step 3: Add the route before `module.exports`**

  Add this line immediately before `module.exports = router;` at the bottom of the file:

  ```js
  // GET /api/v1/auth/me — return current user (session restore)
  router.get('/me', protect, userController.getMe);
  ```

- [ ] **Step 4: Syntax-check the file**

  Run from the repo root:

  ```bash
  node --check backend/src/modules/auth/auth.routes.js
  ```

  Expected output: *(no output, exit code 0)*. Any output means a syntax error — fix before continuing.

- [ ] **Step 5: Start the backend and smoke-test the new route**

  ```bash
  cd backend && npm run dev
  ```

  In a second terminal, run (replace `<token>` with a real JWT from a previous login, or register a test user first):

  ```bash
  curl -s -H "Authorization: Bearer <token>" \
       http://localhost:5000/api/v1/auth/me | jq .
  ```

  Expected response shape:
  ```json
  {
    "success": true,
    "message": "Profile retrieved.",
    "data": {
      "_id": "...",
      "name": "...",
      "email": "...",
      "role": "user",
      "verificationStatus": "approved",
      ...
    }
  }
  ```

  Also verify that calling without a token returns 401:

  ```bash
  curl -s http://localhost:5000/api/v1/auth/me | jq .
  ```

  Expected:
  ```json
  { "success": false, "message": "Access denied. No token provided.", "errors": [] }
  ```

- [ ] **Step 6: Commit**

  ```bash
  cd backend  # or repo root
  git add backend/src/modules/auth/auth.routes.js
  git commit -m "feat(backend): add GET /auth/me session restore endpoint"
  ```

---

## Task 2: Fix `status` field mapping in `UserAccount.fromBackend`

**Files:**
- Modify: `mobile-app/lib/src/core/models/user_account.dart`

**Context:** The backend User document stores verification state in `verificationStatus` (`'pending'|'approved'|'rejected'`). There is no top-level `status` field. The current `fromBackend` reads `json['status']`, always gets `null`, and falls back to `'active'`. This means `account.status == 'pending'` in `login_screen.dart` is never `true` — the "Account Under Review" dialog for pending technicians never appears.

- [ ] **Step 1: Locate the line to fix**

  Open `mobile-app/lib/src/core/models/user_account.dart`. In the `UserAccount.fromBackend` factory (around line 57), find:

  ```dart
  status: (json['status'] as String?) ?? 'active',
  ```

- [ ] **Step 2: Apply the fix**

  Replace that single line with:

  ```dart
  status: (json['verificationStatus'] as String?) ??
          (json['status'] as String?) ?? 'active',
  ```

  The full `fromBackend` factory after the fix should look like this:

  ```dart
  factory UserAccount.fromBackend(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    final rawRole = (json['role'] as String?) ?? 'user';
    return UserAccount(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      role: rawRole == 'worker' ? UserRole.technician : UserRole.customer,
      city: (address?['city'] as String?) ?? 'Cairo',
      status: (json['verificationStatus'] as String?) ??
              (json['status'] as String?) ?? 'active',
    );
  }
  ```

- [ ] **Step 3: Run Flutter analyzer**

  ```bash
  cd mobile-app
  flutter analyze lib/src/core/models/user_account.dart
  ```

  Expected output ends with:
  ```
  No issues found!
  ```

- [ ] **Step 4: Verify the pending-technician dialog path manually**

  Confirm the logic in `mobile-app/lib/src/features/auth/login_screen.dart` around line 86:

  ```dart
  if (account.role == UserRole.technician && account.status == 'pending') {
    _showPendingDialog();
    return;
  }
  ```

  After the fix, when a technician logs in and the backend returns `verificationStatus: "pending"`, `account.status` will be `'pending'` and this branch will fire correctly.

- [ ] **Step 5: Commit**

  ```bash
  git add mobile-app/lib/src/core/models/user_account.dart
  git commit -m "fix(mobile): map verificationStatus to status in UserAccount.fromBackend"
  ```

---

## Task 3: Remove demo credential hints from login screen

**Files:**
- Modify: `mobile-app/lib/src/features/auth/login_screen.dart`

**Context:** Lines 156–176 in `login_screen.dart` render a `Container` that shows `'Demo: ahmed@test.com / test1234'` or `'Demo: khaled@test.com / test1234'`. These users don't exist in a fresh MongoDB instance and mislead testers into thinking the login should work with those credentials.

- [ ] **Step 1: Remove the demo hint container**

  In `mobile-app/lib/src/features/auth/login_screen.dart`, delete this entire block (approximately lines 155–177, the `Container` widget and its trailing `SizedBox`):

  ```dart
  // Demo credentials hint
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ServioColors.tint(servio.accent),
      borderRadius: BorderRadius.circular(ServioRadius.md),
    ),
    child: Row(
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 16, color: servio.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.role == AuthRole.customer
                ? 'Demo: ahmed@test.com / test1234'
                : 'Demo: khaled@test.com / test1234',
            style: theme.textTheme.bodySmall?.copyWith(color: servio.accent),
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: 20),
  ```

  After deletion, the section between the subtitle `Text` and the error block should go directly from:
  ```dart
  const SizedBox(height: 24),
  ```
  to:
  ```dart
  if (_errorMsg != null) ...<Widget>[
  ```

- [ ] **Step 2: Run Flutter analyzer**

  ```bash
  cd mobile-app
  flutter analyze lib/src/features/auth/login_screen.dart
  ```

  Expected:
  ```
  No issues found!
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add mobile-app/lib/src/features/auth/login_screen.dart
  git commit -m "fix(mobile): remove hardcoded demo credential hints from login screen"
  ```

---

## Task 4: End-to-end manual verification

No code changes. Verification only.

- [ ] **Step 1: Start the backend**

  ```bash
  cd backend && npm run dev
  ```

  Confirm output includes `MongoDB connected` and `Server running on port 5000`.

- [ ] **Step 2: Register a customer from the mobile app**

  Run the Flutter app on an Android emulator (`flutter run`). Navigate to Sign Up → Customer. Fill in name, phone, email, password (≥8 chars with a number, e.g. `Test1234`), city. Complete the OTP step (any 6 digits — UI-only, not backend-verified). Accept terms. Tap "Create Account".

  Expected: navigates to `CustomerHomeScreen` without error.

- [ ] **Step 3: Verify customer in MongoDB Compass**

  Open MongoDB Compass → connect to your local MongoDB → open the `users` collection. Find the document by email. Confirm:

  ```json
  {
    "role": "user",
    "verificationStatus": "approved",
    "isVerified": true,
    "isActive": true
  }
  ```

  Password field should NOT be visible (it has `select: false` in the schema — Compass shows it as absent).

- [ ] **Step 4: Login as that customer**

  Log out (if possible) or restart the app. Go to Login → Customer. Enter the email and password used in Step 2. Tap "Log In". Expected: navigates to `CustomerHomeScreen`.

- [ ] **Step 5: Register a technician from the mobile app**

  Navigate to Sign Up → Technician. Complete all 7 steps: basic info, OTP, select at least one skill, set service area, set hourly rate (50–2000), upload verification docs (tap the upload placeholders), submit. Expected: shows "Application Submitted!" screen, then navigates to `TechnicianDashboardScreen`.

- [ ] **Step 6: Verify technician in MongoDB Compass**

  Find the technician document. Confirm:

  ```json
  {
    "role": "worker",
    "verificationStatus": "pending",
    "isVerified": false,
    "skills": ["Plumbing"],
    "categories": ["plumbing"],
    "locationLabel": "<service area entered>",
    "hourlyRate": 350
  }
  ```

- [ ] **Step 7: Verify pending dialog on technician login**

  Log out, go to Login → Technician. Enter the technician's credentials. Tap "Log In". Expected: "Account Under Review" dialog appears (NOT a navigation to the dashboard).

- [ ] **Step 8: Test `GET /auth/me`**

  After any successful login, retrieve the JWT from the app (e.g. via `flutter logs` or set a breakpoint), then:

  ```bash
  curl -s -H "Authorization: Bearer <jwt>" \
       http://localhost:5000/api/v1/auth/me | jq .success
  ```

  Expected: `true`

- [ ] **Step 9: Verify wrong credentials are rejected**

  Attempt login with a non-existent email. Expected: error message in the mobile UI ("Invalid email or password."). Attempt login with correct email but wrong password. Expected: same error message.

---

## Checklist: Spec Coverage

| Spec requirement | Covered by |
|-----------------|-----------|
| Customer signup persists in MongoDB | Task 4 Step 3 |
| Technician signup persists with worker-specific fields | Task 4 Step 6 |
| Login rejects unknown email | Task 4 Step 9 |
| Login rejects wrong password | Task 4 Step 9 |
| Login fails for inactive accounts | Existing `isActive` check in `auth.service.loginUser` — no change needed |
| Login never creates users automatically | `loginUser` only calls `findOne`, never `create` — no change needed |
| Pending technician blocked after login | Task 2 fixes the status mapping; Task 4 Step 7 verifies |
| `GET /auth/me` requires JWT | Task 1 Step 5 (no-token test) |
| `GET /auth/me` returns current MongoDB user | Task 1 Step 5 (with-token test) |
| Token stored securely | Existing `flutter_secure_storage` in `SessionProvider` — no change needed |
| Role mapping `user`→`customer`, `worker`→`technician` | Existing `UserAccount.fromBackend` — no change needed |
| Duplicate email returns 409 | Existing `registerUser` check — no change needed |
| Validation errors return 422 | Existing `validate` middleware — no change needed |
| Password never returned | Existing `toJSON` transform + `select: false` — no change needed |
| Demo hints removed | Task 3 |
