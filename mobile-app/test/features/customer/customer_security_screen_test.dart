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
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/customer/customer_security_screen.dart';
import 'package:servio_mobile_app/src/features/customer/change_password_screen.dart';

Future<Widget> _build({
  required SessionProvider sessionProvider,
}) async {
  return ChangeNotifierProvider<SessionProvider>.value(
    value: sessionProvider,
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: const CustomerSecurityScreen(),
      routes: {
        '/change-password': (_) => const Scaffold(body: Text('Change Password Page Mock')),
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late ApiClient client;
  late SessionProvider sessionProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = await StorageService.init();
    client = ApiClient(
      storage: storage,
      httpClient: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'success': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
      baseUrl: 'http://localhost',
    );
    sessionProvider = SessionProvider(storage, client);
  });

  group('CustomerSecurityScreen Redesign v2', () {
    testWidgets('renders all visual elements, cards, list tiles, and logout actions', (tester) async {
      await tester.pumpWidget(await _build(sessionProvider: sessionProvider));
      await tester.pumpAndSettle();

      // TopAppBar & Header Text
      expect(find.text('Security'), findsNWidgets(2)); // Title in AppBar + Heading in body
      expect(
        find.text('Manage your credentials and monitor account access.'),
        findsOneWidget,
      );

      // Grouped Card Option Tiles
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Two-Factor Authentication'), findsOneWidget);
      expect(find.text('Enable SMS Authentication'), findsOneWidget);
      expect(find.text('Login Activity'), findsOneWidget);

      // Sign out CTA and caption
      expect(find.text('Sign Out of All Devices'), findsOneWidget);
      expect(
        find.text(
          'For security, we recommend signing out of all devices if you suspect unauthorized access.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Change Password tile navigates to ChangePasswordScreen', (tester) async {
      await tester.pumpWidget(await _build(sessionProvider: sessionProvider));
      await tester.pumpAndSettle();

      // Tap on the Change Password tile
      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      // Verify that the change password screen was pushed onto stack
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('Sign Out of All Devices button triggers premium confirmation dialog and logs out', (tester) async {
      var loggedOut = false;
      sessionProvider.addListener(() {
        if (!sessionProvider.isLoggedIn) {
          loggedOut = true;
        }
      });

      await tester.pumpWidget(await _build(sessionProvider: sessionProvider));
      await tester.pumpAndSettle();

      // Tapping "Sign Out of All Devices"
      final signOutBtnFinder = find.text('Sign Out of All Devices');
      await tester.ensureVisible(signOutBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(signOutBtnFinder);
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog is visible
      expect(find.text('Sign Out of All Devices'), findsNWidgets(2)); // App bar + Dialog title
      expect(
        find.text(
          'Are you sure you want to sign out of all devices? You will need to log back in to access your account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Tap Sign Out to confirm
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Verify logout listener was triggered
      expect(loggedOut, isTrue);
    });
  });
}
