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
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/servio_tokens.dart';
import 'package:servio_mobile_app/src/features/auth/login_screen.dart';

Future<Widget> _build({
  Brightness brightness = Brightness.light,
  http.Client? httpClient,
}) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: httpClient ??
        MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, Object?>{'success': false, 'message': 'mock'}),
            401,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
    baseUrl: 'http://localhost',
  );
  return ChangeNotifierProvider<SessionProvider>(
    create: (_) => SessionProvider(storage, client),
    child: MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          ServioThemeExtension(
            backgroundSoft: Color(0xFF2C2C2C),
            surfaceAlt: Color(0xFF3C3C3C),
            surfaceRaised: Color(0xFF4C4C4C),
            textSecondary: Color(0xFF888888),
            border: Color(0xFF555555),
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
      home: const LoginScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginScreen redesign', () {
    testWidgets('shows SERVIO header and welcome copy', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.text('SERVIO'), findsOneWidget);
      expect(
        find.text('Welcome back. Enter your details to access your sanctuary.'),
        findsOneWidget,
      );
    });

    testWidgets('has email and password fields', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('has login and social buttons', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('shows validation before backend call', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(
        find.text('Please enter your email and password.'),
        findsOneWidget,
      );
    });

    testWidgets('valid credentials submit through backend API path',
        (tester) async {
      var requestedLogin = false;
      await tester.pumpWidget(
        await _build(
          httpClient: MockClient((http.Request request) async {
            requestedLogin =
                request.method == 'POST' && request.url.path.endsWith('/login');
            return http.Response(
              jsonEncode(<String, Object?>{
                'success': false,
                'message': 'Invalid email or password.',
              }),
              401,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'customer@example.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(requestedLogin, isTrue);
    });
  });
}
