import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/saved_cards_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fetches saved cards from backend', () async {
    final api = await _api((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/saved-cards');
      return _json(<String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[
          _card(id: 'card1', isDefault: true),
        ],
      });
    });

    final cards = await api.getSavedCards();

    expect(cards, hasLength(1));
    expect(cards.first.id, 'card1');
    expect(cards.first.displayLabel, contains('4242'));
    expect(cards.first.isDefault, isTrue);
  });

  test('creates a saved card through backend', () async {
    Map<String, dynamic>? payload;
    final api = await _api((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(<String, dynamic>{
        'success': true,
        'data': _card(id: 'card2'),
      }, statusCode: 201);
    });

    final card = await api.addCard(
      last4: '4242',
      expiry: '12/30',
      cardType: 'visa',
      label: 'Personal',
    );

    expect(payload?['last4'], '4242');
    expect(payload?['expiry'], '12/30');
    expect(card.id, 'card2');
  });
}

Future<SavedCardsApi> _api(
  Future<http.Response> Function(http.Request request) handler,
) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((request) => handler(request)),
    baseUrl: 'http://localhost',
  );
  return SavedCardsApi(client);
}

Map<String, dynamic> _card({
  required String id,
  bool isDefault = false,
}) {
  return <String, dynamic>{
    '_id': id,
    'last4': '4242',
    'expiry': '12/30',
    'cardType': 'visa',
    'label': 'Personal',
    'isDefault': isDefault,
  };
}

http.Response _json(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
