import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/marketing/faq_screen.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    );
  }

  testWidgets('renders FAQ appbar title and heading', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.text('FAQ'), findsOneWidget);
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(find.text('QUICK ANSWERS'), findsOneWidget);
  });

  testWidgets('renders all 4 question tiles', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.text('Booking or account issue?'), findsOneWidget);
    expect(find.text('Want to join as a professional?'), findsOneWidget);
    expect(find.text('How does SERVIO verify professionals?'), findsOneWidget);
    expect(find.text('Just browsing?'), findsOneWidget);
  });

  testWidgets('answers are hidden by default', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.textContaining('Log in to your account'), findsNothing);
    expect(find.textContaining('Sign up as a technician'), findsNothing);
    expect(find.textContaining('profile review'), findsNothing);
    expect(find.textContaining('compare professionals'), findsNothing);
  });

  testWidgets('tapping a question expands its answer', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    await tester.tap(find.text('Want to join as a professional?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sign up as a technician'), findsOneWidget);
  });

  testWidgets('tapping an expanded question collapses it', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    await tester.tap(find.text('Want to join as a professional?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign up as a technician'), findsOneWidget);

    await tester.tap(find.text('Want to join as a professional?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign up as a technician'), findsNothing);
  });

  testWidgets('first answer references Report a Problem, not the contact form',
      (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    await tester.tap(find.text('Booking or account issue?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Report a Problem'), findsOneWidget);
    expect(find.textContaining('contact form above'), findsNothing);
  });
}
