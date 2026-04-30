# Mobile Backend Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the SERVIO Flutter mobile app's existing UI prototype to the live Node/Express/MongoDB backend, replacing all hardcoded demo data and local-only storage with real API calls.

**Architecture:** The API layer skeleton already exists (`ApiClient`, `AuthApi`, `ServicesApi`, `BookingsApi`, `UsersApi` under `lib/src/core/api/`) but is not wired into the app and has compilation gaps. The plan fixes those gaps first, then wires each feature in dependency order: auth → services/workers → bookings → reviews/payments → technician-side → messages.

**Tech Stack:** Flutter (Provider), `http` package (already used by `ApiClient` but missing from pubspec), `StorageService` (SharedPreferences wrapper), Node.js/Express backend at `http://10.0.2.2:5000/api/v1` (Android emulator) / `http://localhost:5000/api/v1` (iOS simulator).

---

## Pre-flight: Current Compilation Gaps

Before any integration task can run, three things will cause `flutter build` to fail:

1. `pubspec.yaml` has no `http` dependency — `ApiClient` imports it.
2. `StorageService` has no `keyAuthToken` constant or `getSecureString` method — `ApiClient` calls both.
3. `UserAccount` has no `fromBackend()` factory — `AuthApi` calls it.

**Tasks 1–3 fix these gaps. Do not skip them.**

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `mobile-app/pubspec.yaml` | Modify | Add `http: ^1.2.2` |
| `mobile-app/lib/src/core/services/storage_service.dart` | Modify | Add `keyAuthToken` constant + `getSecureString`/`setSecureString`/`removeSecureString` |
| `mobile-app/lib/src/core/models/user_account.dart` | Modify | Add `fromBackend()` factory |
| `mobile-app/lib/src/core/state/app_state.dart` | Modify | Wire `SessionProvider.login/register*` to `AuthApi`; accept `ApiClient` dependency |
| `mobile-app/lib/src/app.dart` | Modify | Construct `ApiClient` + all API objects; pass to providers |
| `mobile-app/lib/src/features/auth/login_screen.dart` | Modify | Remove artificial delay; error handling for `ApiException` |
| `mobile-app/lib/src/features/auth/sign_up_screen.dart` | Modify | Call real register methods; remove fake OTP acceptance |
| `mobile-app/lib/src/features/auth/forgot_password_screen.dart` | Create | Email input → `POST /auth/forgot-password` |
| `mobile-app/lib/src/core/api/auth_api.dart` | Modify | Add `forgotPassword()` method |
| `mobile-app/lib/src/core/api/services_api.dart` | Modify | Add `getServiceById()` |
| `mobile-app/lib/src/core/api/users_api.dart` | Modify | Add `getWorkerById()`, `updateMe()`, `updateAvailability()` |
| `mobile-app/lib/src/core/api/bookings_api.dart` | Modify | Add `createBooking()`, `getWorkerBookings()`, `updateStatus()`, `getBooking()` |
| `mobile-app/lib/src/core/api/reviews_api.dart` | Create | `getWorkerReviews()`, `submitReview()` |
| `mobile-app/lib/src/core/api/messages_api.dart` | Create | `getConversations()`, `getMessages()`, `sendMessage()` |
| `mobile-app/lib/src/core/api/payments_api.dart` | Create | `getEarnings()` |
| `mobile-app/lib/src/core/models/backend_service_model.dart` | Create | `BackendService` — maps raw backend JSON for services |
| `mobile-app/lib/src/core/models/backend_worker_model.dart` | Create | `BackendWorker` — maps raw backend JSON for workers |
| `mobile-app/lib/src/core/models/backend_booking_model.dart` | Create | `BackendBooking` — maps raw backend JSON for bookings |
| `mobile-app/lib/src/core/state/services_state.dart` | Create | `ServicesProvider` — fetches + caches services list |
| `mobile-app/lib/src/core/state/workers_state.dart` | Create | `WorkersProvider` — fetches + caches worker list |
| `mobile-app/lib/src/features/customer/services_marketplace_screen.dart` | Modify | Consume `ServicesProvider` instead of `demo_services.dart` |
| `mobile-app/lib/src/features/customer/service_detail_screen.dart` | Modify | Fetch by ID from `ServicesProvider` |
| `mobile-app/lib/src/features/customer/technician_listing_screen.dart` | Modify | Consume `WorkersProvider` instead of `kDemoTechnicians` |
| `mobile-app/lib/src/features/customer/technician_profile_screen.dart` | Modify | Fetch by ID + fetch reviews |
| `mobile-app/lib/src/features/booking/booking_step_three_screen.dart` | Modify | Call `BookingsApi.createBooking()` on confirm |
| `mobile-app/lib/src/features/customer/my_bookings_screen.dart` | Modify | Fetch from `BookingsApi.getMyBookings()` |
| `mobile-app/lib/src/features/customer/customer_dashboard_screen.dart` | Modify | Use live bookings, wire cancel to `updateStatus()` |
| `mobile-app/lib/src/features/customer/write_review_screen.dart` | Modify | Call `ReviewsApi.submitReview()` |
| `mobile-app/lib/src/features/technician/job_queue_screen.dart` | Modify | Fetch from `BookingsApi.getWorkerBookings()` |
| `mobile-app/lib/src/features/technician/job_details_screen.dart` | Modify | Call `updateStatus()` on accept/reject |
| `mobile-app/lib/src/features/technician/earnings_screen.dart` | Modify | Fetch from `PaymentsApi.getEarnings()` |
| `mobile-app/lib/src/features/technician/availability_manager_screen.dart` | Modify | Call `UsersApi.updateAvailability()` on save |
| `mobile-app/lib/src/features/messages/messages_screen.dart` | Modify | Fetch from `MessagesApi.getConversations()` |
| `mobile-app/lib/src/features/messages/chat_screen.dart` | Modify | Fetch + send via `MessagesApi` |

---

## Task 1: Fix pubspec — add `http` dependency

**Files:**
- Modify: `mobile-app/pubspec.yaml`

- [ ] **Step 1: Add `http` to dependencies**

Open `mobile-app/pubspec.yaml`. Under `dependencies:`, add:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.2
  shared_preferences: ^2.3.3
  go_router: ^14.6.2
  intl: ^0.19.0
  url_launcher: ^6.3.1
  http: ^1.2.2
