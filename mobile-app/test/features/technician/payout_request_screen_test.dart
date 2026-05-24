import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/payments_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/payments_provider.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/servio_tokens.dart';
import 'package:servio_mobile_app/src/features/technician/payout_request_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows error when amount is below minimum', (tester) async {
    await tester.pumpWidget(await _wrap());

    // Enter amount below minimum
    await tester.enterText(find.byType(TextField).first, '30');
    await tester.tap(find.text('Submit Request'));
    await tester.pump();

    expect(find.text('Minimum payout is EGP 50.0.'), findsOneWidget);
  });

  testWidgets('shows phone field for Vodafone Cash method', (tester) async {
    await tester.pumpWidget(await _wrap());

    // Vodafone Cash is the default — phone field should be visible
    expect(find.text('Vodafone Cash Number'), findsOneWidget);

    // Switch to Bank Transfer
    await tester.tap(find.text('Bank Transfer'));
    await tester.pump();

    expect(find.text('IBAN'), findsOneWidget);
    expect(find.text('Account Holder Name'), findsOneWidget);
  });

  testWidgets('shows InstaPay Number field when InstaPay is selected',
      (tester) async {
    await tester.pumpWidget(await _wrap());

    await tester.tap(find.text('InstaPay'));
    await tester.pump();

    expect(find.text('InstaPay Number'), findsOneWidget);
  });

  testWidgets('shows wallet error when phone is empty for non-bank method',
      (tester) async {
    await tester.pumpWidget(await _wrap());

    // Enter valid amount but leave phone empty (Vodafone Cash default)
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.text('Submit Request'));
    await tester.pump();

    expect(
      find.text('Enter your wallet / InstaPay number.'),
      findsOneWidget,
    );
  });

  testWidgets('shows bank field errors when bank fields are empty',
      (tester) async {
    await tester.pumpWidget(await _wrap());

    // Switch to Bank Transfer
    await tester.tap(find.text('Bank Transfer'));
    await tester.pump();

    // Enter valid amount but leave IBAN empty
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.text('Submit Request'));
    await tester.pump();

    expect(find.text('Enter IBAN.'), findsOneWidget);
  });

  testWidgets('renders AppBar with correct title', (tester) async {
    await tester.pumpWidget(await _wrap());

    expect(find.text('Request Payout'), findsOneWidget);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<Widget> _wrap() async {
  final storage = await StorageService.init();

  // MockClient that rejects payout requests (we only test UI validation here).
  final httpClient = MockClient((http.Request request) async {
    return http.Response(
      jsonEncode(<String, Object?>{
        'success': false,
        'message': 'Stub — not implemented in test',
      }),
      422,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });

  final apiClient = ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
  );

  final paymentsProvider = PaymentsProvider(PaymentsApi(apiClient));

  return ChangeNotifierProvider<PaymentsProvider>.value(
    value: paymentsProvider,
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          ServioThemeExtension(
            backgroundSoft: Color(0xFFF5F5F5),
            surfaceAlt: Color(0xFFEEEEEE),
            surfaceRaised: Color(0xFFFFFFFF),
            textSecondary: Color(0xFF888888),
            border: Color(0xFFDDDDDD),
            accent: ServioColors.accent,
            accentLight: ServioColors.accentLight,
            neutralWarm: ServioColors.neutralWarm,
            success: ServioColors.success,
            warning: ServioColors.warning,
            info: ServioColors.info,
            danger: ServioColors.danger,
          ),
        ],
      ),
      home: const PayoutRequestScreen(),
    ),
  );
}
