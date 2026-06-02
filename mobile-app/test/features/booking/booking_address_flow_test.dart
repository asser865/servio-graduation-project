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
import 'package:servio_mobile_app/src/core/api/payments_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/customer_addresses_state.dart';
import 'package:servio_mobile_app/src/core/state/payments_provider.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/booking/booking_flow_data.dart';
import 'package:servio_mobile_app/src/features/booking/booking_step_two_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('booking uses saved address from backend', (tester) async {
    final backend = _AddressBackend(<Map<String, dynamic>>[
      _address(id: 'home', street: '12 Nile St'),
    ]);

    await tester.pumpWidget(
      await _wrap(BookingStepTwoScreen(data: const BookingFlowData()),
          backend.client()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('12 Nile St'), findsOneWidget);

    await _tapVisible(tester, find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.textContaining('12 Nile St'), findsWidgets);
  });

  testWidgets('new booking address persists and appears after refetch',
      (tester) async {
    final backend = _AddressBackend(<Map<String, dynamic>>[]);

    await tester.pumpWidget(
      await _wrap(BookingStepTwoScreen(data: const BookingFlowData()),
          backend.client()),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('booking-add-address-button')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-label-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-label-field')),
      'Studio',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-street-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-street-field')),
      'Villa 9',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-city-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-city-field')),
      'Cairo',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-state-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-state-field')),
      'New Cairo',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('address-save-button')));
    await tester.pumpAndSettle();

    expect(backend.addresses, hasLength(1));
    expect(find.textContaining('Villa 9'), findsOneWidget);

    await _tapVisible(tester, find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.textContaining('Villa 9'), findsWidgets);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<Widget> _wrap(Widget child, http.Client httpClient) async {
  final storage = await StorageService.init();
  final apiClient = ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
  );
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<CustomerAddressesProvider>(
        create: (_) => CustomerAddressesProvider(UsersApi(apiClient)),
      ),
      ChangeNotifierProvider<PaymentsProvider>(
        create: (_) => PaymentsProvider(PaymentsApi(apiClient)),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

class _AddressBackend {
  _AddressBackend(this.addresses);

  final List<Map<String, dynamic>> addresses;
  int _nextId = 1;

  http.Client client() => MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/users/me') {
          return _json(<String, dynamic>{
            'success': true,
            'data': {'addresses': addresses},
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/users/me/addresses') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final created = <String, dynamic>{
            '_id': 'new-${_nextId++}',
            'label': body['label'] ?? '',
            'street': body['street'] ?? '',
            'city': body['city'] ?? '',
            'state': body['state'] ?? '',
            'zipCode': body['zipCode'] ?? '',
          };
          addresses.add(created);
          return _json(<String, dynamic>{
            'success': true,
            'data': created,
          }, statusCode: 201);
        }
        return _json(<String, dynamic>{
          'success': false,
          'message': 'not found',
        }, statusCode: 404);
      });
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

Map<String, dynamic> _address({
  required String id,
  required String street,
}) =>
    <String, dynamic>{
      '_id': id,
      'label': 'Home',
      'street': street,
      'city': 'Cairo',
      'state': 'Maadi',
      'zipCode': '',
    };
