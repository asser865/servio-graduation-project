import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/marketing/contact_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> wrapWidget(Widget child) async {
    return MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    );
  }

  group('ContactScreen Redesign', () {
    testWidgets('renders all visual elements correctly', (tester) async {
      await tester.pumpWidget(await wrapWidget(const ContactScreen()));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Get in touch'), findsOneWidget);

      // Check form card parts
      expect(find.text('Send a message'), findsOneWidget);
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('SUBJECT'), findsOneWidget);
      expect(find.text('MESSAGE'), findsOneWidget);
      expect(find.text('Send Message'), findsOneWidget);

      // Check bento cards
      expect(find.text('Email Us'), findsOneWidget);
      expect(find.text('Call Us'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('support@servio.com'), findsOneWidget);
      expect(find.text('+1 (800) 555-0199'), findsOneWidget);
    });

    testWidgets('form validation blocks submit on empty required fields', (tester) async {
      await tester.pumpWidget(await wrapWidget(const ContactScreen()));
      await tester.pumpAndSettle();

      final submitBtn = find.text('Send Message');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsAtLeastNWidgets(2));
      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('form validation blocks submit on invalid email format', (tester) async {
      await tester.pumpWidget(await wrapWidget(const ContactScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Alexander');
      await tester.enterText(find.byType(TextFormField).at(1), 'invalidemail');
      await tester.enterText(find.byType(TextFormField).at(3), 'Need help with plumbing ASAP.');

      final submitBtn = find.text('Send Message');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('This field is required.'), findsNothing);
    });

    testWidgets('submits successfully and clears fields', (tester) async {
      await tester.pumpWidget(await wrapWidget(const ContactScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Alexander');
      await tester.enterText(find.byType(TextFormField).at(1), 'alexander@example.com');
      await tester.enterText(find.byType(TextFormField).at(3), 'Need help with plumbing ASAP.');

      final submitBtn = find.text('Send Message');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump(const Duration(milliseconds: 200)); // Start submitting

      // Check loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600)); // Finish delay
      await tester.pumpAndSettle();

      expect(find.text('Message sent. We will reply within 2 business hours.'), findsOneWidget);
    });
  });
}
