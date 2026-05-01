# Mobile Edit-Profile Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Flutter mobile edit-profile screens for both customer and technician roles to the existing `PATCH /api/v1/users/me` backend endpoint so that profile changes persist in MongoDB and reload correctly after restart/re-login.

**Architecture:** The backend already has `PATCH /api/v1/users/me` with `updateProfile` controller, but its validation and `allowedFields` whitelist are missing several worker-specific fields (`yearsExperience`, `availabilityType`, `categories`). On the Flutter side the `UserAccount` model is missing those fields, `UsersApi` has no `updateProfile` method, `SessionProvider` has no corresponding action, and both edit screens discard form data on save (they just call `Navigator.pop`). The fix is: extend backend validation + allowedFields → extend Flutter model → add API + provider method → wire both edit screens.

**Tech Stack:** Node.js/Express/Mongoose (backend), Flutter/Dart with Provider (mobile), `flutter_secure_storage`, existing `ApiClient.patch()`.

---

## File Structure

| File | Change |
|------|--------|
| `backend/src/modules/users/user.routes.js` | Extend `profileUpdateValidation` to cover `bio`, `hourlyRate`, `skills`, `locationLabel`, `yearsExperience`, `availabilityType`, `categories` |
| `backend/src/modules/users/user.controller.js` | Add `yearsExperience`, `availabilityType`, `categories` to `allowedFields` in `updateProfile` |
| `mobile-app/lib/src/core/models/user_account.dart` | Add `bio`, `hourlyRate`, `skills`, `locationLabel`, `yearsExperience`, `availabilityType`, `categories` fields; update `fromBackend`, `fromJson`, `toJson` |
| `mobile-app/lib/src/core/api/users_api.dart` | Add `updateProfile(Map<String, dynamic> fields)` method → `PATCH /users/me` |
| `mobile-app/lib/src/core/state/app_state.dart` | Add `updateProfile(Map<String, dynamic>)` to `SessionProvider`; refresh account via `AuthApi.getMe()` on success |
| `mobile-app/lib/src/features/customer/edit_profile_screen.dart` | Pre-fill phone + bio; wire save button to `SessionProvider.updateProfile`; add loading state and error snackbar |
| `mobile-app/lib/src/features/technician/technician_edit_profile_screen.dart` | Same wiring; add `hourlyRate`, `skills`, `locationLabel`, `yearsExperience`, `availabilityType` fields to the form |

---

## Task 1: Extend backend validation and allowedFields

**Files:**
- Modify: `backend/src/modules/users/user.routes.js` (lines 17–21 `profileUpdateValidation`)
- Modify: `backend/src/modules/users/user.controller.js` (lines 81–100 `allowedFields`)

- [ ] **Step 1: Update `profileUpdateValidation` in user.routes.js**

Replace the existing `profileUpdateValidation` array (lines 17–21) with:

```js
const profileUpdateValidation = [
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty'),
  body('phone').optional().isMobilePhone().withMessage('Invalid phone number'),
  body('profileImage').optional().isURL().withMessage('Profile image must be a valid URL'),
  body('bio').optional().trim().isLength({ max: 1000 }).withMessage('Bio cannot exceed 1000 characters'),
  body('hourlyRate').optional().isFloat({ min: 0 }).withMessage('Hourly rate must be a non-negative number'),
  body('locationLabel').optional().trim().isLength({ max: 200 }).withMessage('Location label too long'),
  body('yearsExperience').optional().isInt({ min: 0 }).withMessage('Years of experience must be a non-negative integer'),
  body('availabilityType').optional().isIn(['weekdays', 'weekends', 'both', '']).withMessage('Invalid availability type'),
  body('skills').optional().isArray().withMessage('Skills must be an array'),
  body('skills.*').optional().isString().trim().notEmpty().withMessage('Each skill must be a non-empty string'),
  body('categories').optional().isArray().withMessage('Categories must be an array'),
  body('categories.*').optional().isIn(['plumbing','electrical','painting','flooring','carpentry','cleaning','hvac','other']).withMessage('Invalid category'),
];
```

