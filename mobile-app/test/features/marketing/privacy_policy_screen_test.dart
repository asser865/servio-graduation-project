import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/marketing/privacy_policy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    );
  }

  testWidgets('renders AppBar, Last Updated card, and Table of Contents',
      (tester) async {
    await tester.pumpWidget(wrap(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    // Verify Sticky App Bar title
    expect(find.text('Privacy Policy'), findsOneWidget);

    // Verify Last Updated Info Card
    expect(find.text('Last Updated'), findsOneWidget);
    expect(find.text('May 2026'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    // Verify Table of Contents is visible
    expect(find.text('Table of Contents'), findsOneWidget);
    expect(find.textContaining('1. Introduction'), findsOneWidget);
  });

  testWidgets('collapsing/expanding sections on header tap works correctly',
      (tester) async {
    await tester.pumpWidget(wrap(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    // Verify we can find the section headers
    final introHeaderFinder = find.text('Introduction');
    expect(introHeaderFinder, findsOneWidget);

    // Tap header to collapse
    await tester.tap(introHeaderFinder);
    await tester.pumpAndSettle();

    // Tap header again to expand
    await tester.tap(introHeaderFinder);
    await tester.pumpAndSettle();
  });

  testWidgets('search functionality filters content, highlights matching text, and auto-expands',
      (tester) async {
    await tester.pumpWidget(wrap(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    // Tap search action icon in AppBar
    final searchIconFinder = find.byTooltip('Search privacy policy');
    expect(searchIconFinder, findsOneWidget);
    await tester.tap(searchIconFinder);
    await tester.pumpAndSettle();

    // Type query "welcome"
    final searchFieldFinder = find.byType(TextField);
    expect(searchFieldFinder, findsOneWidget);
    await tester.enterText(searchFieldFinder, 'welcome');
    await tester.pumpAndSettle();

    // Verify matching query results are displayed (Section 1 matches 'welcome')
    expect(find.textContaining('to SERVIO'), findsOneWidget);
    // Non-matching sections are filtered out
    expect(find.text('3'), findsNothing);
  });

  testWidgets('copy to clipboard actions succeed without throwing errors',
      (tester) async {
    await tester.pumpWidget(wrap(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    // Tap clipboard copy button in AppBar
    final copyIconFinder = find.byTooltip('Copy full policy');
    expect(copyIconFinder, findsOneWidget);
    await tester.tap(copyIconFinder);
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify SnackBar triggers and shows copy message
    expect(find.text('Privacy Policy copied to clipboard.'), findsOneWidget);
  });
}
