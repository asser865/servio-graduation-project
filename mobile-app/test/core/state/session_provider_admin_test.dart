import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a mock HTTP client that always responds with a 200 login payload.
http.Client _loginResponse(Map<String, dynamic> user, {String token = 'tok'}) =>
    MockClient((_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': 'ok',
            'data': {'token': token, 'user': user},
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));

/// Returns a mock HTTP client that always responds with an error.
http.Client _errorResponse(int statusCode, String message) =>
    MockClient((_) async => http.Response(
          jsonEncode({'success': false, 'message': message}),
          statusCode,
          headers: {'content-type': 'application/json'},
        ));

Map<String, dynamic> _userJson({
  String id = 'uid1',
  String name = 'Test User',
  String email = 'test@example.com',
  required String role,
}) =>
    {
      '_id': id,
      'name': name,
      'email': email,
      'phone': '',
      'role': role,
      'isActive': true,
      'isVerified': true,
      'verificationStatus': 'approved',
    };

/// Builds a [SessionProvider] with fresh mock prefs and the given HTTP client.
/// Returns both the provider and the underlying storage for assertions.
Future<({SessionProvider provider, StorageService storage})> _makeProvider(
  http.Client mockHttp,
) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: mockHttp,
    baseUrl: 'http://localhost',
  );
  return (provider: SessionProvider(storage, client), storage: storage);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SessionProvider.login — admin role restriction', () {
    test('returns error and does NOT persist session when role is admin',
        () async {
      final (:provider, :storage) = await _makeProvider(
        _loginResponse(_userJson(role: 'admin')),
      );

      final error = await provider.login('admin@example.com', 'Password1');

      expect(
          error, equals('Admin accounts can only log in through the website.'));
      expect(provider.isLoggedIn, isFalse);
      expect(provider.account, isNull);

      final storedToken =
          await storage.getSecureString(StorageService.keyAuthToken);
      expect(storedToken, isNull);
    });

    test('succeeds and persists session when role is user', () async {
      final (:provider, :storage) = await _makeProvider(
        _loginResponse(_userJson(role: 'user'), token: 'user-token'),
      );

      final error = await provider.login('user@example.com', 'Password1');

      expect(error, isNull);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.account, isNotNull);

      final storedToken =
          await storage.getSecureString(StorageService.keyAuthToken);
      expect(storedToken, equals('user-token'));
    });

    test('succeeds and persists session when role is worker', () async {
      final (:provider, :storage) = await _makeProvider(
        _loginResponse(_userJson(role: 'worker'), token: 'worker-token'),
      );

      final error = await provider.login('worker@example.com', 'Password1');

      expect(error, isNull);
      expect(provider.isLoggedIn, isTrue);

      final storedToken =
          await storage.getSecureString(StorageService.keyAuthToken);
      expect(storedToken, equals('worker-token'));
    });

    test('returns server error message when credentials are wrong', () async {
      final (:provider, :storage) = await _makeProvider(
        _errorResponse(401, 'Invalid email or password.'),
      );

      final error = await provider.login('bad@example.com', 'wrongpass');

      expect(error, equals('Invalid email or password.'));
      expect(provider.isLoggedIn, isFalse);
    });
  });

  group('SessionProvider._loadFromStorage — defensive admin session clear', () {
    test('clears stored session if saved role is admin and stays logged out',
        () async {
      // Simulate an old session stored with role: 'admin'
      SharedPreferences.setMockInitialValues({
        'servio_session': jsonEncode({
          'id': 'admin1',
          'name': 'Admin',
          'email': 'admin@example.com',
          'phone': '',
          'role': 'admin',
          'city': 'Cairo',
          'avatarInitials': '',
          'status': 'active',
          'bio': '',
          'hourlyRate': 0,
          'skills': <String>[],
          'locationLabel': '',
          'yearsExperience': 0,
          'availabilityType': '',
          'availability': <dynamic>[],
          'categories': <String>[],
        }),
        'servio_auth_token': 'old-admin-token',
      });

      final storage = await StorageService.init();
      final client = ApiClient(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://localhost',
      );

      final provider = SessionProvider.load(storage, client);

      expect(provider.isLoggedIn, isFalse);
      expect(provider.account, isNull);
    });

    test('restores session normally when saved role is customer', () async {
      SharedPreferences.setMockInitialValues({
        'servio_session': jsonEncode({
          'id': 'user1',
          'name': 'Regular User',
          'email': 'user@example.com',
          'phone': '',
          'role': 'customer',
          'city': 'Cairo',
          'avatarInitials': '',
          'status': 'active',
          'bio': '',
          'hourlyRate': 0,
          'skills': <String>[],
          'locationLabel': '',
          'yearsExperience': 0,
          'availabilityType': '',
          'availability': <dynamic>[],
          'categories': <String>[],
        }),
      });

      final storage = await StorageService.init();
      final client = ApiClient(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://localhost',
      );

      final provider = SessionProvider.load(storage, client);

      expect(provider.isLoggedIn, isTrue);
      expect(provider.account?.name, equals('Regular User'));
    });

    test('restores session normally when saved role is technician', () async {
      SharedPreferences.setMockInitialValues({
        'servio_session': jsonEncode({
          'id': 'worker1',
          'name': 'Ahmed Plumber',
          'email': 'ahmed@example.com',
          'phone': '',
          'role': 'technician',
          'city': 'Cairo',
          'avatarInitials': '',
          'status': 'active',
          'bio': '',
          'hourlyRate': 150,
          'skills': <String>['plumbing'],
          'locationLabel': 'Nasr City',
          'yearsExperience': 5,
          'availabilityType': 'weekdays',
          'availability': <dynamic>[],
          'categories': <String>['plumbing'],
        }),
      });

      final storage = await StorageService.init();
      final client = ApiClient(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://localhost',
      );

      final provider = SessionProvider.load(storage, client);

      expect(provider.isLoggedIn, isTrue);
      expect(provider.account?.name, equals('Ahmed Plumber'));
    });
  });
}
