import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/features/shared/account_screen.dart';

void main() {
  testWidgets('delete account dialog requires typed confirmation',
      (tester) async {
    await tester.pumpWidget(_wrap(const AccountScreen()));

    await _openDeleteDialog(tester);

    final inputFinder = find.byKey(
      const ValueKey<String>('delete-account-confirm-input'),
    );
    final confirmButtonFinder = find.byKey(
      const ValueKey<String>('delete-account-confirm-button'),
    );

    expect(
      find.text(
        'This will permanently delete your account and all associated data. '
        'This action cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(inputFinder, findsOneWidget);
    expect(_confirmationProgress(tester), 0);
    expect(_confirmButton(tester, confirmButtonFinder).onPressed, isNull);

    await tester.enterText(inputFinder, 'remove');
    await tester.pump();

    expect(_confirmationText(tester), isEmpty);
    expect(_confirmationProgress(tester), 0);
    expect(_confirmButton(tester, confirmButtonFinder).onPressed, isNull);

    await tester.enterText(inputFinder, 'd');
    await tester.pump();

    expect(_confirmationText(tester), 'd');
    expect(_confirmationProgress(tester), closeTo(1 / 6, 0.001));
    expect(_confirmButton(tester, confirmButtonFinder).onPressed, isNull);

    await tester.enterText(inputFinder, 'delet');
    await tester.pump();

    expect(_confirmationText(tester), 'delet');
    expect(_confirmationProgress(tester), closeTo(5 / 6, 0.001));
    expect(_confirmButton(tester, confirmButtonFinder).onPressed, isNull);

    await tester.enterText(inputFinder, 'deletex');
    await tester.pump();

    expect(_confirmationText(tester), 'delet');
    expect(_confirmationProgress(tester), closeTo(5 / 6, 0.001));
    expect(_confirmButton(tester, confirmButtonFinder).onPressed, isNull);

    await tester.enterText(inputFinder, 'DELETE');
    await tester.pump();

    expect(_confirmationText(tester), 'DELETE');
    expect(_confirmationProgress(tester), 1);
    expect(_confirmButton(tester, confirmButtonFinder).onPressed, isNotNull);

    await tester.tap(confirmButtonFinder);
    await tester.pumpAndSettle();

    expect(inputFinder, findsNothing);
  });

  testWidgets('delete account dialog fits compact mobile width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const AccountScreen()));

    await _openDeleteDialog(tester);

    expect(
      find.byKey(const ValueKey<String>('delete-account-confirm-input')),
      findsOneWidget,
    );
    expect(find.text('Delete My Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete account dialog follows light and dark theme surfaces',
      (tester) async {
    await tester.pumpWidget(_wrap(const AccountScreen()));
    await _openDeleteDialog(tester);

    expect(_dialogDecoration(tester).color,
        ServioTheme.light().colorScheme.surface);

    await tester.tap(
      find.byKey(const ValueKey<String>('delete-account-cancel-button')),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(_wrap(const AccountScreen(), dark: true));
    await _openDeleteDialog(tester);

    expect(
      _dialogDecoration(tester).color,
      ServioTheme.dark().extension<ServioThemeExtension>()!.surfaceRaised,
    );
  });
}

Widget _wrap(Widget child, {bool dark = false}) {
  return MaterialApp(
    theme: dark ? ServioTheme.dark() : ServioTheme.light(),
    home: child,
  );
}

Future<void> _openDeleteDialog(WidgetTester tester) async {
  await tester.tap(find.text('Delete Account'));
  await tester.pumpAndSettle();
}

FilledButton _confirmButton(WidgetTester tester, Finder finder) {
  return tester.widget<FilledButton>(finder);
}

BoxDecoration _dialogDecoration(WidgetTester tester) {
  final dialogFinder = find.byType(Dialog);
  final decoratedBoxFinder = find.descendant(
    of: dialogFinder,
    matching: find.byType(DecoratedBox),
  );
  return tester.widget<DecoratedBox>(decoratedBoxFinder.first).decoration
      as BoxDecoration;
}

String _confirmationText(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).controller.text;
}

double _confirmationProgress(WidgetTester tester) {
  final meterFinder = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(AnimatedFractionallySizedBox),
  );
  return tester
          .widget<AnimatedFractionallySizedBox>(meterFinder.last)
          .widthFactor ??
      0;
}
