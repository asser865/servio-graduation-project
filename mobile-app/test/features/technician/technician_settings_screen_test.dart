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
import 'package:servio_mobile_app/src/features/technician/technician_settings_screen.dart';

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues({
    'servio_session': jsonEncode(
      const UserAccount(
        id: 'w1',
        name: 'Ali',
        email: 'ali@test.com',
        phone: '01012345678',
        role: UserRole.technician,
      ).toJson(),
    ),
  });

  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((_) async => http.Response('{}', 200)),
    baseUrl: 'http://localhost',
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider.load(storage, client),
      ),
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(storage),
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(storage),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: const TechnicianSettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings screen has My Services tile', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    expect(find.text('My Services'), findsOneWidget);
    expect(find.text('Pricing & Payments'), findsOneWidget);
  });

  testWidgets('settings screen has Edit Profile tile with bio subtitle',
      (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Name, photo, bio, rate'), findsOneWidget);
  });
}
