import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../api/bookings_api.dart';
import '../api/token_storage.dart';
import '../api/users_api.dart';
import '../models/booking_model.dart';
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
  SessionProvider(
    StorageService storage,
    this._apiClient, {
    TokenStorage? tokenStorage,
  })  : _storage = storage,
        _tokenStorage = tokenStorage ?? StorageBackedTokenStorage(storage);

  final StorageService _storage;
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  late final AuthApi _authApi = AuthApi(_apiClient);
  late final UsersApi _usersApi = UsersApi(_apiClient);

  UserAccount? _account;

  UserAccount? get account => _account;
  bool get isLoggedIn => _account != null;

  String get savedEmail => _storage.getString(_kKeyRememberEmail) ?? '';

  void _loadFromStorage() {
    final json = _storage.getJson(_kKeySession);
    if (json == null) return;
    // Defensive guard: clear any previously-saved session whose stored role is
    // 'admin'. This can happen if an older version of the app persisted an admin
    // session before the login block was in place.
    if (json['role'] == 'admin') {
      _storage.remove(_kKeySession);
      _storage.remove(_kKeyAccount);
      unawaited(_tokenStorage.clearToken());
      return;
    }
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
      await _tokenStorage.saveToken(session.token);
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
      await _tokenStorage.saveToken(session.token);
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
      await _tokenStorage.saveToken(session.token);
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
      await _refreshAccount();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save profile. Check your connection.';
    }
  }

  Future<String?> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      await _usersApi.updateEmail(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );
      await logout();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update email. Check your connection.';
    }
  }

  Future<String?> loadCurrentWorkerProfile() async {
    try {
      await _refreshAccount();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not load profile. Check your connection.';
    }
  }

  Future<String?> updateWorkerAvailability(
    List<AvailabilitySlot> availability,
  ) async {
    try {
      final updated = await _usersApi.updateAvailability(availability);
      await _setAccount(updated);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save availability. Check your connection.';
    }
  }

  Future<String?> updateAvailability(
    List<Map<String, dynamic>> availability,
  ) {
    return updateWorkerAvailability(
      availability.map(AvailabilitySlot.fromJson).toList(),
    );
  }

  Future<String?> toggleBlockedDate(String date) async {
    try {
      final updated = await _usersApi.toggleBlockedDate(date);
      await _setAccount(_account!.copyWith(blockedDates: updated));
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update blocked dates. Check your connection.';
    }
  }

  Future<String?> toggleAvailableNow(bool value) async {
    try {
      await _usersApi.updateAvailableNow(value);
      await _refreshAccount();
      if (_account != null && _account!.isAvailable != value) {
        await _setAccount(_account!.copyWith(isAvailable: value));
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update availability. Check your connection.';
    }
  }

  Future<void> _refreshAccount() async {
    final refreshed = await _usersApi.getMe();
    await _setAccount(refreshed);
  }

  Future<void> _setAccount(UserAccount account) async {
    _account = account;
    await _storage.setJson(_kKeySession, account.toJson());
    await _storage.setJson(_kKeyAccount, account.toJson());
    notifyListeners();
  }

  Future<void> logout() async {
    _account = null;
    await _storage.remove(_kKeySession);
    await _storage.remove(_kKeyAccount);
    await _tokenStorage.clearToken();
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    try {
      await _usersApi.deleteMe();
      await logout();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not delete account. Check your connection.';
    }
  }

  static SessionProvider load(
    StorageService storage,
    ApiClient apiClient, {
    TokenStorage? tokenStorage,
  }) {
    final provider = SessionProvider(
      storage,
      apiClient,
      tokenStorage: tokenStorage,
    );
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
  BookingsProvider(this._storage, this._api) {
    _loadCached();
    refresh();
  }

  final StorageService _storage;
  final BookingsApi _api;
  final List<BookingModel> _bookings = <BookingModel>[];
  bool _loading = false;

  List<BookingModel> get all => List<BookingModel>.unmodifiable(_bookings);
  bool get isLoading => _loading;

  List<BookingModel> get upcoming =>
      _bookings.where((b) => b.status.isActive).toList();

  List<BookingModel> get past =>
      _bookings.where((b) => b.status.isPast).toList();

  void _loadCached() {
    final list = _storage.getJsonList(_kKeyBookings);
    _bookings.addAll(list.map(BookingModel.fromJson));
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final raw = await _api.getMyBookings();
      _bookings
        ..clear()
        ..addAll(raw.map(BookingModel.fromBackend));
      await _save();
    } catch (_) {
      // keep cached data on error
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    await _storage.setJsonList(
      _kKeyBookings,
      _bookings.map((b) => b.toJson()).toList(),
    );
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
  MessagesProvider();

  int _totalUnread = 0;

  int get totalUnread => _totalUnread;

  void setTotalUnread(int value) {
    if (_totalUnread == value) return;
    _totalUnread = value;
    notifyListeners();
  }
}
