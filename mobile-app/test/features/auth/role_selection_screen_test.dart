import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/features/auth/role_selection_screen.dart';

Widget _build({Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const RoleSelectionScreen(),
    );

void main() {
  group('RoleSelectionScreen', () {
    testWidgets('shows role question heading', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('How do you want to use SERVIO?'), findsOneWidget);
    });

    testWidgets('shows both role options', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('I need a service'), findsOneWidget);
      expect(find.text('Offer my skills'), findsOneWidget);
    });

    testWidgets('Continue button is available with default customer role',
        (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('tapping professional role keeps Continue available',
        (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offer my skills'));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows login link', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });
  });
}
