import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/auth_api.dart';
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