- [ ] **Step 2: Add missing fields to `allowedFields` in user.controller.js**

In `updateProfile`, the `allowedFields` array starts at line 81. Add `yearsExperience`, `availabilityType`, and `categories` to it:

```js
const allowedFields = [
  'name',
  'email',
  'bio',
  'phone',
  'profileImage',
  'address',
  'locationLabel',
  'hourlyRate',
  'skills',
  'yearsExperience',
  'availabilityType',
  'categories',
  'idFrontUrl',
  'idFrontName',
  'idBackUrl',
  'idBackName',
  'idSelfieUrl',
  'idSelfieName',
  'cvUrl',
  'cvName',
  'portfolioFiles',
];
```

- [ ] **Step 3: Verify backend syntax**

```bash
cd backend
node --check src/modules/users/user.routes.js
node --check src/modules/users/user.controller.js
```

Expected: no output (clean).

- [ ] **Step 4: Start backend and confirm the route is reachable**

```bash
cd backend
npm run dev
```

Expected: `✅ MongoDB connected` and `Server running on port 5000`. Keep running in background or stop with Ctrl+C after confirming startup.

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/users/user.routes.js backend/src/modules/users/user.controller.js
git commit -m "feat(backend): extend profile update validation and allowedFields for worker fields"
```

---

## Task 2: Extend Flutter UserAccount model

**Files:**
- Modify: `mobile-app/lib/src/core/models/user_account.dart`

- [ ] **Step 1: Replace the entire file with the extended model**

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
    this.bio = '',
    this.hourlyRate = 0.0,
    this.skills = const [],
    this.locationLabel = '',
    this.yearsExperience = 0,
    this.availabilityType = '',
    this.categories = const [],
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String city;
  final String avatarInitials;
  final String status;
  final String bio;
  final double hourlyRate;
  final List<String> skills;
  final String locationLabel;
  final int yearsExperience;
  final String availabilityType;
  final List<String> categories;

  String get initials {
    if (avatarInitials.isNotEmpty) return avatarInitials;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  UserAccount copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? city,
    String? avatarInitials,
    String? status,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
    String? locationLabel,
    int? yearsExperience,
    String? availabilityType,
    List<String>? categories,
  }) =>
      UserAccount(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        city: city ?? this.city,
        avatarInitials: avatarInitials ?? this.avatarInitials,
        status: status ?? this.status,
        bio: bio ?? this.bio,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        skills: skills ?? this.skills,
        locationLabel: locationLabel ?? this.locationLabel,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        availabilityType: availabilityType ?? this.availabilityType,
        categories: categories ?? this.categories,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'city': city,
        'avatarInitials': avatarInitials,
        'status': status,
        'bio': bio,
        'hourlyRate': hourlyRate,
        'skills': skills,
        'locationLabel': locationLabel,
        'yearsExperience': yearsExperience,
        'availabilityType': availabilityType,
        'categories': categories,
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
        bio: (json['bio'] as String?) ?? '',
        hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toDouble(),
        skills: List<String>.from((json['skills'] as List<dynamic>?) ?? []),
        locationLabel: (json['locationLabel'] as String?) ?? '',
        yearsExperience: (json['yearsExperience'] as int?) ?? 0,
        availabilityType: (json['availabilityType'] as String?) ?? '',
        categories: List<String>.from((json['categories'] as List<dynamic>?) ?? []),
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
      status: (json['verificationStatus'] as String?) ??
              (json['status'] as String?) ?? 'active',
      bio: (json['bio'] as String?) ?? '',
      hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toDouble(),
      skills: List<String>.from((json['skills'] as List<dynamic>?) ?? []),
      locationLabel: (json['locationLabel'] as String?) ?? '',
      yearsExperience: (json['yearsExperience'] as int?) ?? 0,
      availabilityType: (json['availabilityType'] as String?) ?? '',
      categories: List<String>.from((json['categories'] as List<dynamic>?) ?? []),
    );
  }
}
```

