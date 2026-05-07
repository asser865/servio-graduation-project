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
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/customer/customer_profile_screen.dart';
import 'package:servio_mobile_app/src/features/marketing/contact_screen.dart';
import 'package:servio_mobile_app/src/features/shared/report_problem_screen.dart';
import 'package:servio_mobile_app/src/features/technician/technician_profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customer profile opens Report a Problem page', (tester) async {
    await tester.pumpWidget(
      await _wrapProfile(
        const CustomerProfileScreen(),
        role: UserRole.customer,
      ),
    );

    await _tapProfileTile(tester, 'Report a Problem');

    expect(find.byType(ReportProblemScreen), findsOneWidget);
    expect(find.byType(ContactScreen), findsNothing);
  });

  testWidgets('customer profile Contact Us remains separate', (tester) async {
    await tester.pumpWidget(
      await _wrapProfile(
        const CustomerProfileScreen(),
        role: UserRole.customer,
      ),
    );

    await _tapProfileTile(tester, 'Contact Us');

    expect(find.byType(ContactScreen), findsOneWidget);
    expect(find.byType(ReportProblemScreen), findsNothing);
  });

  testWidgets('technician profile opens Report a Problem page', (tester) async {
    await tester.pumpWidget(
      await _wrapProfile(
        const TechnicianSettingsProfileScreen(),
        role: UserRole.technician,
      ),
    );

    await _tapProfileTile(tester, 'Report a Problem');

    expect(find.byType(ReportProblemScreen), findsOneWidget);
    expect(find.byType(ContactScreen), findsNothing);
  });
}

Future<Widget> _wrapProfile(
  Widget child, {
  required UserRole role,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'servio_session': jsonEncode(_account(role).toJson()),
  });

  final storage = await StorageService.init();
  final client = ApiClient(
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

  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider.load(storage, client),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

UserAccount _account(UserRole role) {
  final isTechnician = role == UserRole.technician;

  return UserAccount(
    id: isTechnician ? 'tech1' : 'cust1',
    name: isTechnician ? 'Mona Adel' : 'Ahmed Essam',
    email: isTechnician ? 'mona@example.com' : 'ahmed@example.com',
    phone: '01000000000',
    role: role,
    city: 'Cairo',
  );
}

Future<void> _tapProfileTile(WidgetTester tester, String label) async {
  final tileFinder = find.text(label);

  await tester.scrollUntilVisible(
    tileFinder,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  await tester.tap(tileFinder);
  await tester.pumpAndSettle();
}
