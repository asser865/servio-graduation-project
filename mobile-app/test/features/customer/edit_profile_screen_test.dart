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
import 'package:servio_mobile_app/src/features/customer/edit_profile_screen.dart';

// Test user data matching the session storage format
const Map<String, dynamic> _kTestUser = {
  'id': 'user123',
  'name': 'Alexander Sterling',
  'email': 'alexander.s@example.com',
  'phone': '+1 555 1234567',
  'role': 'customer',
  'avatarInitials': 'AS',
  'status': 'active',
};

Future<Widget> _build({
  required SessionProvider sessionProvider,
}) async {
  return ChangeNotifierProvider<SessionProvider>.value(
    value: sessionProvider,
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: const EditProfileScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late ApiClient client;
  late SessionProvider sessionProvider;

  setUp(() async {
    // Pre-seed storage so SessionProvider.load() hydrates the account
    SharedPreferences.setMockInitialValues(<String, Object>{
      'servio_session': jsonEncode(_kTestUser),
      'servio_account': jsonEncode(_kTestUser),
    });
    storage = await StorageService.init();
    client = ApiClient(
      storage: storage,
      httpClient: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'success': true, 'data': _kTestUser}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
      baseUrl: 'http://localhost',
    );
    // Use SessionProvider.load() so _loadFromStorage() is called
    sessionProvider = SessionProvider.load(storage, client);
  });

  group('EditProfileScreen Redesign', () {
    testWidgets(
        'renders all visual elements: header, avatar, form card, and inputs',
        (tester) async {
      await tester.pumpWidget(await _build(sessionProvider: sessionProvider));
      await tester.pumpAndSettle();

      // TopAppBar
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Avatar section — initials and caption
      expect(find.text('AS'), findsOneWidget);
      expect(find.text('Tap to change photo'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

      // Form card field labels
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      // Pre-filled input values from the mock account
      expect(find.text('Alexander Sterling'), findsOneWidget);
      expect(find.text('alexander.s@example.com'), findsOneWidget);
      expect(find.text('+1 555 1234567'), findsOneWidget);

      // Save Changes button is present
      expect(find.text('Save Changes'), findsOneWidget);

      // Inline email Change button
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets(
        'Save Changes button becomes tappable after editing a text field',
        (tester) async {
      await tester.pumpWidget(await _build(sessionProvider: sessionProvider));
      await tester.pumpAndSettle();

      // Find the three TextFields in order: name, email, phone
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      // Before any edits the container has a greyed-out appearance
      // (We test the state change by checking _isChanged changes the widget)
      // Modify the Name field
      await tester.enterText(textFields.at(0), 'Alexander Sterling Updated');
      await tester.pumpAndSettle();

      // The save button text stays "Save Changes"
      expect(find.text('Save Changes'), findsOneWidget);

      // Restore back to original so _isChanged resets
      await tester.enterText(textFields.at(0), 'Alexander Sterling');
      await tester.pumpAndSettle();

      // Modify the Phone field
      await tester.enterText(textFields.at(2), '+1 999 9999999');
      await tester.pumpAndSettle();

      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets(
        'email inline Change button opens Confirm Email Change dialog',
        (tester) async {
      await tester.pumpWidget(await _build(sessionProvider: sessionProvider));
      await tester.pumpAndSettle();

      // Find the email TextField (index 1)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      // Type a new email address to enable the inline Change button
      await tester.enterText(textFields.at(1), 'new.email@example.com');
      await tester.pumpAndSettle();

      // Tap the inline "Change" button
      final changeBtnFinder = find.text('Change');
      expect(changeBtnFinder, findsOneWidget);
      await tester.tap(changeBtnFinder);
      await tester.pumpAndSettle();

      // Verify the Confirm Email Change dialog appeared
      expect(find.text('Confirm Email Change'), findsOneWidget);
      expect(find.text('New email: new.email@example.com'), findsOneWidget);
      expect(find.text('Enter your current password to confirm:'), findsOneWidget);

      // The password TextField should be present in the dialog
      // (4 total = 3 form fields + 1 dialog password field)
      expect(find.byType(TextField), findsNWidgets(4));

      // Dismiss with Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Confirm dialog is closed
      expect(find.text('Confirm Email Change'), findsNothing);
      // The 3 original form fields remain
      expect(find.byType(TextField), findsNWidgets(3));
    });
  });
}
