import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/users_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/customer_addresses_state.dart';
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

  testWidgets('re-book opens booking flow with previous service and technician',
      (tester) async {
    await tester.pumpWidget(await _wrap(const MyBookingsScreen(
      initialTabIndex: 1,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-book'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Your Booking'), findsOneWidget);
    expect(find.text('Kitchen Painting'), findsWidgets);
    expect(find.text('Ahmed Nabil'), findsOneWidget);
  });

  testWidgets('re-book keeps technician availability for date selection',
      (tester) async {
    await tester.pumpWidget(await _wrap(const MyBookingsScreen(
      initialTabIndex: 1,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-book'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a Date & Time'), findsOneWidget);
    expect(
      find.text('Technician is not available on this day'),
      findsNothing,
    );
    expect(find.text('9:00 AM - 10:00 AM'), findsOneWidget);
  });
}

Future<Widget> _wrap(Widget child) async {
  final storage = await StorageService.init();
  final apiClient = ApiClient(
    storage: storage,
    httpClient: MockClient((request) async {
      if (request.url.path == '/users/me') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'addresses': <Map<String, dynamic>>[
                <String, dynamic>{
                  '_id': 'addr1',
                  'label': 'Home',
                  'street': '12 Nile St',
                  'city': 'Cairo',
                  'state': 'Maadi',
                },
              ],
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
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

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<CustomerAddressesProvider>(
        create: (_) => CustomerAddressesProvider(UsersApi(apiClient)),
      ),
    ],
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
      'availability': <Map<String, dynamic>>[
        <String, dynamic>{'day': 'friday', 'from': '09:00', 'to': '17:00'},
        <String, dynamic>{'day': 'saturday', 'from': '09:00', 'to': '17:00'},
        <String, dynamic>{'day': 'sunday', 'from': '09:00', 'to': '17:00'},
        <String, dynamic>{'day': 'monday', 'from': '09:00', 'to': '17:00'},
        <String, dynamic>{'day': 'tuesday', 'from': '09:00', 'to': '17:00'},
        <String, dynamic>{'day': 'wednesday', 'from': '09:00', 'to': '17:00'},
        <String, dynamic>{'day': 'thursday', 'from': '09:00', 'to': '17:00'},
      ],
    },
    'service': <String, dynamic>{
      '_id': '664000000000000000000002',
      'title': serviceName,
      'category': 'plumbing',
    },
  };
}