```

- [ ] **Step 2: Run pub get**

```bash
cd mobile-app && flutter pub get
```

Expected: Resolves without errors. `http 1.2.x` appears in `.dart_tool/package_config.json`.

- [ ] **Step 3: Commit**

```bash
git add mobile-app/pubspec.yaml mobile-app/pubspec.lock
git commit -m "chore(mobile): add http package for API client"
```

---

## Task 2: Fix `StorageService` — add JWT helpers

`ApiClient` calls `_storage.getSecureString(StorageService.keyAuthToken)` and there is no such method or constant. We add them as simple wrappers over `getString`/`setString` (sufficient for a prototype; upgrade to `flutter_secure_storage` later for production).

**Files:**
- Modify: `mobile-app/lib/src/core/services/storage_service.dart`

- [ ] **Step 1: Add constant and methods**

Replace the entire file with:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;

  static const String keyAuthToken = 'servio_auth_token';

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  // ── String ────────────────────────────────────────────────
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  // ── Bool ──────────────────────────────────────────────────
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  // ── JSON map ──────────────────────────────────────────────
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  // ── JSON list ─────────────────────────────────────────────
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  // ── Secure (uses SharedPreferences for prototype; upgrade to
  //    flutter_secure_storage for production) ─────────────────
  Future<String?> getSecureString(String key) async => _prefs.getString(key);
  Future<void> setSecureString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> removeSecureString(String key) => _prefs.remove(key);

  // ── Remove ────────────────────────────────────────────────
  Future<void> remove(String key) => _prefs.remove(key);
}
```

- [ ] **Step 2: Verify flutter analyze passes**

```bash
cd mobile-app && flutter analyze lib/src/core/services/storage_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile-app/lib/src/core/services/storage_service.dart
git commit -m "fix(mobile): add keyAuthToken constant and secure storage helpers to StorageService"
```

---

## Task 3: Fix `UserAccount` — add `fromBackend()` factory

`AuthApi.login()` calls `UserAccount.fromBackend(json['user'])`. The backend returns:
```json
{ "_id": "...", "name": "...", "email": "...", "phone": "...", "role": "user|worker", "address": {"city": "..."}, "status": "active|pending" }
```

**Files:**
- Modify: `mobile-app/lib/src/core/models/user_account.dart`

- [ ] **Step 1: Add `fromBackend()` factory**

Replace the entire file with:

```dart
enum UserRole { customer, technician }

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.city = 'Cairo',
    this.avatarInitials = '',
    this.status = 'active',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String city;
  final String avatarInitials;
  final String status;

  String get initials {
    if (avatarInitials.isNotEmpty) return avatarInitials;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'city': city,
        'avatarInitials': avatarInitials,
        'status': status,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.customer,
        ),
        city: (json['city'] as String?) ?? 'Cairo',
        avatarInitials: (json['avatarInitials'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'active',
      );

  // Maps backend API response (uses _id, role: 'user'|'worker', nested address)
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
      status: (json['status'] as String?) ?? 'active',
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
cd mobile-app && flutter analyze lib/src/core/models/user_account.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile-app/lib/src/core/models/user_account.dart
git commit -m "fix(mobile): add UserAccount.fromBackend() factory for API response mapping"
```

---

## Task 4: Wire `ApiClient` into `ServioApp`

Currently `ApiClient` is defined but never instantiated. `ServioApp` must create it and make it available via `Provider` so screens and state classes can access it.

**Files:**
- Modify: `mobile-app/lib/src/app.dart`
- Modify: `mobile-app/lib/src/core/state/app_state.dart`

- [ ] **Step 1: Update `app_state.dart` — accept `ApiClient` in `SessionProvider`**

At the top of `app_state.dart`, add the import:
```dart
import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/api_exception.dart';
```

Change `SessionProvider` constructor to accept `ApiClient`:

```dart
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._storage, this._api);

  final StorageService _storage;
  final ApiClient _api;
  late final AuthApi _authApi = AuthApi(_api);

  UserAccount? _account;
  UserAccount? get account => _account;
  bool get isLoggedIn => _account != null;
  String get savedEmail => _storage.getString(_kKeyRememberEmail) ?? '';

  void _loadFromStorage() {
    final json = _storage.getJson(_kKeySession);
    if (json == null) return;
    try {
      _account = UserAccount.fromJson(json);
    } catch (_) {}
  }

  Future<String?> login(
    String email,
    String password, {
    bool rememberEmail = false,
  }) async {
    try {
      final session = await _authApi.login(email: email, password: password);
      _account = session.user;
      await _storage.setSecureString(StorageService.keyAuthToken, session.token);
      await _storage.setJson(_kKeySession, session.user.toJson());
      await _storage.setJson(_kKeyAccount, session.user.toJson());
      if (rememberEmail) {
        await _storage.setString(_kKeyRememberEmail, email);
      } else {
        await _storage.remove(_kKeyRememberEmail);
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unable to connect. Check your internet connection.';
    }
  }

  Future<String?> registerCustomer({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
  }) async {
    try {
      final session = await _authApi.registerCustomer(
        name: name,
        email: email,
        password: password,
        phone: phone,
        city: city,
      );
      _account = session.user;
      await _storage.setSecureString(StorageService.keyAuthToken, session.token);
      await _storage.setJson(_kKeySession, session.user.toJson());
      await _storage.setJson(_kKeyAccount, session.user.toJson());
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Registration failed. Check your connection.';
    }
  }

  Future<String?> registerTechnician({
    required String name,
    required String email,
    required String password,
    required String phone,
    required List<String> skills,
    required String serviceArea,
    required int hourlyRate,
    required String availabilityType,
  }) async {
    try {
      final session = await _authApi.registerTechnician(
        name: name,
        email: email,
        password: password,
        phone: phone,
        skills: skills,
        serviceArea: serviceArea,
        hourlyRate: hourlyRate,
        availabilityType: availabilityType,
      );
      _account = session.user;
      await _storage.setSecureString(StorageService.keyAuthToken, session.token);
      await _storage.setJson(_kKeySession, session.user.toJson());
      await _storage.setJson(_kKeyAccount, session.user.toJson());
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Registration failed. Check your connection.';
    }
  }

  Future<void> logout() async {
    _account = null;
    await _storage.remove(_kKeySession);
    await _storage.removeSecureString(StorageService.keyAuthToken);
    notifyListeners();
  }

  static SessionProvider load(StorageService storage, ApiClient api) {
    final provider = SessionProvider(storage, api);
    provider._loadFromStorage();
    return provider;
  }
}
```

Remove the import of `demo_accounts.dart` from `app_state.dart` (the old `validateDemoLogin` call is now gone).

- [ ] **Step 2: Update `app.dart` — construct `ApiClient` and pass to providers**

Replace the entire `app.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/models/user_account.dart';
import 'core/services/storage_service.dart';
import 'core/state/app_state.dart';
import 'design_system/servio_theme.dart';
import 'design_system/servio_tokens.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/customer/customer_dashboard_screen.dart';
import 'features/technician/technician_dashboard_screen.dart';
import 'features/onboarding/splash_screen.dart';

class ServioApp extends StatelessWidget {
  const ServioApp({required this.storage, super.key});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(storage: storage);

    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider.load(storage, apiClient),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(storage),
        ),
        ChangeNotifierProvider<BookingsProvider>(
          create: (_) => BookingsProvider(storage),
        ),
        ChangeNotifierProvider<MessagesProvider>(
          create: (_) => MessagesProvider(),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    final locale = context.watch<LocaleProvider>().locale;

    return MaterialApp(
      title: 'SERVIO',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      themeAnimationCurve: ServioMotion.curve,
      themeAnimationDuration: ServioMotion.micro,
      theme: ServioTheme.light(),
      darkTheme: ServioTheme.dark(),
      locale: locale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.isLoggedIn) return const RoleSelectionScreen();
    return session.account!.role == UserRole.technician
        ? const TechnicianDashboardScreen()
        : const CustomerDashboardScreen();
  }
}
```

