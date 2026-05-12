import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/customer/my_bookings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('history tab displays active and completed bookings from backend',
      (tester) async {
    await tester.pumpWidget(await _wrap(const MyBookingsScreen(
      initialTabIndex: 1,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Drain Cleaning'), findsOneWidget);
    expect(find.text('Kitchen Painting'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });
}

Future<Widget> _wrap(Widget child) async {
  final storage = await StorageService.init();
  final apiClient = ApiClient(
    storage: storage,
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'bookings': <Map<String, dynamic>>[
              _booking(
                id: '665000000000000000000010',
                status: 'pending',
                serviceName: 'Drain Cleaning',
              ),
              _booking(
                id: '665000000000000000000011',
                status: 'completed',
                serviceName: 'Kitchen Painting',
              ),
            ],
          },
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
    baseUrl: 'http://localhost',
  );

  return Provider<ApiClient>.value(
    value: apiClient,
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

Map<String, dynamic> _booking({
  required String id,
  required String status,
  required String serviceName,
}) {
  return <String, dynamic>{
    '_id': id,
    'status': status,
    'scheduledDate': '2026-05-11T00:00:00.000Z',
    'scheduledTime': '10:00',
    'totalPrice': 350,
    'address': '12 Nile St, Cairo',
    'pin': '4821',
    'paymentMethod': 'cash',
    'worker': <String, dynamic>{
      '_id': '664000000000000000000001',
      'name': 'Ahmed Nabil',
    },
    'service': <String, dynamic>{
      '_id': '664000000000000000000002',
      'title': serviceName,
      'category': 'plumbing',
    },
  };
}
