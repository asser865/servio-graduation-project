import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/models/user_account.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/core/state/services_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/technician/technician_services_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Services returned by the mock API.
final _mockServices = [
  <String, dynamic>{
    '_id': 'svc1',
    'title': 'Pipe Repair',
    'category': 'plumbing',
    'description': 'Fix pipes',
    'basePrice': 100,
    'priceUnit': 'per_hour',
    'isActive': true,
  },
  <String, dynamic>{
    '_id': 'svc2',
    'title': 'Wiring',
    'category': 'electrical',
    'description': 'Wiring work',
    'basePrice': 80,
    'priceUnit': 'per_hour',
    'isActive': true,
  },
];

/// Builds an [ApiClient] backed by SharedPreferences mock + [httpClient].
Future<ApiClient> _buildClient(http.Client httpClient) async {
  final storage = await StorageService.init();
  return ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
  );
}

/// A [MockClient] that returns [_mockServices] for GET /services and
/// accepts PATCH /users/me without error.
http.Client _defaultMockHttp() => MockClient((request) async {
      if (request.url.path == '/services') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'services': _mockServices},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PATCH' && request.url.path == '/users/me') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': 'w1',
              'name': 'Ali',
              'email': 'ali@test.com',
              'phone': '01012345678',
              'role': 'technician',
              'categories': ['plumbing'],
              'pendingCategories': ['electrical'],
              'serviceIds': ['svc1'],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET' && request.url.path == '/users/me') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': 'w1',
              'name': 'Ali',
              'email': 'ali@test.com',
              'phone': '01012345678',
              'role': 'technician',
              'categories': ['plumbing'],
              'pendingCategories': ['electrical'],
              'serviceIds': ['svc1'],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

/// Wraps [child] in the providers the screen needs.
Future<Widget> _wrap(
  Widget child, {
  http.Client? httpClient,
}) async {
  final client = await _buildClient(httpClient ?? _defaultMockHttp());
  final storage = await StorageService.init();

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider.load(storage, client),
      ),
      ChangeNotifierProvider<ServicesProvider>(
        create: (_) => ServicesProvider(client),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'servio_session': jsonEncode(
        const UserAccount(
          id: 'w1',
          name: 'Ali',
          email: 'ali@test.com',
          phone: '01012345678',
          role: UserRole.technician,
          categories: ['plumbing'],
          pendingCategories: ['electrical'],
          serviceIds: ['svc1'],
        ).toJson(),
      ),
    });
  });

  testWidgets('shows services page title', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianServicesScreen()));
    expect(find.text('My Services'), findsOneWidget);
  });

  testWidgets('renders category sections for loaded services', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianServicesScreen()));
    // pump once for postFrameCallback fetchAll, then settle for async response
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
  });

  testWidgets('shows Verified badge for verified categories', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianServicesScreen()));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('shows Pending badge for pending categories', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianServicesScreen()));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('shows Save button', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianServicesScreen()));
    expect(find.text('Save Services'), findsOneWidget);
  });

  testWidgets('shows Certifications field', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianServicesScreen()));
    expect(find.text('Certifications'), findsOneWidget);
  });
}
