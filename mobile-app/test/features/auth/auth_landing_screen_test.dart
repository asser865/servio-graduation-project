import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/features/auth/auth_landing_screen.dart';
import 'package:servio_mobile_app/src/features/auth/widgets/auth_background.dart';

Widget _build({Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const AuthLandingScreen(),
    );

void main() {
  group('AuthLandingScreen', () {
    testWidgets('shows SERVIO brand text', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('SERVIO'), findsOneWidget);
    });

    testWidgets('shows both action buttons', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows trust pills', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Verified professionals'), findsOneWidget);
      expect(find.text('Top-rated every time'), findsOneWidget);
    });

    testWidgets('uses AuthBackground', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });

    testWidgets('uses AuthBackground in light mode too', (tester) async {
      await tester.pumpWidget(_build(brightness: Brightness.light));
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });
  });
}
