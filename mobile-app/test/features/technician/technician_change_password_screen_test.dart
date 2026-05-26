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
import 'package:servio_mobile_app/src/features/technician/technician_change_password_screen.dart';

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
      theme: ServioTheme.light(),
      home: const TechnicianChangePasswordScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TechnicianChangePasswordScreen Redesign', () {
    testWidgets('renders all security details and fields correctly', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Security Details'), findsOneWidget);
      expect(
        find.text('Ensure your account stays secure by using a strong password.'),
        findsOneWidget,
      );

      // Verify fields exist by their placeholder / hint text
      expect(find.text('Enter current password'), findsOneWidget);
      expect(find.text('Create new password'), findsOneWidget);
      expect(find.text('Repeat new password'), findsOneWidget);

      // Password requirements list
      expect(find.text('Password requirements:'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('One uppercase letter'), findsOneWidget);
      expect(find.text('One lowercase letter'), findsOneWidget);
      expect(find.text('One number'), findsOneWidget);
      expect(find.text('One special character'), findsOneWidget);

      // Buttons
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('validates matching and mismatching confirm password', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();

      // Enter "Abcdef1!" into New Password (at index 1)
      final newPasswordFinder = find.byType(TextField).at(1);
      await tester.enterText(newPasswordFinder, 'Abcdef1!');
      await tester.pumpAndSettle();

      // Enter mismatched text in Confirm Password (at index 2)
      final confirmPasswordFinder = find.byType(TextField).at(2);
      await tester.enterText(confirmPasswordFinder, 'MismatchedText!');
      await tester.pumpAndSettle();

      expect(
        find.text('Confirm Password must match the New Password.'),
        findsOneWidget,
      );

      // Fix it by matching
      await tester.enterText(confirmPasswordFinder, 'Abcdef1!');
      await tester.pumpAndSettle();

      expect(
        find.text('Confirm Password must match the New Password.'),
        findsNothing,
      );
    });

    testWidgets('shows warning when new password is identical to current password', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();

      final currentPasswordFinder = find.byType(TextField).at(0);
      final newPasswordFinder = find.byType(TextField).at(1);

      await tester.enterText(currentPasswordFinder, 'CurrentPass123!');
      await tester.enterText(newPasswordFinder, 'CurrentPass123!');
      await tester.pumpAndSettle();

      expect(
        find.text('New Password cannot be identical to the Current Password.'),
        findsOneWidget,
      );
    });

    testWidgets('checklist and password strength bar dynamically update with strength levels', (tester) async {
      await tester.pumpWidget(await _build());
      await tester.pumpAndSettle();

      final newPasswordFinder = find.byType(TextField).at(1);

      // Test case 1: Weak password
      await tester.enterText(newPasswordFinder, 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Weak'), findsOneWidget);

      // Test case 2: Medium password (at least 8 chars + lowercase + uppercase)
      await tester.enterText(newPasswordFinder, 'Abcdefgh');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Medium'), findsOneWidget);

      // Test case 3: Strong password (all requirements met)
      await tester.enterText(newPasswordFinder, 'Abcdef1!');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Strong'), findsOneWidget);
    });

    testWidgets('successful change password submission sends PATCH request and pops', (tester) async {
      var passwordChangedPatchCalled = false;

      await tester.pumpWidget(
        await _build(
          httpClient: MockClient((http.Request request) async {
            if (request.method == 'PATCH' &&
                request.url.path.endsWith('/users/me/password')) {
              passwordChangedPatchCalled = true;
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['currentPassword'], 'OldPassword1!');
              expect(body['newPassword'], 'NewPassword2@');
              return http.Response(
                jsonEncode(<String, Object?>{'success': true}),
                200,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode(<String, Object?>{'success': true}),
              200,
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      final currentPasswordFinder = find.byType(TextField).at(0);
      final newPasswordFinder = find.byType(TextField).at(1);
      final confirmPasswordFinder = find.byType(TextField).at(2);

      await tester.enterText(currentPasswordFinder, 'OldPassword1!');
      await tester.enterText(newPasswordFinder, 'NewPassword2@');
      await tester.enterText(confirmPasswordFinder, 'NewPassword2@');
      await tester.pumpAndSettle();

      // Submit button is active, scroll to make sure it is fully visible and hit-testable
      final buttonFinder = find.text('Update Password');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();

      // Tap the Update Password button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(passwordChangedPatchCalled, isTrue);
    });

    group('Accessibility and Toggles', () {
      testWidgets('password visibility toggle changes obscureText value', (tester) async {
        await tester.pumpWidget(await _build());
        await tester.pumpAndSettle();

        final currentTextFieldFinder = find.byType(TextField).at(0);
        var currentTextField = tester.widget<TextField>(currentTextFieldFinder);
        expect(currentTextField.obscureText, isTrue);

        // Find the toggle icon button (which initially has visibility_off)
        final visibilityToggleFinder = find.byIcon(Icons.visibility_off_outlined).at(0);
        await tester.tap(visibilityToggleFinder);
        await tester.pumpAndSettle();

        // Re-query the widget from the tree to verify the updated state
        currentTextField = tester.widget<TextField>(currentTextFieldFinder);
        expect(currentTextField.obscureText, isFalse);
      });
    });
  });
}