- [ ] **Step 3: Build to verify no compilation errors**

```bash
cd mobile-app && flutter build apk --debug 2>&1 | tail -20
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk` with no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/app.dart mobile-app/lib/src/core/state/app_state.dart
git commit -m "feat(mobile): wire ApiClient into ServioApp and connect SessionProvider to AuthApi"
```

---

## Task 5: Connect Login screen — remove fake delay and demo accounts

**Files:**
- Modify: `mobile-app/lib/src/features/auth/login_screen.dart`

- [ ] **Step 1: Remove artificial delay in `_login()`**

Find the `_login()` method. Remove this line:
```dart
await Future<void>.delayed(const Duration(milliseconds: 600));
```

The method already calls `context.read<SessionProvider>().login(...)` — now that `login()` makes a real HTTP call, no artificial delay is needed.

- [ ] **Step 2: Wire "Forgot password?" button**

Find the `TextButton` with `onPressed: () {}` that currently does nothing. Change it to:

```dart
TextButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const ForgotPasswordScreen(),
    ),
  ),
  child: const Text('Forgot password?'),
),
```

Add the import at the top of the file:
```dart
import 'forgot_password_screen.dart';
```

- [ ] **Step 3: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/auth/login_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/auth/login_screen.dart
git commit -m "feat(mobile): connect login to real API, wire forgot-password navigation"
```

---

## Task 6: Create `ForgotPasswordScreen`

**Files:**
- Create: `mobile-app/lib/src/features/auth/forgot_password_screen.dart`
- Modify: `mobile-app/lib/src/core/api/auth_api.dart`

- [ ] **Step 1: Add `forgotPassword()` to `AuthApi`**

Append to `mobile-app/lib/src/core/api/auth_api.dart`:

```dart
  Future<void> forgotPassword(String email) async {
    await _client.post('/auth/forgot-password', <String, dynamic>{
      'email': email,
    });
  }
```

- [ ] **Step 2: Create `ForgotPasswordScreen`**

Create `mobile-app/lib/src/features/auth/forgot_password_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/auth_api.dart';
import '../../core/api/api_exception.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // AuthApi is created inline here — SessionProvider owns the ApiClient
      // but we don't need session state for this call.
      // We obtain ApiClient indirectly via SessionProvider's internal API.
      // Simpler: call the endpoint directly through a fresh AuthApi using
      // the same ApiClient that the SessionProvider already holds.
      // Since ApiClient is not exposed publicly, we replicate the call via http.
      // NOTE: In a larger app, expose ApiClient via Provider. For now, construct
      // a throwaway AuthApi from the session provider's client by reading the
      // base URL from ApiConfig.
      await context.read<SessionProvider>().forgotPassword(email);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(ServioSpacing.lg),
        child: _sent ? _sentView() : _formView(),
      ),
    );
  }

  Widget _sentView() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 64),
          const SizedBox(height: ServioSpacing.md),
          Text(
            'Check your inbox',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ServioSpacing.sm),
          Text(
            'A password reset link was sent to ${_emailCtrl.text.trim()}.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ServioSpacing.lg),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login'),
          ),
        ],
      );

  Widget _formView() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: ServioSpacing.xl),
          Text(
            'Reset your password',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: ServioSpacing.sm),
          const Text('Enter the email address for your account.'),
          const SizedBox(height: ServioSpacing.lg),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          if (_error != null) ...[
            const SizedBox(height: ServioSpacing.sm),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: ServioSpacing.lg),
          ServioPrimaryButton(
            label: 'Send reset link',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      );
}
```

- [ ] **Step 3: Add `forgotPassword()` to `SessionProvider` in `app_state.dart`**

Inside `SessionProvider`, add this method (uses the `_authApi` field already present):

```dart
  Future<String?> forgotPassword(String email) async {
    try {
      await _authApi.forgotPassword(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not connect. Try again.';
    }
  }
```

Update `ForgotPasswordScreen._submit()` to call `context.read<SessionProvider>().forgotPassword(email)` directly (already written that way above — just confirm `SessionProvider` has the method).

- [ ] **Step 4: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/auth/ lib/src/core/api/auth_api.dart lib/src/core/state/app_state.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/auth/forgot_password_screen.dart \
        mobile-app/lib/src/core/api/auth_api.dart \
        mobile-app/lib/src/core/state/app_state.dart
git commit -m "feat(mobile): add ForgotPasswordScreen with real forgot-password API call"
```

---

## Task 7: Connect Sign Up to real backend

**Files:**
- Modify: `mobile-app/lib/src/features/auth/sign_up_screen.dart`

The sign-up screen calls `context.read<SessionProvider>().registerCustomer(...)` and `registerTechnician(...)`. `SessionProvider` now calls the real API (from Task 4). We only need to:
1. Pass `password` (currently not passed to `registerCustomer`)
2. Show API errors instead of silently succeeding

- [ ] **Step 1: Find `_createCustomerAccount()` in `sign_up_screen.dart`**

Locate the method that calls `SessionProvider.registerCustomer()`. It likely looks like:

```dart
Future<void> _createCustomerAccount() async {
  await context.read<SessionProvider>().registerCustomer(
    name: _nameCtrl.text.trim(),
    email: _emailCtrl.text.trim(),
    phone: _phoneCtrl.text.trim(),
    city: _cityCtrl.text.trim(),
  );
  // navigate...
}
```

Replace it with:

```dart
Future<void> _createCustomerAccount() async {
  setState(() { _submitting = true; _error = null; });
  final error = await context.read<SessionProvider>().registerCustomer(
    name: _nameCtrl.text.trim(),
    email: _emailCtrl.text.trim(),
    password: _passwordCtrl.text,
    phone: _phoneCtrl.text.trim(),
    city: _cityCtrl.text.trim(),
  );
  if (!mounted) return;
  setState(() => _submitting = false);
  if (error != null) {
    setState(() => _error = error);
    return;
  }
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
    (_) => false,
  );
}
```

- [ ] **Step 2: Find `_createTechnicianAccount()` and update similarly**

```dart
Future<void> _createTechnicianAccount() async {
  setState(() { _submitting = true; _error = null; });
  final error = await context.read<SessionProvider>().registerTechnician(
    name: _nameCtrl.text.trim(),
    email: _emailCtrl.text.trim(),
    password: _passwordCtrl.text,
    phone: _phoneCtrl.text.trim(),
    skills: _specialties.toList(),
    serviceArea: _serviceAreaCtrl.text.trim(),
    hourlyRate: int.tryParse(_rateCtrl.text) ?? 350,
    availabilityType: _availability,
  );
  if (!mounted) return;
  setState(() => _submitting = false);
  if (error != null) {
    setState(() => _error = error);
    return;
  }
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute<void>(builder: (_) => const TechnicianDashboardScreen()),
    (_) => false,
  );
}
```

- [ ] **Step 3: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/auth/sign_up_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/auth/sign_up_screen.dart
git commit -m "feat(mobile): connect SignUpScreen to real registration API"
```

