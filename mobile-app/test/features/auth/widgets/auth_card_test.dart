import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/features/auth/widgets/auth_card.dart';

void main() {
  group('AuthCard', () {
    testWidgets('glass surface in dark mode — low opacity fill, no shadow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: AuthCard(child: Text('hi'))),
      ));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
                of: find.byType(AuthCard), matching: find.byType(DecoratedBox))
            .first,
      );
      final deco = box.decoration as BoxDecoration;
      expect(
          (deco.color!.a * 255).round(), lessThan(40)); // ≈ 0.07–0.15 opacity
      expect(deco.boxShadow, anyOf(isNull, isEmpty));
    });

    testWidgets('white elevated card in light mode — opaque white, has shadow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const Scaffold(body: AuthCard(child: Text('hi'))),
      ));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
                of: find.byType(AuthCard), matching: find.byType(DecoratedBox))
            .first,
      );
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, equals(Colors.white));
      expect(deco.boxShadow, isNotEmpty);
    });
  });
}
