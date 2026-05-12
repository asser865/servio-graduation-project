import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/api_exception.dart';
import 'package:servio_mobile_app/src/core/api/users_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fetches saved addresses with bearer auth', () async {
    String? authHeader;
    final env = await _buildApi(MockClient((request) async {
      authHeader = request.headers['Authorization'];
      expect(request.method, 'GET');
      expect(request.url.path, '/users/me');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'data': {
          'addresses': [_addressJson(id: 'addr1', street: '12 Nile St')],
        },
      });
    }), token: 'token-123');

    final addresses = await env.api.getSavedAddresses();

    expect(authHeader, 'Bearer token-123');
    expect(addresses, hasLength(1));
    expect(addresses.single.id, 'addr1');
    expect(addresses.single.street, '12 Nile St');
  });

  test('returns empty saved address list', () async {
    final env = await _buildApi(MockClient((_) async {
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'data': {'addresses': <dynamic>[]},
      });
    }));

    expect(await env.api.getSavedAddresses(), isEmpty);
  });

  test('adds address successfully', () async {
    Map<String, dynamic>? payload;
    final env = await _buildApi(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/users/me/addresses');
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'data': _addressJson(id: 'addr2', street: payload!['street'] as String),
      }, statusCode: 201);
    }));

    final address = await env.api.addAddress(
      label: 'Home',
      street: '34 Tahrir St',
      city: 'Cairo',
      state: 'Downtown',
    );

    expect(payload, containsPair('label', 'Home'));
    expect(payload, containsPair('street', '34 Tahrir St'));
    expect(address.id, 'addr2');
    expect(address.city, 'Cairo');
  });

  test('updates address successfully', () async {
    final env = await _buildApi(MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/users/me/addresses/addr1');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'data': _addressJson(id: 'addr1', street: 'Updated St'),
      });
    }));

    final address = await env.api.updateAddress(
      'addr1',
      label: 'Office',
      street: 'Updated St',
    );

    expect(address.id, 'addr1');
    expect(address.street, 'Updated St');
  });

  test('deletes address successfully', () async {
    final env = await _buildApi(MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/users/me/addresses/addr1');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'message': 'Address deleted.',
      });
    }));

    await env.api.deleteAddress('addr1');
  });

  test('surfaces backend validation failure', () async {
    final env = await _buildApi(MockClient((_) async {
      return _jsonResponse(<String, dynamic>{
        'success': false,
        'message': 'Street is required.',
      }, statusCode: 400);
    }));

    await expectLater(
      env.api.addAddress(street: ''),
      throwsA(isA<ApiException>().having(
        (e) => e.message,
        'message',
        'Street is required.',
      )),
    );
  });

  test('surfaces server error', () async {
    final env = await _buildApi(MockClient((_) async {
      return _jsonResponse(<String, dynamic>{
        'success': false,
        'message': 'Database unavailable.',
      }, statusCode: 500);
    }));

    await expectLater(
      env.api.getSavedAddresses(),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        500,
      )),
    );
  });

  test('clears token on unauthorized response', () async {
    final env = await _buildApi(MockClient((_) async {
      return _jsonResponse(<String, dynamic>{
        'success': false,
        'message': 'Unauthorized',
      }, statusCode: 401);
    }), token: 'expired-token');

    await expectLater(
      env.api.getSavedAddresses(),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        401,
      )),
    );
    expect(
      await env.storage.getSecureString(StorageService.keyAuthToken),
      isNull,
    );
  });
}

Future<({UsersApi api, StorageService storage})> _buildApi(
  http.Client httpClient, {
  String? token,
}) async {
  final storage = await StorageService.init();
  if (token != null) {
    await storage.setSecureString(StorageService.keyAuthToken, token);
  }
  final client = ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
  );
  return (api: UsersApi(client), storage: storage);
}

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _addressJson({
  required String id,
  required String street,
}) =>
    <String, dynamic>{
      '_id': id,
      'label': 'Home',
      'street': street,
      'city': 'Cairo',
      'state': 'Maadi',
      'zipCode': '11728',
    };
