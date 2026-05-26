import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/features/auth/auth_landing_screen.dart';

Widget _build({Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: AuthLandingScreen(),
      ),
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

    testWidgets('shows Stitch service chips', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Electrical'), findsOneWidget);
      expect(find.text('HVAC'), findsOneWidget);
    });

    testWidgets('shows the landing value proposition', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(
        find.text('Transform your home with verified technicians.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in light mode too', (tester) async {
      await tester.pumpWidget(_build(brightness: Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('SERVIO'), findsOneWidget);
    });
  });
}
