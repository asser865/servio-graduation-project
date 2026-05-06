import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/shared/report_problem_screen.dart';

void main() {
  Widget _wrap(Widget child, {bool dark = false}) {
    return MaterialApp(
      theme: dark ? ServioTheme.dark() : ServioTheme.light(),
      home: child,
    );
  }

  testWidgets('renders page title and description text', (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    expect(find.text('Report a Problem'), findsWidgets);
    expect(
      find.textContaining('Found a bug or experiencing an issue'),
      findsOneWidget,
    );
  });

  testWidgets('shows category dropdown and description field', (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    expect(find.text('Problem Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Submit Report'), findsOneWidget);
  });

  testWidgets('shows error banner when submitting empty form', (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    await tester.ensureVisible(find.text('Submit Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(
      find.text('Please complete the required fields before submitting.'),
      findsOneWidget,
    );
  });

  testWidgets('shows validation error when description is too short',
      (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    // Open dropdown and pick a category
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bug / App Crash').last);
    await tester.pumpAndSettle();

    // Type a short description
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue in detail…'),
      'short',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Submit Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(
      find.text('Please provide at least 20 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('shows success banner and clears form after valid submission',
      (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    // Pick a category
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment Issue').last);
    await tester.pumpAndSettle();

    // Enter a valid description
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue in detail…'),
      'The payment screen crashes when I try to pay.',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Submit Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Report'));
    await tester.pump(); // start submit

    // Advance past the 700ms delay
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(
      find.textContaining('Report submitted'),
      findsOneWidget,
    );
    // Form should be cleared — description is empty
    final editables = tester.widgetList<EditableText>(find.byType(EditableText));
    for (final e in editables) {
      expect(e.controller.text, isEmpty);
    }
  });
}
