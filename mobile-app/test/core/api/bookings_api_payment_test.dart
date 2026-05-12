import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/bookings_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('createBooking sends cash payment payload and reads backend PIN',
      () async {
    Map<String, dynamic>? payload;
    final api = await _api((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _bookingResponse(paymentMethod: 'cash');
    });

    final booking = await api.createBooking(
      workerId: '664000000000000000000001',
      serviceId: '664000000000000000000002',
      scheduledDate: DateTime(2026, 5, 11),
      scheduledTime: '10:00 AM - 11:00 AM',
      address: '12 Nile St, Cairo',
      paymentMethod: 'cash',
    );

    expect(payload?['workerId'], '664000000000000000000001');
    expect(payload?['serviceId'], '664000000000000000000002');
    expect(payload?['paymentMethod'], 'cash');
    expect(payload?.containsKey('savedCardId'), isFalse);
    expect(booking.pin, '4821');
    expect(booking.paymentMethod, 'cash');
  });

  test('createBooking sends selected saved card for card payments', () async {
    Map<String, dynamic>? payload;
    final api = await _api((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _bookingResponse(paymentMethod: 'card');
    });

    final booking = await api.createBooking(
      workerId: '664000000000000000000001',
      serviceId: '664000000000000000000002',
      scheduledDate: DateTime(2026, 5, 11),
      scheduledTime: '14:00',
      address: '12 Nile St, Cairo',
      paymentMethod: 'card',
      savedCardId: '664000000000000000000003',
    );

    expect(payload?['paymentMethod'], 'card');
    expect(payload?['savedCardId'], '664000000000000000000003');
    expect(booking.paymentMethod, 'card');
    expect(booking.paymentCardLast4, '4242');
  });
}

Future<BookingsApi> _api(
  Future<http.Response> Function(http.Request request) handler,
) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((request) => handler(request)),
    baseUrl: 'http://localhost',
  );
  return BookingsApi(client);
}

http.Response _bookingResponse({required String paymentMethod}) {
  return http.Response(
    jsonEncode(<String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        '_id': '665000000000000000000010',
        'status': 'pending',
        'scheduledDate': '2026-05-11T00:00:00.000Z',
        'scheduledTime': '10:00',
        'totalPrice': 350,
        'address': '12 Nile St, Cairo',
        'pin': '4821',
        'paymentMethod': paymentMethod,
        'paymentMeta': <String, dynamic>{
          'last4': paymentMethod == 'card' ? '4242' : '',
          'cardType': paymentMethod == 'card' ? 'visa' : '',
          'label': paymentMethod == 'card' ? 'Personal' : '',
        },
        'worker': <String, dynamic>{
          '_id': '664000000000000000000001',
          'name': 'Ahmed Nabil',
        },
        'service': <String, dynamic>{
          '_id': '664000000000000000000002',
          'title': 'Drain Cleaning',
          'category': 'plumbing',
        },
      },
    }),
    201,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
