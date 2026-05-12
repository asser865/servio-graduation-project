import 'dart:async';
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
import 'package:servio_mobile_app/src/features/customer/my_addresses_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows loading state while fetching addresses', (tester) async {
    final completer = Completer<http.Response>();
    final widget = await _wrapWithBackend(
      const MyAddressesScreen(),
      MockClient((_) => completer.future),
      timeout: null,
    );

    await tester.pumpWidget(widget);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty saved address list', (tester) async {
    final backend = _AddressBackend(<Map<String, dynamic>>[]);

    await tester.pumpWidget(
      await _wrapWithBackend(const MyAddressesScreen(), backend.client()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved addresses yet.'), findsOneWidget);
  });

  testWidgets('shows error and retries successfully', (tester) async {
    final backend = _AddressBackend(
      <Map<String, dynamic>>[_address(id: 'addr1', street: '12 Nile St')],
      failFirstGet: true,
    );

    await tester.pumpWidget(
      await _wrapWithBackend(const MyAddressesScreen(), backend.client()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend down'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('12 Nile St'), findsOneWidget);
  });

  testWidgets('adds address successfully', (tester) async {
    final backend = _AddressBackend(<Map<String, dynamic>>[]);

    await tester.pumpWidget(
      await _wrapWithBackend(const MyAddressesScreen(), backend.client()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add New Address'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('address-label-field')),
      'Home',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-street-field')),
      '45 Garden St',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-city-field')),
      'Cairo',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-state-field')),
      'Maadi',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('address-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('45 Garden St'), findsOneWidget);
    expect(backend.addresses, hasLength(1));
  });

  testWidgets('validates empty street before add', (tester) async {
    final backend = _AddressBackend(<Map<String, dynamic>>[]);

    await tester.pumpWidget(
      await _wrapWithBackend(const MyAddressesScreen(), backend.client()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add New Address'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('address-save-button')));
    await tester.pump();

    expect(find.text('Street address is required'), findsOneWidget);
    expect(backend.addresses, isEmpty);
  });

  testWidgets('edits address successfully', (tester) async {
    final backend = _AddressBackend(
      <Map<String, dynamic>>[_address(id: 'addr1', street: 'Old St')],
    );

    await tester.pumpWidget(
      await _wrapWithBackend(const MyAddressesScreen(), backend.client()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('edit-address-addr1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('address-street-field')),
      'Updated St',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('address-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('address-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Updated St'), findsOneWidget);
    expect(backend.addresses.single['street'], 'Updated St');
  });

  testWidgets('deletes address successfully', (tester) async {
    final backend = _AddressBackend(
      <Map<String, dynamic>>[_address(id: 'addr1', street: 'Delete St')],
    );

    await tester.pumpWidget(
      await _wrapWithBackend(const MyAddressesScreen(), backend.client()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('delete-address-addr1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-address-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved addresses yet.'), findsOneWidget);
    expect(backend.addresses, isEmpty);
  });
}

Future<Widget> _wrapWithBackend(
  Widget child,
  http.Client httpClient, {
  Duration? timeout = const Duration(seconds: 20),
}) async {
  final storage = await StorageService.init();
  final apiClient = ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
    timeout: timeout,
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

class _AddressBackend {
  _AddressBackend(
    List<Map<String, dynamic>> initial, {
    this.failFirstGet = false,
  }) : addresses = List<Map<String, dynamic>>.from(initial);

  final List<Map<String, dynamic>> addresses;
  final bool failFirstGet;
  int _getCount = 0;
  int _nextId = 100;

  http.Client client() => MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/users/me') {
          _getCount++;
          if (failFirstGet && _getCount == 1) {
            return _json(<String, dynamic>{
              'success': false,
              'message': 'Backend down',
            }, statusCode: 500);
          }
          return _json(<String, dynamic>{
            'success': true,
            'data': {'addresses': addresses},
          });
        }

        if (request.method == 'POST' &&
            request.url.path == '/users/me/addresses') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final created = <String, dynamic>{
            '_id': 'addr${_nextId++}',
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

        if (request.method == 'PATCH' &&
            request.url.path.startsWith('/users/me/addresses/')) {
          final id = request.url.pathSegments.last;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final index = addresses.indexWhere((a) => a['_id'] == id);
          if (index == -1) {
            return _json(<String, dynamic>{
              'success': false,
              'message': 'Address not found.',
            }, statusCode: 404);
          }
          addresses[index] = <String, dynamic>{
            ...addresses[index],
            ...body,
          };
          return _json(<String, dynamic>{
            'success': true,
            'data': addresses[index],
          });
        }

        if (request.method == 'DELETE' &&
            request.url.path.startsWith('/users/me/addresses/')) {
          final id = request.url.pathSegments.last;
          addresses.removeWhere((a) => a['_id'] == id);
          return _json(<String, dynamic>{'success': true});
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