---

## Task 8: Backend models for Services, Workers, Bookings

The existing `ServiceModel` and `TechnicianModel` are too complex (bilingual text, demo-specific fields) to map cleanly from the simple backend JSON. We add slim backend-focused models that the UI uses when real data is available.

**Files:**
- Create: `mobile-app/lib/src/core/models/backend_service_model.dart`
- Create: `mobile-app/lib/src/core/models/backend_worker_model.dart`
- Create: `mobile-app/lib/src/core/models/backend_booking_model.dart`

Backend service JSON shape:
```json
{ "_id": "...", "name": "Plumbing", "category": "plumbing", "description": "...", "basePrice": 200, "isActive": true }
```

Backend worker JSON shape:
```json
{ "_id": "...", "name": "Ahmed", "email": "...", "skills": ["plumbing"], "locationLabel": "Cairo", "hourlyRate": 350, "rating": 4.8, "reviewCount": 12, "isVerified": true, "availabilityType": "both" }
```

Backend booking JSON shape:
```json
{ "_id": "...", "customerId": {...}, "workerId": {...}, "serviceId": {...}, "status": "pending|confirmed|in_progress|completed|cancelled", "scheduledDate": "2026-05-10T10:00:00Z", "address": {"city": "Cairo", "street": "..."}, "totalAmount": 500, "notes": "" }
```

- [ ] **Step 1: Create `backend_service_model.dart`**

```dart
class BackendService {
  const BackendService({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double basePrice;

  factory BackendService.fromJson(Map<String, dynamic> json) => BackendService(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        basePrice: ((json['basePrice'] as num?) ?? 0).toDouble(),
      );
}
```

- [ ] **Step 2: Create `backend_worker_model.dart`**

```dart
class BackendWorker {
  const BackendWorker({
    required this.id,
    required this.name,
    required this.email,
    required this.skills,
    required this.locationLabel,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.availabilityType,
  });

  final String id;
  final String name;
  final String email;
  final List<String> skills;
  final String locationLabel;
  final int hourlyRate;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String availabilityType;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'T';
  }

  factory BackendWorker.fromJson(Map<String, dynamic> json) => BackendWorker(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        skills: ((json['skills'] as List<dynamic>?) ?? <dynamic>[])
            .cast<String>(),
        locationLabel: (json['locationLabel'] as String?) ?? '',
        hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toInt(),
        rating: ((json['rating'] as num?) ?? 0).toDouble(),
        reviewCount: ((json['reviewCount'] as num?) ?? 0).toInt(),
        isVerified: (json['isVerified'] as bool?) ?? false,
        availabilityType: (json['availabilityType'] as String?) ?? 'both',
      );
}
```

- [ ] **Step 3: Create `backend_booking_model.dart`**

```dart
class BackendBooking {
  const BackendBooking({
    required this.id,
    required this.status,
    required this.scheduledDate,
    required this.totalAmount,
    required this.notes,
    required this.workerName,
    required this.workerId,
    required this.serviceName,
    required this.serviceId,
    required this.addressCity,
    required this.addressStreet,
  });

  final String id;
  final String status; // pending|confirmed|in_progress|completed|cancelled
  final DateTime scheduledDate;
  final double totalAmount;
  final String notes;
  final String workerName;
  final String workerId;
  final String serviceName;
  final String serviceId;
  final String addressCity;
  final String addressStreet;

  factory BackendBooking.fromJson(Map<String, dynamic> json) {
    final worker = json['workerId'];
    final service = json['serviceId'];
    final address = json['address'] as Map<String, dynamic>?;

    String workerName = '';
    String workerId = '';
    if (worker is Map<String, dynamic>) {
      workerName = (worker['name'] as String?) ?? '';
      workerId = (worker['_id'] as String?) ?? '';
    } else if (worker is String) {
      workerId = worker;
    }

    String serviceName = '';
    String serviceId = '';
    if (service is Map<String, dynamic>) {
      serviceName = (service['name'] as String?) ?? '';
      serviceId = (service['_id'] as String?) ?? '';
    } else if (service is String) {
      serviceId = service;
    }

    return BackendBooking(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      scheduledDate: DateTime.tryParse((json['scheduledDate'] as String?) ?? '') ??
          DateTime.now(),
      totalAmount: ((json['totalAmount'] as num?) ?? 0).toDouble(),
      notes: (json['notes'] as String?) ?? '',
      workerName: workerName,
      workerId: workerId,
      serviceName: serviceName,
      serviceId: serviceId,
      addressCity: (address?['city'] as String?) ?? '',
      addressStreet: (address?['street'] as String?) ?? '',
    );
  }
}
```

- [ ] **Step 4: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/core/models/
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/core/models/backend_service_model.dart \
        mobile-app/lib/src/core/models/backend_worker_model.dart \
        mobile-app/lib/src/core/models/backend_booking_model.dart
git commit -m "feat(mobile): add BackendService, BackendWorker, BackendBooking models"
```

---

## Task 9: Expand API classes (Services, Users, Bookings)

**Files:**
- Modify: `mobile-app/lib/src/core/api/services_api.dart`
- Modify: `mobile-app/lib/src/core/api/users_api.dart`
- Modify: `mobile-app/lib/src/core/api/bookings_api.dart`
- Create: `mobile-app/lib/src/core/api/reviews_api.dart`
- Create: `mobile-app/lib/src/core/api/messages_api.dart`
- Create: `mobile-app/lib/src/core/api/payments_api.dart`

- [ ] **Step 1: Replace `services_api.dart`**

```dart
import '../models/backend_service_model.dart';
import 'api_client.dart';

class ServicesApi {
  ServicesApi(this._client);

  final ApiClient _client;

  Future<List<BackendService>> getServices({String? category}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '100',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/services?$qs'));
    final list = (data['services'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendService.fromJson)
        .toList();
  }

  Future<BackendService> getServiceById(String id) async {
    final data = _client.unwrapData(await _client.get('/services/$id'));
    return BackendService.fromJson(data);
  }
}
```

- [ ] **Step 2: Replace `users_api.dart`**

```dart
import '../models/backend_worker_model.dart';
import 'api_client.dart';

class UsersApi {
  UsersApi(this._client);

  final ApiClient _client;