- [ ] **Step 2: Run dart format**

```bash
cd mobile-app
dart format lib/src/core/models/user_account.dart
```

Expected: `Formatted 1 file` or `No changes`.

- [ ] **Step 3: Commit**

```bash
git add mobile-app/lib/src/core/models/user_account.dart
git commit -m "feat(mobile): extend UserAccount model with worker profile fields"
```

---

## Task 3: Add updateProfile to UsersApi

**Files:**
- Modify: `mobile-app/lib/src/core/api/users_api.dart`

- [ ] **Step 1: Add `updateProfile` method**

The file currently ends at line 31. Add one method before the closing `}`:

```dart
import '../models/backend_worker_model.dart';
import '../models/user_account.dart';
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
    return list.whereType<Map<String, dynamic>>().map(BackendWorker.fromJson).toList();
  }

  Future<BackendWorker> getWorkerById(String id) async {
    final data = _client.unwrapData(await _client.get('/users/workers/$id'));
    return BackendWorker.fromJson(data);
  }

  Future<void> updateAvailability(Map<String, dynamic> availability) async {
    await _client.patch('/users/me/availability', availability);
  }

  Future<UserAccount> updateProfile(Map<String, dynamic> fields) async {
    final response = await _client.patch('/users/me', fields);
    return UserAccount.fromBackend(_client.unwrapData(response));
  }
}
```

- [ ] **Step 2: Run dart format**

```bash
cd mobile-app
dart format lib/src/core/api/users_api.dart
```

- [ ] **Step 3: Run flutter analyze on the file**

```bash
cd mobile-app
flutter analyze lib/src/core/api/users_api.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/core/api/users_api.dart
git commit -m "feat(mobile): add updateProfile method to UsersApi"
```

---

## Task 4: Add updateProfile to SessionProvider

**Files:**
- Modify: `mobile-app/lib/src/core/state/app_state.dart`

- [ ] **Step 1: Add `UsersApi` import and `updateProfile` method to `SessionProvider`**

At the top of `app_state.dart`, add the import (after the existing `auth_api.dart` import):

```dart
import '../api/users_api.dart';
```

Inside `SessionProvider`, add `_usersApi` field (after the `_authApi` field) and the `updateProfile` method (after `forgotPassword`, before `logout`):

The complete new section to insert after line 27 (`late final AuthApi _authApi = AuthApi(_apiClient);`):

```dart
  late final AuthApi _authApi = AuthApi(_apiClient);
  late final UsersApi _usersApi = UsersApi(_apiClient);
```

The new `updateProfile` method to insert after the `forgotPassword` method (after line 139):

```dart
  Future<String?> updateProfile(Map<String, dynamic> fields) async {
    try {
      await _usersApi.updateProfile(fields);
      final refreshed = await _authApi.getMe();
      _account = refreshed;
      await _storage.setJson(_kKeySession, refreshed.toJson());
      await _storage.setJson(_kKeyAccount, refreshed.toJson());
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save profile. Check your connection.';
    }
  }
```

The full file after edits should look like this (complete replacement):

