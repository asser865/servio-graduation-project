import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/models/user_account.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/technician/technician_pricing_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _seedAccount = UserAccount(
  id: 'w1',
  name: 'Ali',
  email: 'ali@test.com',
  phone: '01012345678',
  role: UserRole.technician,
  minFee: 50,
  travelFee: 20,
  emergencyMultiplier: 1.5,
  acceptCash: true,
  acceptCard: false,
  acceptInstapay: true,
  acceptWallet: false,
);

Future<ApiClient> _buildClient(http.Client httpClient) async {
  final storage = await StorageService.init();
  return ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
  );
}

http.Client _defaultMockHttp() => MockClient((request) async {
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
              'minFee': 50,
              'travelFee': 20,
              'emergencyMultiplier': 1.5,
              'acceptCash': true,
              'acceptCard': false,
              'acceptInstapay': true,
              'acceptWallet': false,
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
              'minFee': 50,
              'travelFee': 20,
              'emergencyMultiplier': 1.5,
              'acceptCash': true,
              'acceptCard': false,
              'acceptInstapay': true,
              'acceptWallet': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

Future<Widget> _wrap(Widget child, {http.Client? httpClient}) async {
  final client = await _buildClient(httpClient ?? _defaultMockHttp());
  final storage = await StorageService.init();

  return ChangeNotifierProvider<SessionProvider>(
    create: (_) => SessionProvider.load(storage, client),
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
      'servio_session': jsonEncode(_seedAccount.toJson()),
    });
  });

  testWidgets('shows Pricing screen title', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    expect(find.text('Pricing & Payments'), findsOneWidget);
  });

  testWidgets('pre-populates minFee from account', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
  });

  testWidgets('pre-populates travelFee from account', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    expect(find.widgetWithText(TextFormField, '20'), findsOneWidget);
  });

  testWidgets('pre-populates emergencyMultiplier from account', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    expect(find.widgetWithText(TextFormField, '1.5'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows all 4 payment method switches', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Credit / Debit Card'), findsOneWidget);
    expect(find.text('Instapay'), findsOneWidget);
    expect(find.text('Mobile Wallet'), findsOneWidget);
  });

  testWidgets('shows Save Pricing button', (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    expect(find.text('Save Pricing'), findsOneWidget);
  });

  testWidgets('shows validation error when emergencyMultiplier > 5',
      (tester) async {
    await tester.pumpWidget(await _wrap(const TechnicianPricingScreen()));
    final multField = find.widgetWithText(TextFormField, '1.5').first;
    await tester.enterText(multField, '6');
    await tester.ensureVisible(find.text('Save Pricing'));
    await tester.tap(find.text('Save Pricing'));
    await tester.pump();
    expect(find.text('Must be between 1.0 and 5.0'), findsOneWidget);
  });
}
