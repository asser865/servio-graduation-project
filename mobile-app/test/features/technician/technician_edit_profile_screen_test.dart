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
import 'package:servio_mobile_app/src/features/technician/technician_edit_profile_screen.dart';

Future<Widget> _wrap({UserAccount? account}) async {
  SharedPreferences.setMockInitialValues(
    account != null
        ? {'servio_session': jsonEncode(account.toJson())}
        : <String, Object>{},
  );

  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((_) async => http.Response('{}', 200)),
    baseUrl: 'http://localhost',
  );

  return ChangeNotifierProvider<SessionProvider>(
    create: (_) => SessionProvider.load(storage, client),
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: const TechnicianEditProfileScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit profile does NOT show Skills field', (tester) async {
    await tester.pumpWidget(await _wrap(
      account: const UserAccount(
        id: 'w1',
        name: 'Ali',
        email: 'ali@test.com',
        phone: '0101',
        role: UserRole.technician,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Skills (comma-separated)'), findsNothing);
    expect(find.text('Skills'), findsNothing);
  });

  testWidgets('edit profile still shows Name field', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    expect(find.text('Full Name'), findsOneWidget);
  });
}