```dart
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../api/users_api.dart';
import '../models/booking_model.dart';
import '../models/message_model.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';

// ── Storage keys ──────────────────────────────────────────────────────────────
const String _kKeyAccount = 'servio_account';
const String _kKeySession = 'servio_session';
const String _kKeyRememberEmail = 'servio_remember_email';
const String _kKeyBookings = 'servio_bookings';
const String _kKeyThemeMode = 'servio_theme_mode';
const String _kKeyLocale = 'servio_locale';

// ── SessionProvider ───────────────────────────────────────────────────────────

class SessionProvider extends ChangeNotifier {
  SessionProvider(this._storage, this._apiClient);

  final StorageService _storage;
  final ApiClient _apiClient;
  late final AuthApi _authApi = AuthApi(_apiClient);
  late final UsersApi _usersApi = UsersApi(_apiClient);

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

  Future<String?> updateProfile(Map<String, dynamic> fields) async {
    try {
      await _usersApi.updateProfile(fields);
      final refreshed = await _authApi.getMe();
      _account = refreshed;
      await _storage.setJson(_kKeySession, refreshed.toJson());
      await _storage.setJson(_kKeyAccount, refreshed.toJson());
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save profile. Check your connection.';
    }
  }

  Future<void> logout() async {
    _account = null;
    await _storage.remove(_kKeySession);
    await _storage.removeSecureString(StorageService.keyAuthToken);
    notifyListeners();
  }

  static SessionProvider load(StorageService storage, ApiClient apiClient) {
    final provider = SessionProvider(storage, apiClient);
    provider._loadFromStorage();
    return provider;
  }
}

// ── ThemeProvider ─────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._storage) {
    final saved = _storage.getString(_kKeyThemeMode);
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  final StorageService _storage;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _storage.setString(_kKeyThemeMode, mode.name);
    notifyListeners();
  }
}

// ── LocaleProvider ────────────────────────────────────────────────────────────

class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._storage) {
    final saved = _storage.getString(_kKeyLocale);
    _locale = (saved == 'ar') ? const Locale('ar') : const Locale('en');
  }

  final StorageService _storage;
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _storage.setString(_kKeyLocale, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() => setLocale(
        isArabic ? const Locale('en') : const Locale('ar'),
      );
}

// ── BookingsProvider ──────────────────────────────────────────────────────────

class BookingsProvider extends ChangeNotifier {
  BookingsProvider(this._storage) {
    _load();
  }

  final StorageService _storage;
  final List<BookingModel> _bookings = <BookingModel>[];

  List<BookingModel> get all => List<BookingModel>.unmodifiable(_bookings);

  List<BookingModel> get upcoming => _bookings
      .where((b) => b.status == BookingStatus.upcoming || b.status == BookingStatus.inProgress)
      .toList();

  List<BookingModel> get past => _bookings
      .where((b) => b.status == BookingStatus.completed || b.status == BookingStatus.cancelled)
      .toList();

  void _load() {
    final list = _storage.getJsonList(_kKeyBookings);
    _bookings.addAll(list.map(BookingModel.fromJson));
  }

  Future<void> _save() async {
    await _storage.setJsonList(
      _kKeyBookings,
      _bookings.map((b) => b.toJson()).toList(),
    );
  }

  Future<void> add(BookingModel booking) async {
    _bookings.insert(0, booking);
    await _save();
    notifyListeners();
  }

  Future<void> updateStatus(String bookingId, BookingStatus status) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) return;
    _bookings[idx] = _bookings[idx].copyWith(status: status);
    await _save();
    notifyListeners();
  }
}

// ── MessagesProvider ──────────────────────────────────────────────────────────

class MessagesProvider extends ChangeNotifier {
  MessagesProvider() {
    _initDemoConversations();
  }

  final List<ConversationModel> _conversations = <ConversationModel>[];

  List<ConversationModel> get conversations => _conversations;

  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void _initDemoConversations() {
    _conversations.addAll(<ConversationModel>[
      ConversationModel(
        id: 'conv_khaled',
        contactName: 'Khaled Mohamed',
        contactInitials: 'KM',
        lastMessage: 'I\'ll be there by 10 AM.',
        time: '10:32 AM',
        unreadCount: 2,
        messages: <ChatMessage>[
          const ChatMessage(
              text: 'Hello, I\'ve confirmed your booking for tomorrow.',
              isMe: false,
              time: '10:25 AM'),
          const ChatMessage(
              text: 'Great, what time should I expect you?',
              isMe: true,
              time: '10:30 AM'),
          const ChatMessage(
              text: 'I\'ll be there by 10 AM.',
              isMe: false,
              time: '10:32 AM'),
        ],
      ),
      ConversationModel(
        id: 'conv_mahmoud',
        contactName: 'Mahmoud Ibrahim',
        contactInitials: 'MI',
        lastMessage: 'Parts ordered, will call when ready.',
        time: 'Yesterday',
        unreadCount: 0,
        messages: <ChatMessage>[
          const ChatMessage(
              text: 'The panel upgrade needs a specific breaker.',
              isMe: false,
              time: 'Yesterday 2:00 PM'),
          const ChatMessage(
              text: 'How long will that take to source?', isMe: true, time: 'Yesterday 2:10 PM'),
          const ChatMessage(
              text: 'Parts ordered, will call when ready.',
              isMe: false,
              time: 'Yesterday 2:15 PM'),
        ],
      ),
    ]);
  }

  void sendMessage(String conversationId, String text) {
    final conv = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw StateError('Conversation not found: $conversationId'),
    );
    final now = _timeNow();
    conv.messages.add(ChatMessage(text: text, isMe: true, time: now));
    conv.lastMessage = text;
    conv.time = now;

    Future<void>.delayed(const Duration(seconds: 2), () {
      conv.messages.add(ChatMessage(
        text: _autoReply(text),
        isMe: false,
        time: _timeNow(),
      ));
      conv.lastMessage = conv.messages.last.text;
      conv.time = _timeNow();
      notifyListeners();
    });

    notifyListeners();
  }

  void markRead(String conversationId) {
    final conv = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw StateError('Conversation not found: $conversationId'),
    );
    if (conv.unreadCount > 0) {
      conv.unreadCount = 0;
      notifyListeners();
    }
  }

  ConversationModel? findOrCreate(String technicianId, String technicianName) {
    final id = 'conv_$technicianId';
    final existing = _conversations.where((c) => c.id == id).firstOrNull;
    if (existing != null) return existing;

    final initials = technicianName.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase();
    final conv = ConversationModel(
      id: id,
      contactName: technicianName,
      contactInitials: initials,
      lastMessage: 'New conversation',
      time: _timeNow(),
    );
    _conversations.insert(0, conv);
    notifyListeners();
    return conv;
  }

  static String _timeNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _autoReply(String userMsg) {
    final lower = userMsg.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hi there! How can I help you?';
    }
    if (lower.contains('time') || lower.contains('when')) {
      return 'I\'ll let you know as soon as I can confirm the schedule.';
    }
    if (lower.contains('price') || lower.contains('cost') || lower.contains('how much')) {
      return 'I\'ll send you a detailed quote shortly.';
    }
    if (lower.contains('thank')) {
      return 'You\'re welcome! Happy to help.';
    }
    return 'Got it, I\'ll get back to you shortly.';
  }
}
```

