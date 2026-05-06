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
import 'package:servio_mobile_app/src/features/auth/widgets/auth_background.dart';
import 'package:servio_mobile_app/src/features/auth/widgets/auth_card.dart';

Future<Widget> _build({Brightness brightness = Brightness.dark}) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((http.Request request) async {
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
    testWidgets('shows Welcome back heading', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome back'), findsOneWidget);
    });

    testWidgets('uses AuthBackground', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });

    testWidgets('uses AuthCard for form', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthCard), findsOneWidget);
    });

    testWidgets('has email and password fields', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('has Log In button', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();
      expect(find.text('Log In'), findsOneWidget);
    });
  });
}
