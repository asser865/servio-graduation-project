// mobile-app/test/features/booking/booking_progress_indicator_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/booking/widgets/booking_progress_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ServioTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('BookingProgressIndicator', () {
    testWidgets('step 1 active: circles 2 and 3 are future', (tester) async {
      await tester.pumpWidget(_wrap(
        const BookingProgressIndicator(
          currentStep: 1,
          totalSteps: 3,
          stepLabels: <String>['Details', 'Schedule', 'Payment'],
        ),
      ));
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('step 2 active: step 1 shows checkmark', (tester) async {
      await tester.pumpWidget(_wrap(
        const BookingProgressIndicator(
          currentStep: 2,
          totalSteps: 3,
          stepLabels: <String>['Details', 'Schedule', 'Payment'],
        ),
      ));
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('step 3 active: steps 1 and 2 show checkmarks', (tester) async {
      await tester.pumpWidget(_wrap(
        const BookingProgressIndicator(
          currentStep: 3,
          totalSteps: 3,
          stepLabels: <String>['Details', 'Schedule', 'Payment'],
        ),
      ));
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
