import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/customer/customer_profile_screen.dart';
import 'package:servio_mobile_app/src/features/customer/customer_settings_screen.dart';
import 'package:servio_mobile_app/src/features/customer/my_bookings_screen.dart';
import 'package:servio_mobile_app/src/features/marketing/faq_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Map<String, dynamic> testUser = {
    'id': 'user123',
    'name': 'Alexander Sterling',
    'email': 'alexander.s@example.com',
    'phone': '+1 555 1234567',
    'role': 'customer',
    'avatarInitials': 'AS',
    'status': 'active',
  };

  Future<Widget> wrapProfile(Widget child) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'servio_session': jsonEncode(testUser),
      'servio_account': jsonEncode(testUser),
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
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(storage),
        ),
      ],
      child: MaterialApp(
        theme: ServioTheme.light(),
        home: child,
      ),
    );
  }

  group('CustomerProfileScreen Redesign', () {
    testWidgets('renders profile user cards and stat chips correctly', (tester) async {
      await tester.pumpWidget(await wrapProfile(const CustomerProfileScreen()));
      await tester.pumpAndSettle();

      // Check Appbar Title
      expect(find.text('Profile'), findsOneWidget);

      // Check User Details Card
      expect(find.text('Alexander Sterling'), findsOneWidget);
      expect(find.text('AS'), findsOneWidget);
      expect(find.text('Member since 2025'), findsWidgets);

      // Check stat chips
      expect(find.text('BOOKINGS'), findsOneWidget);
      expect(find.text('REVIEWS'), findsOneWidget);
      expect(find.text('SPENT'), findsOneWidget);
    });

    testWidgets('navigates to MyBookingsScreen when tapping Bookings tile', (tester) async {
      await tester.pumpWidget(await wrapProfile(const CustomerProfileScreen()));
      await tester.pumpAndSettle();

      final bookingsTile = find.ancestor(
        of: find.text('Bookings'),
        matching: find.byType(InkWell),
      );
      await tester.tap(bookingsTile.first);
      await tester.pumpAndSettle();

      expect(find.byType(MyBookingsScreen), findsOneWidget);
    });

    testWidgets('navigates to CustomerSettingsScreen when tapping Settings tile', (tester) async {
      await tester.pumpWidget(await wrapProfile(const CustomerProfileScreen()));
      await tester.pumpAndSettle();

      final settingsTile = find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(InkWell),
      );
      await tester.tap(settingsTile.first);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerSettingsScreen), findsOneWidget);
    });

    testWidgets('navigates to FAQ when tapping FAQ tile', (tester) async {
      await tester.pumpWidget(await wrapProfile(const CustomerProfileScreen()));
      await tester.pumpAndSettle();

      final faqTileFinder = find.text('FAQ');
      await tester.scrollUntilVisible(
        faqTileFinder,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final faqTile = find.ancestor(
        of: faqTileFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(faqTile.first);
      await tester.pumpAndSettle();

      expect(find.byType(FaqScreen), findsOneWidget);
    });
  });
}
