import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/design_system/widgets/servio_primary_button.dart';
import 'package:servio_mobile_app/src/features/auth/role_selection_screen.dart';
import 'package:servio_mobile_app/src/features/auth/widgets/auth_background.dart';

Widget _build({Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const RoleSelectionScreen(),
    );

void main() {
  group('RoleSelectionScreen', () {
    testWidgets('shows role question heading', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.textContaining('How will you'), findsOneWidget);
    });

    testWidgets('shows both role options', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('I need a service'), findsOneWidget);
      expect(find.text("I'm a technician"), findsOneWidget);
    });

    testWidgets('Continue button disabled until role selected', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      // Find the ServioPrimaryButton and check its onPressed is null
      final servioPrimaryButton = tester.widget<ServioPrimaryButton>(
          find.byType(ServioPrimaryButton));
      expect(servioPrimaryButton.onPressed, isNull);
    });

    testWidgets('tapping a role card enables Continue', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('I need a service'));
      await tester.pump();
      // After selecting a role, onPressed should not be null
      final servioPrimaryButton = tester.widget<ServioPrimaryButton>(
          find.byType(ServioPrimaryButton));
      expect(servioPrimaryButton.onPressed, isNotNull);
    });

    testWidgets('uses AuthBackground', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });
  });
}