- [ ] **Step 2: Run dart format**

```bash
cd mobile-app
dart format lib/src/core/state/app_state.dart
```

- [ ] **Step 3: Run flutter analyze on the file**

```bash
cd mobile-app
flutter analyze lib/src/core/state/app_state.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/core/state/app_state.dart
git commit -m "feat(mobile): add updateProfile to SessionProvider with post-save account refresh"
```

---

## Task 5: Wire up customer EditProfileScreen

**Files:**
- Modify: `mobile-app/lib/src/features/customer/edit_profile_screen.dart`

- [ ] **Step 1: Replace the entire file**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _nameCtrl = TextEditingController(text: account?.name ?? '');
    _emailCtrl = TextEditingController(text: account?.email ?? '');
    _phoneCtrl = TextEditingController(text: account?.phone ?? '');
    _bioCtrl = TextEditingController(text: account?.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final fields = <String, dynamic>{};
    final account = context.read<SessionProvider>().account;
    if (_nameCtrl.text.trim() != (account?.name ?? '')) {
      fields['name'] = _nameCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim() != (account?.phone ?? '')) {
      fields['phone'] = _phoneCtrl.text.trim();
    }
    if (_bioCtrl.text.trim() != (account?.bio ?? '')) {
      fields['bio'] = _bioCtrl.text.trim();
    }
    if (fields.isEmpty) {
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
      return;
    }
    final error = await context.read<SessionProvider>().updateProfile(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            Stack(
              children: <Widget>[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.warm,
                    shape: BoxShape.circle,
                    border: Border.all(color: servio.accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      account?.initials ?? 'U',
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(color: ServioColors.deepBrown),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: servio.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              enabled: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            ServioPrimaryButton(
              label: _saving ? 'Saving…' : 'Save Changes',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: servio.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart format**

```bash
cd mobile-app
dart format lib/src/features/customer/edit_profile_screen.dart
```

- [ ] **Step 3: Run flutter analyze**

```bash
cd mobile-app
flutter analyze lib/src/features/customer/edit_profile_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/customer/edit_profile_screen.dart
git commit -m "feat(mobile): wire customer edit profile screen to PATCH /users/me"
```

---

## Task 6: Wire up TechnicianEditProfileScreen

**Files:**
- Modify: `mobile-app/lib/src/features/technician/technician_edit_profile_screen.dart`

- [ ] **Step 1: Replace the entire file**

This screen adds technician-specific fields: hourly rate, service area (locationLabel), skills (comma-separated text field), and availability type (dropdown).

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class TechnicianEditProfileScreen extends StatefulWidget {
  const TechnicianEditProfileScreen({super.key});

  @override
  State<TechnicianEditProfileScreen> createState() => _TechnicianEditProfileScreenState();
}

class _TechnicianEditProfileScreenState extends State<TechnicianEditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _hourlyRateCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _skillsCtrl;
  String _availabilityType = '';
  bool _saving = false;

  static const List<String> _availabilityOptions = ['', 'weekdays', 'weekends', 'both'];
  static const Map<String, String> _availabilityLabels = {
    '': 'Not set',
    'weekdays': 'Weekdays',
    'weekends': 'Weekends',
    'both': 'Weekdays & Weekends',
  };

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _nameCtrl = TextEditingController(text: account?.name ?? '');
    _emailCtrl = TextEditingController(text: account?.email ?? '');
    _phoneCtrl = TextEditingController(text: account?.phone ?? '');
    _bioCtrl = TextEditingController(text: account?.bio ?? '');
    _hourlyRateCtrl = TextEditingController(
      text: account != null && account.hourlyRate > 0
          ? account.hourlyRate.toStringAsFixed(0)
          : '',
    );
    _locationCtrl = TextEditingController(text: account?.locationLabel ?? '');
    _skillsCtrl = TextEditingController(text: account?.skills.join(', ') ?? '');
    _availabilityType = account?.availabilityType ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _locationCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final account = context.read<SessionProvider>().account;
    final fields = <String, dynamic>{};

    if (_nameCtrl.text.trim() != (account?.name ?? '')) {
      fields['name'] = _nameCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim() != (account?.phone ?? '')) {
      fields['phone'] = _phoneCtrl.text.trim();
    }
    if (_bioCtrl.text.trim() != (account?.bio ?? '')) {
      fields['bio'] = _bioCtrl.text.trim();
    }
    if (_locationCtrl.text.trim() != (account?.locationLabel ?? '')) {
      fields['locationLabel'] = _locationCtrl.text.trim();
    }
    if (_availabilityType != (account?.availabilityType ?? '')) {
      fields['availabilityType'] = _availabilityType;
    }
    final rateText = _hourlyRateCtrl.text.trim();
    if (rateText.isNotEmpty) {
      final rate = double.tryParse(rateText);
      if (rate != null && rate != account?.hourlyRate) {
        fields['hourlyRate'] = rate;
      }
    }
    final rawSkills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (rawSkills.join(',') != (account?.skills.join(',') ?? '')) {
      fields['skills'] = rawSkills;
    }

    if (fields.isEmpty) {
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
      return;
    }

    final error = await context.read<SessionProvider>().updateProfile(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: <Widget>[
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      shape: BoxShape.circle,
                      border: Border.all(color: servio.accent, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        account?.initials ?? 'T',
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(color: ServioColors.deepBrown),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: servio.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              enabled: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio / Professional Summary',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hourlyRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hourly Rate (EGP)',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Service Area (e.g. Nasr City)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _skillsCtrl,
              decoration: const InputDecoration(
                labelText: 'Skills (comma-separated)',
                prefixIcon: Icon(Icons.build_outlined),
                hintText: 'e.g. pipe repair, drain cleaning',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _availabilityType,
              decoration: const InputDecoration(
                labelText: 'Availability',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              items: _availabilityOptions
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(_availabilityLabels[v] ?? v),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _availabilityType = v ?? ''),
            ),
            const SizedBox(height: 32),
            ServioPrimaryButton(
              label: _saving ? 'Saving…' : 'Save Changes',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: servio.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart format**

```bash
cd mobile-app
dart format lib/src/features/technician/technician_edit_profile_screen.dart
```

- [ ] **Step 3: Run flutter analyze**

```bash
cd mobile-app
flutter analyze lib/src/features/technician/technician_edit_profile_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile-app/lib/src/features/technician/technician_edit_profile_screen.dart
git commit -m "feat(mobile): wire technician edit profile screen to PATCH /users/me with worker fields"
```

---

## Task 7: Full project analyze and final commit

**Files:** None modified — verification only.

- [ ] **Step 1: Run full flutter analyze**

```bash
cd mobile-app
flutter analyze
```

Expected: `No issues found!` — fix any warnings before continuing.

- [ ] **Step 2: Verify backend still starts cleanly**

```bash
cd backend
node --check src/modules/users/user.routes.js
node --check src/modules/users/user.controller.js
```

Expected: no output.

- [ ] **Step 3: Confirm no website frontend files were changed**

```bash
git diff --name-only HEAD~6 HEAD | grep servio_frontend
```

Expected: no output (no frontend files touched).

---

## Manual Test Steps

1. Start the backend: `cd backend && npm run dev`
2. Launch the Flutter app on Android emulator (or device): `cd mobile-app && flutter run`
3. **Customer flow:**
   - Log in as a customer account
   - Navigate to your profile → Edit Profile
   - Change Name, Phone, Bio → tap Save Changes
   - Verify the loading spinner appears and then the screen closes
   - Open Edit Profile again — confirm Name, Phone, Bio are pre-filled with the new values
   - Open MongoDB Compass → `users` collection → find the document → confirm `name`, `phone`, `bio` fields are updated
   - Log out and log back in → open Edit Profile → confirm values still show
4. **Technician flow:**
   - Log in as a technician account
   - Navigate to your profile → Edit Profile
   - Change Name, Phone, Bio, Hourly Rate, Service Area, Skills, Availability → tap Save Changes
   - Open Edit Profile again — confirm all fields are pre-filled correctly
   - Open MongoDB Compass → confirm `bio`, `hourlyRate`, `locationLabel`, `skills`, `availabilityType` are updated in the document
   - Confirm `role` is still `worker` and `isVerified` / `isActive` are unchanged
5. **Protected fields test:**
   - Use a REST client (Postman) to send `PATCH /api/v1/users/me` with body `{ "role": "admin", "isVerified": true }` and a valid Bearer token
   - Confirm the response succeeds but the document in MongoDB still has the original role and isVerified values (they are not in `allowedFields`)
6. **Validation test:**
   - Send `PATCH /api/v1/users/me` with `{ "hourlyRate": -50 }` → expect HTTP 422 with `{ success: false, errors: [...] }`
   - Send with `{ "availabilityType": "evenings" }` → expect HTTP 422

---

## Endpoints Changed

| Method | Path | Change |
|--------|------|--------|
| `PATCH` | `/api/v1/users/me` | Validation extended; `allowedFields` extended — **existing** endpoint, no breaking change |

## Customer Fields Saved

`name`, `phone`, `bio`

## Technician Fields Saved

`name`, `phone`, `bio`, `hourlyRate`, `locationLabel` (service area), `skills` (array), `availabilityType`

## Protected Fields (ignored silently by allowedFields whitelist)

`_id`, `role`, `password`, `isVerified`, `isActive`, `averageRating`, `totalReviews`, `completedJobs`, `resetPasswordToken`, `resetPasswordExpires`