  Future<List<BackendWorker>> getWorkers({String? category}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/users/workers?$qs'));
    final list = (data['workers'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendWorker.fromJson)
        .toList();
  }

  Future<BackendWorker> getWorkerById(String id) async {
    final data = _client.unwrapData(await _client.get('/users/workers/$id'));
    return BackendWorker.fromJson(data);
  }

  Future<void> updateAvailability(Map<String, dynamic> availability) async {
    await _client.patch('/users/me/availability', availability);
  }
}
```

- [ ] **Step 3: Replace `bookings_api.dart`**

```dart
import '../models/backend_booking_model.dart';
import 'api_client.dart';

class BookingsApi {
  BookingsApi(this._client);

  final ApiClient _client;

  Future<List<BackendBooking>> getMyBookings({String? status}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/bookings/my?$qs'));
    final list = (data['bookings'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendBooking.fromJson)
        .toList();
  }

  Future<List<BackendBooking>> getWorkerBookings({String? status}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/bookings/worker?$qs'));
    final list = (data['bookings'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendBooking.fromJson)
        .toList();
  }

  Future<BackendBooking> createBooking({
    required String workerId,
    required String serviceId,
    required DateTime scheduledDate,
    required String addressCity,
    required String addressStreet,
    String notes = '',
  }) async {
    final data = _client.unwrapData(
      await _client.post('/bookings', <String, dynamic>{
        'workerId': workerId,
        'serviceId': serviceId,
        'scheduledDate': scheduledDate.toIso8601String(),
        'address': <String, dynamic>{
          'city': addressCity,
          'street': addressStreet,
        },
        if (notes.isNotEmpty) 'notes': notes,
      }),
    );
    return BackendBooking.fromJson(data);
  }

  Future<void> updateStatus(String bookingId, String status) async {
    await _client.patch('/bookings/$bookingId/status', <String, dynamic>{
      'status': status,
    });
  }

  Future<BackendBooking> getBooking(String id) async {
    final data = _client.unwrapData(await _client.get('/bookings/$id'));
    return BackendBooking.fromJson(data);
  }
}
```

- [ ] **Step 4: Create `reviews_api.dart`**

```dart
import 'api_client.dart';

class ReviewResult {
  const ReviewResult({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });

  final String id;
  final double rating;
  final String comment;
  final String reviewerName;
  final DateTime createdAt;

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    final customer = json['customerId'];
    String name = 'Anonymous';
    if (customer is Map<String, dynamic>) {
      name = (customer['name'] as String?) ?? 'Anonymous';
    }
    return ReviewResult(
      id: (json['_id'] as String?) ?? '',
      rating: ((json['rating'] as num?) ?? 0).toDouble(),
      comment: (json['comment'] as String?) ?? '',
      reviewerName: name,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class ReviewsApi {
  ReviewsApi(this._client);

  final ApiClient _client;

  Future<List<ReviewResult>> getWorkerReviews(String workerId) async {
    final data =
        _client.unwrapData(await _client.get('/reviews/worker/$workerId'));
    final list = (data['reviews'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ReviewResult.fromJson)
        .toList();
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    await _client.post('/reviews', <String, dynamic>{
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
    });
  }
}
```

- [ ] **Step 5: Create `messages_api.dart`**

```dart
import 'api_client.dart';

class ApiConversation {
  const ApiConversation({
    required this.bookingId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
  });

  final String bookingId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  factory ApiConversation.fromJson(Map<String, dynamic> json) {
    final other = json['otherUser'] as Map<String, dynamic>?;
    return ApiConversation(
      bookingId: (json['bookingId'] as String?) ?? '',
      otherUserId: (other?['_id'] as String?) ?? '',
      otherUserName: (other?['name'] as String?) ?? 'Unknown',
      lastMessage: (json['lastMessage'] as String?) ?? '',
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      unreadCount: ((json['unreadCount'] as num?) ?? 0).toInt(),
    );
  }
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String senderId;
  final DateTime createdAt;

  factory ApiMessage.fromJson(Map<String, dynamic> json) => ApiMessage(
        id: (json['_id'] as String?) ?? '',
        text: (json['content'] as String?) ?? '',
        senderId: (json['senderId'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
                DateTime.now(),
      );
}

class MessagesApi {
  MessagesApi(this._client);

  final ApiClient _client;

  Future<List<ApiConversation>> getConversations() async {
    final data = _client.unwrapData(await _client.get('/messages/conversations'));
    final list = (data['conversations'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiConversation.fromJson)
        .toList();
  }

  Future<List<ApiMessage>> getMessages(String bookingId) async {
    final data =
        _client.unwrapData(await _client.get('/messages/$bookingId'));
    final list = (data['messages'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiMessage.fromJson)
        .toList();
  }

  Future<void> sendMessage(String bookingId, String content) async {
    await _client.post('/messages', <String, dynamic>{
      'bookingId': bookingId,
      'content': content,
    });
  }
}
```

- [ ] **Step 6: Create `payments_api.dart`**

```dart
import 'api_client.dart';

class EarningsSummary {
  const EarningsSummary({
    required this.totalEarnings,
    required this.pendingPayout,
    required this.completedJobs,
  });

  final double totalEarnings;
  final double pendingPayout;
  final int completedJobs;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        totalEarnings:
            ((json['totalEarnings'] as num?) ?? 0).toDouble(),
        pendingPayout:
            ((json['pendingPayout'] as num?) ?? 0).toDouble(),
        completedJobs: ((json['completedJobs'] as num?) ?? 0).toInt(),
      );
}

class PaymentsApi {
  PaymentsApi(this._client);

  final ApiClient _client;

  Future<EarningsSummary> getEarnings({String period = 'all'}) async {
    final data = _client.unwrapData(
        await _client.get('/payments/earnings?period=$period'));
    return EarningsSummary.fromJson(data);
  }
}
```

- [ ] **Step 7: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/core/api/
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile-app/lib/src/core/api/
git commit -m "feat(mobile): expand API classes — services, users, bookings, reviews, messages, payments"
```

---

## Task 10: Create `ServicesProvider` and `WorkersProvider`

Screens need async state management for loading/error/data. We add two `ChangeNotifier` providers.

**Files:**
- Create: `mobile-app/lib/src/core/state/services_state.dart`
- Create: `mobile-app/lib/src/core/state/workers_state.dart`
- Modify: `mobile-app/lib/src/app.dart`

- [ ] **Step 1: Create `services_state.dart`**

```dart
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/services_api.dart';
import '../models/backend_service_model.dart';

class ServicesProvider extends ChangeNotifier {
  ServicesProvider(ApiClient client) : _api = ServicesApi(client);

  final ServicesApi _api;
  List<BackendService> _services = <BackendService>[];
  bool _loading = false;
  String? _error;

  List<BackendService> get services => _services;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchAll({String? category}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _services = await _api.getServices(category: category);
    } catch (e) {
      _error = 'Failed to load services.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  BackendService? findById(String id) {
    try {
      return _services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 2: Create `workers_state.dart`**

```dart
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/users_api.dart';
import '../models/backend_worker_model.dart';

class WorkersProvider extends ChangeNotifier {
  WorkersProvider(ApiClient client) : _api = UsersApi(client);

  final UsersApi _api;
  List<BackendWorker> _workers = <BackendWorker>[];
  bool _loading = false;
  String? _error;

  List<BackendWorker> get workers => _workers;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchAll({String? category}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _workers = await _api.getWorkers(category: category);
    } catch (e) {
      _error = 'Failed to load technicians.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  BackendWorker? findById(String id) {
    try {
      return _workers.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 3: Register both providers in `app.dart`**

In `ServioApp.build()`, after constructing `apiClient`, add:

```dart
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider.load(storage, apiClient),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(storage),
        ),
        ChangeNotifierProvider<BookingsProvider>(
          create: (_) => BookingsProvider(storage),
        ),
        ChangeNotifierProvider<MessagesProvider>(
          create: (_) => MessagesProvider(),
        ),
        ChangeNotifierProvider<ServicesProvider>(
          create: (_) => ServicesProvider(apiClient),
        ),
        ChangeNotifierProvider<WorkersProvider>(
          create: (_) => WorkersProvider(apiClient),
        ),
      ],
      // ...
    );
```

Add imports at top of `app.dart`:
```dart
import 'core/state/services_state.dart';
import 'core/state/workers_state.dart';
```

- [ ] **Step 4: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/core/state/ lib/src/app.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/core/state/services_state.dart \
        mobile-app/lib/src/core/state/workers_state.dart \
        mobile-app/lib/src/app.dart
git commit -m "feat(mobile): add ServicesProvider and WorkersProvider with live API fetching"
```

---

## Task 11: Connect Services Marketplace screen

**Files:**
- Modify: `mobile-app/lib/src/features/customer/services_marketplace_screen.dart`

- [ ] **Step 1: Replace demo data source with `ServicesProvider`**

At the top of the screen's `initState()` (or in a `didChangeDependencies()`), trigger a fetch:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<ServicesProvider>().fetchAll();
  });
}
```

Add the import:
```dart
import '../../core/state/services_state.dart';
import '../../core/models/backend_service_model.dart';
```

- [ ] **Step 2: Update the build method to consume `ServicesProvider`**

Where the screen previously iterated over `demoServices` (from `demo_services.dart`), replace with:

```dart
final provider = context.watch<ServicesProvider>();

if (provider.loading) {
  return const Center(child: CircularProgressIndicator());
}
if (provider.error != null) {
  return Center(child: Text(provider.error!));
}
final services = provider.services;
```

Then map `BackendService` fields to your existing card widgets:
- `service.name` → card title
- `service.category` → chip label
- `service.basePrice` → price badge (`EGP ${service.basePrice.toStringAsFixed(0)}`)
- `service.id` → used for navigation to `ServiceDetailScreen`

- [ ] **Step 3: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/customer/services_marketplace_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/customer/services_marketplace_screen.dart
git commit -m "feat(mobile): connect ServicesMarketplaceScreen to live backend API"
```

---

## Task 12: Connect Technician Listing and Profile screens

**Files:**
- Modify: `mobile-app/lib/src/features/customer/technician_listing_screen.dart`
- Modify: `mobile-app/lib/src/features/customer/technician_profile_screen.dart`

- [ ] **Step 1: Update `TechnicianListingScreen` to use `WorkersProvider`**

In `initState()`:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<WorkersProvider>().fetchAll();
});
```

In `build()`, replace `kDemoTechnicians` with:
```dart
final provider = context.watch<WorkersProvider>();
if (provider.loading) return const Center(child: CircularProgressIndicator());
if (provider.error != null) return Center(child: Text(provider.error!));
final workers = provider.workers;
```

Map `BackendWorker` to existing card widgets:
- `worker.name` → card title
- `worker.skills.join(', ')` → subtitle
- `worker.rating` → star display
- `worker.hourlyRate` → "EGP ${worker.hourlyRate}/hr"
- `worker.isVerified` → verified badge
- `worker.locationLabel` → location text
- `worker.id` → pass to `TechnicianProfileScreen`

- [ ] **Step 2: Update `TechnicianProfileScreen` to fetch by ID and reviews**

The screen receives a `technicianId`. Add state to load from API if not already in `WorkersProvider`:

```dart
BackendWorker? _worker;
List<ReviewResult> _reviews = <ReviewResult>[];
bool _loading = true;
String? _error;

@override
void initState() {
  super.initState();
  _load();
}

Future<void> _load() async {
  try {
    // Try cache first
    final cached = context.read<WorkersProvider>().findById(widget.technicianId);
    if (cached != null) {
      setState(() { _worker = cached; });
    } else {
      final worker = await UsersApi(
        // Get ApiClient via provider — see note below
      ).getWorkerById(widget.technicianId);
      setState(() { _worker = worker; });
    }
    // Always fetch fresh reviews
    final reviews = await ReviewsApi(/* client */).getWorkerReviews(widget.technicianId);
    setState(() { _reviews = reviews; });
  } catch (e) {
    setState(() { _error = 'Could not load technician profile.'; });
  } finally {
    setState(() { _loading = false; });
  }
}
```

**Note on ApiClient access:** To avoid passing `ApiClient` through all screens, expose it via a `Provider<ApiClient>` in `app.dart`. Add to `ServioApp.build()` providers list:

```dart
Provider<ApiClient>.value(value: apiClient),
```

Then in screens that need direct API calls:
```dart
final client = context.read<ApiClient>();
final api = UsersApi(client);
```

Add this `Provider<ApiClient>` to `app.dart` now (in the same commit as this task).

- [ ] **Step 3: Render `_reviews` list in profile screen**

Where the screen shows hardcoded inline reviews, replace with:
```dart
..._reviews.map((r) => _ReviewTile(
  name: r.reviewerName,
  rating: r.rating,
  comment: r.comment,
)),
```

- [ ] **Step 4: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/customer/technician_listing_screen.dart lib/src/features/customer/technician_profile_screen.dart lib/src/app.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/customer/technician_listing_screen.dart \
        mobile-app/lib/src/features/customer/technician_profile_screen.dart \
        mobile-app/lib/src/app.dart
git commit -m "feat(mobile): connect TechnicianListing and TechnicianProfile to live API"
```

---

## Task 13: Connect Booking Creation

**Files:**
- Modify: `mobile-app/lib/src/features/booking/booking_step_three_screen.dart`

The confirm step must call `BookingsApi.createBooking()` instead of writing to local `BookingsProvider`.

- [ ] **Step 1: Update `_confirmBooking()` in `booking_step_three_screen.dart`**

Find `_confirmBooking()`. Replace the local `BookingsProvider.add()` call with:

```dart
Future<void> _confirmBooking() async {
  setState(() => _loading = true);
  try {
    final client = context.read<ApiClient>();
    final api = BookingsApi(client);

    final booking = await api.createBooking(
      workerId: widget.technicianId,   // must be MongoDB ObjectId from TechnicianProfile
      serviceId: widget.serviceId,     // must be MongoDB ObjectId from ServiceDetail
      scheduledDate: widget.selectedDate,
      addressCity: widget.addressCity,
      addressStreet: widget.addressStreet,
      notes: widget.notes,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingConfirmationScreen(bookingId: booking.id),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    setState(() => _error = 'Booking failed. Please try again.');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

**Important:** `widget.technicianId` and `widget.serviceId` must be the real MongoDB `_id` strings (not display names). Verify that `TechnicianProfileScreen` passes `BackendWorker.id` and the selected service's `BackendService.id` through the booking flow. Trace through `BookingStepOneScreen` → `BookingStepTwoScreen` → `BookingStepThreeScreen` to confirm these IDs are threaded through as parameters.

- [ ] **Step 2: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/booking/
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile-app/lib/src/features/booking/
git commit -m "feat(mobile): connect booking confirmation to POST /api/v1/bookings"
```

---

## Task 14: Connect My Bookings and Customer Dashboard

**Files:**
- Modify: `mobile-app/lib/src/features/customer/my_bookings_screen.dart`
- Modify: `mobile-app/lib/src/features/customer/customer_dashboard_screen.dart`

- [ ] **Step 1: Update `MyBookingsScreen` to fetch from API**

Add state:
```dart
List<BackendBooking> _bookings = <BackendBooking>[];
bool _loading = true;
String? _error;
```

In `initState()`:
```dart
_fetchBookings();
```

Add:
```dart
Future<void> _fetchBookings() async {
  try {
    final client = context.read<ApiClient>();
    _bookings = await BookingsApi(client).getMyBookings();
  } catch (_) {
    _error = 'Could not load bookings.';
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Add imports:
```dart
import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
```

- [ ] **Step 2: Map `BackendBooking` to existing list-item widgets**

`BackendBooking` fields → UI:
- `booking.workerName` → technician name
- `booking.serviceName` → service title
- `booking.scheduledDate` → format with `intl`: `DateFormat('MMM d, y – h:mm a').format(booking.scheduledDate)`
- `booking.status` → status chip color
- `booking.totalAmount` → "EGP ${booking.totalAmount.toStringAsFixed(0)}"
- `booking.addressCity` → location line

- [ ] **Step 3: Wire Cancel to API in dashboard**

Where `updateStatus()` is called with `BookingStatus.cancelled`:

```dart
Future<void> _cancelBooking(String bookingId) async {
  try {
    final client = context.read<ApiClient>();
    await BookingsApi(client).updateStatus(bookingId, 'cancelled');
    await _fetchBookings(); // refresh
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not cancel booking.')),
    );
  }
}
```

- [ ] **Step 4: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/customer/my_bookings_screen.dart lib/src/features/customer/customer_dashboard_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/customer/my_bookings_screen.dart \
        mobile-app/lib/src/features/customer/customer_dashboard_screen.dart
git commit -m "feat(mobile): connect MyBookings and CustomerDashboard to live bookings API"
```

---

## Task 15: Connect Write Review

**Files:**
- Modify: `mobile-app/lib/src/features/customer/write_review_screen.dart`

- [ ] **Step 1: Update `_submit()` to call `ReviewsApi`**

The screen must receive the real `bookingId` (MongoDB ObjectId) as a constructor parameter. Verify it's passed from the booking details screen. If not, add it as a required parameter.

Find the `_submit()` method (currently just calls `Navigator.pop(true)`). Replace with:

```dart
Future<void> _submit() async {
  if (_rating == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a star rating.')),
    );
    return;
  }
  setState(() => _loading = true);
  try {
    final client = context.read<ApiClient>();
    await ReviewsApi(client).submitReview(
      bookingId: widget.bookingId,
      rating: _rating,
      comment: _commentCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to submit review. Try again.')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Add imports:
```dart
import '../../core/api/api_client.dart';
import '../../core/api/reviews_api.dart';
```

- [ ] **Step 2: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/customer/write_review_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile-app/lib/src/features/customer/write_review_screen.dart
git commit -m "feat(mobile): connect WriteReviewScreen to POST /api/v1/reviews"
```

---

## Task 16: Connect Technician Job Queue and Job Details

**Files:**
- Modify: `mobile-app/lib/src/features/technician/job_queue_screen.dart`
- Modify: `mobile-app/lib/src/features/technician/job_details_screen.dart`

- [ ] **Step 1: Update `JobQueueScreen` to fetch from API**

Add state and load in `initState()`:

```dart
List<BackendBooking> _jobs = <BackendBooking>[];
bool _loading = true;
String? _error;

Future<void> _fetchJobs() async {
  try {
    final client = context.read<ApiClient>();
    _jobs = await BookingsApi(client).getWorkerBookings();
  } catch (_) {
    _error = 'Could not load jobs.';
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Filter by tab (Pending / Confirmed / In Progress / Completed):
```dart
List<BackendBooking> _filtered(String status) =>
    _jobs.where((j) => j.status == status).toList();
```

- [ ] **Step 2: Update `JobDetailsScreen` — accept/reject/complete actions**

Find buttons for accepting and rejecting jobs. Wire each to:

```dart
Future<void> _updateStatus(String status) async {
  try {
    final client = context.read<ApiClient>();
    await BookingsApi(client).updateStatus(widget.jobId, status);
    if (!mounted) return;
    Navigator.pop(context, true); // pop and signal refresh
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action failed. Try again.')),
    );
  }
}
```

Call:
- Accept → `_updateStatus('confirmed')`
- Reject → `_updateStatus('cancelled')`
- Start job → `_updateStatus('in_progress')`
- Complete → `_updateStatus('completed')`

- [ ] **Step 3: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/technician/
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/technician/job_queue_screen.dart \
        mobile-app/lib/src/features/technician/job_details_screen.dart
git commit -m "feat(mobile): connect technician job queue and job details to live API"
```

---

## Task 17: Connect Earnings and Availability Manager

**Files:**
- Modify: `mobile-app/lib/src/features/technician/earnings_screen.dart`
- Modify: `mobile-app/lib/src/features/technician/availability_manager_screen.dart`

- [ ] **Step 1: Update `EarningsScreen` to fetch real earnings**

Add state and fetch:

```dart
EarningsSummary? _summary;
bool _loading = true;

Future<void> _fetchEarnings() async {
  try {
    final client = context.read<ApiClient>();
    _summary = await PaymentsApi(client).getEarnings();
  } catch (_) {
    // keep summary null — show dash/zero
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

In `build()`, replace hardcoded numbers with:
```dart
final earnings = _summary?.totalEarnings ?? 0.0;
final pending = _summary?.pendingPayout ?? 0.0;
final jobs = _summary?.completedJobs ?? 0;
```

Add import:
```dart
import '../../core/api/api_client.dart';
import '../../core/api/payments_api.dart';
```

- [ ] **Step 2: Update `AvailabilityManagerScreen` save action**

Find the Save/Update button `onPressed`. Replace with:

```dart
Future<void> _saveAvailability() async {
  try {
    final client = context.read<ApiClient>();
    await UsersApi(client).updateAvailability(<String, dynamic>{
      'type': _selectedType, // 'weekdays'|'weekends'|'both'
      'hours': <String, dynamic>{
        'start': _startTime,
        'end': _endTime,
      },
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Availability updated.')),
    );
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update availability.')),
    );
  }
}
```

Adjust `_selectedType`, `_startTime`, `_endTime` to match whatever local state the screen already tracks.

- [ ] **Step 3: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/technician/earnings_screen.dart lib/src/features/technician/availability_manager_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/technician/earnings_screen.dart \
        mobile-app/lib/src/features/technician/availability_manager_screen.dart
git commit -m "feat(mobile): connect Earnings and AvailabilityManager to live API"
```

---

## Task 18: Connect Messages (Conversations + Chat)

**Files:**
- Modify: `mobile-app/lib/src/features/messages/messages_screen.dart`
- Modify: `mobile-app/lib/src/features/messages/chat_screen.dart`

- [ ] **Step 1: Update `MessagesScreen` to fetch real conversations**

Add state:
```dart
List<ApiConversation> _conversations = <ApiConversation>[];
bool _loading = true;
```

Fetch in `initState()`:
```dart
Future<void> _fetchConversations() async {
  try {
    final client = context.read<ApiClient>();
    _conversations = await MessagesApi(client).getConversations();
  } catch (_) {
    // fallback: keep empty list
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Map `ApiConversation` to list tile:
- `conv.otherUserName` → contact name
- `conv.lastMessage` → last message preview
- `conv.unreadCount` → badge
- `conv.bookingId` → pass to `ChatScreen`

- [ ] **Step 2: Update `ChatScreen` to fetch real messages and send via API**

`ChatScreen` receives `bookingId`. Fetch on load:
```dart
Future<void> _fetchMessages() async {
  try {
    final client = context.read<ApiClient>();
    final msgs = await MessagesApi(client).getMessages(widget.bookingId);
    setState(() => _messages = msgs);
  } catch (_) {}
}
```

Wire send button:
```dart
Future<void> _send(String text) async {
  if (text.trim().isEmpty) return;
  _inputCtrl.clear();
  try {
    final client = context.read<ApiClient>();
    await MessagesApi(client).sendMessage(widget.bookingId, text);
    await _fetchMessages(); // reload
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to send message.')),
    );
  }
}
```

- [ ] **Step 3: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/messages/
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/messages/messages_screen.dart \
        mobile-app/lib/src/features/messages/chat_screen.dart
git commit -m "feat(mobile): connect MessagesScreen and ChatScreen to live messaging API"
```

---

## Task 19: Connect AI Smart Match

**Files:**
- Modify: `mobile-app/lib/src/features/customer/ai_smart_match_screen.dart`

- [ ] **Step 1: Update `_analyze()` to call `POST /api/v1/ai/recommend`**

Find `_analyze()`. Replace:

```dart
Future<void> _analyze() async {
  final query = _queryCtrl.text.trim();
  if (query.isEmpty) return;
  setState(() { _loading = true; _showResults = false; _error = null; });
  try {
    final client = context.read<ApiClient>();
    final response = await client.post('/ai/recommend', <String, dynamic>{
      'query': query,
    });
    // Backend returns { data: { recommendations: [...] } }
    // Map to your existing results display structure
    final data = client.unwrapData(response);
    _results = data; // store raw map; adapt display widgets to real keys
    setState(() => _showResults = true);
  } catch (e) {
    setState(() => _error = 'AI service unavailable. Try again later.');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Add import:
```dart
import '../../core/api/api_client.dart';
```

**Note:** The AI microservice may return different JSON than the hardcoded demo. After calling the real endpoint, check the response shape and update the results display widgets accordingly.

- [ ] **Step 2: Run analyze**

```bash
cd mobile-app && flutter analyze lib/src/features/customer/ai_smart_match_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile-app/lib/src/features/customer/ai_smart_match_screen.dart
git commit -m "feat(mobile): connect AI Smart Match to POST /api/v1/ai/recommend"
```

---

## Task 20: Final build verification and cleanup

- [ ] **Step 1: Full release build**

```bash
cd mobile-app && flutter build apk --release 2>&1 | tail -30
```

Expected: `Built build/app/outputs/flutter-apk/app-release.apk` with no `error:` lines.

- [ ] **Step 2: Run full analyzer**

```bash
cd mobile-app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Remove unused demo data files**

After all screens are connected to live data, these files can be deleted:

```bash
rm mobile-app/lib/src/core/data/demo_accounts.dart
rm mobile-app/lib/src/core/data/demo_services.dart
rm mobile-app/lib/src/core/data/demo_technicians.dart
```

Check no file still imports them:
```bash
cd mobile-app && grep -r "demo_accounts\|demo_services\|demo_technicians" lib/
```

Expected: no output.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore(mobile): remove unused demo data files after full backend integration"
```

---

## Self-Review Checklist

**Spec coverage check:**

| Report Priority | Covered in Plan? | Task(s) |
|----------------|-----------------|---------|
| Foundation: HTTP client | Yes | Task 1 |
| Foundation: StorageService | Yes | Task 2 |
| Foundation: UserAccount.fromBackend | Yes | Task 3 |
| Foundation: Wire ApiClient | Yes | Task 4 |
| Auth: Login | Yes | Task 4, 5 |
| Auth: Register | Yes | Task 7 |
| Auth: Forgot Password | Yes | Task 6 |
| Services Marketplace | Yes | Task 9, 10, 11 |
| Technician Listing + Profile | Yes | Task 9, 10, 12 |
| Booking Creation | Yes | Task 9, 13 |
| My Bookings + Dashboard | Yes | Task 9, 14 |
| Write Review | Yes | Task 9, 15 |
| Technician Job Queue + Details | Yes | Task 9, 16 |
| Technician Earnings | Yes | Task 9, 17 |
| Availability Manager | Yes | Task 9, 17 |
| Messages + Chat | Yes | Task 9, 18 |
| AI Smart Match | Yes | Task 19 |
| Admin Dashboard | Not included — intentionally web-only |
| Reset Password deep link | Not included — requires app link config; out of scope for MVP |
| Stripe payments | Not included — requires `flutter_stripe` package and additional backend setup; separate task |
| File uploads (technician signup) | Not included — requires `image_picker`; separate task |
| Push notifications | Not included — requires Firebase setup on both sides; separate task |
| AI Estimator | Not included — AI microservice is placeholder; blocked |
