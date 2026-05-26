import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/features/auth/forgot_password_screen.dart';

Future<Widget> _build({http.Client? httpClient}) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: httpClient ??
        MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, Object?>{'success': true}),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
    baseUrl: 'http://localhost',
  );

  return ChangeNotifierProvider<SessionProvider>(
    create: (_) => SessionProvider(storage, client),
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const ForgotPasswordScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ForgotPasswordScreen', () {
    testWidgets('shows reset password form', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('validates empty email before backend call', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Please enter your email address.'), findsOneWidget);
    });

    testWidgets('validates malformed email before backend call',
        (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bad-email');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('valid email submits to forgot-password API path',
        (tester) async {
      var requestedForgotPassword = false;

      await tester.pumpWidget(
        await _build(
          httpClient: MockClient((http.Request request) async {
            requestedForgotPassword = request.method == 'POST' &&
                request.url.path.endsWith('/auth/forgot-password');
            return http.Response(
              jsonEncode(<String, Object?>{'success': true}),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'customer@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(requestedForgotPassword, isTrue);
    });
  });
}
