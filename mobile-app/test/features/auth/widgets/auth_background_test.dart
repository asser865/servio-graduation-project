import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/features/auth/widgets/auth_background.dart';

void main() {
  group('AuthBackground', () {
    testWidgets('full dark gradient covers screen in dark mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Stack(children: const [
            Positioned.fill(child: AuthBackground()),
            Center(child: Text('content')),
          ]),
        ),
      ));
      expect(find.byType(AuthBackground), findsOneWidget);
      // No cream ColoredBox in dark mode
      expect(
        find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xFFFAF8F5)),
        findsNothing,
      );
    });

    testWidgets('cream body + gradient header in light mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: Stack(children: const [
            Positioned.fill(child: AuthBackground(lightHeaderHeight: 200)),
            Center(child: Text('content')),
          ]),
        ),
      ));
      expect(find.byType(AuthBackground), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xFFFAF8F5)),
        findsOneWidget,
      );
    });
  });
}
