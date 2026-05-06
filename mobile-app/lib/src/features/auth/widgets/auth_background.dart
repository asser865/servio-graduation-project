import 'package:flutter/material.dart';
import '../../../design_system/servio_tokens.dart';

/// Full-screen background for auth screens.
///
/// Dark mode: deep brown→navy gradient fills the entire screen.
/// Light mode: brand gradient anchors the top [lightHeaderHeight] px,
/// then warm cream below it with a 22 px rounded cutout.
///
/// Place as `Positioned.fill` as the first child of the screen's Stack:
/// ```dart
/// Positioned.fill(child: AuthBackground(lightHeaderHeight: 210))
/// ```
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, this.lightHeaderHeight = 240.0});

  final double lightHeaderHeight;

  static const _kDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C2415), Color(0xFF222831), Color(0xFF1E2633)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const DecoratedBox(
        decoration: BoxDecoration(gradient: _kDarkGradient),
        child: SizedBox.expand(),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final headerEnd = topPad + lightHeaderHeight;

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFFAF8F5))),
        Positioned(
          top: 0, left: 0, right: 0, height: headerEnd,
          child: const DecoratedBox(
              decoration: BoxDecoration(gradient: ServioGradients.brand)),
        ),
        Positioned(
          top: headerEnd - 22, left: 0, right: 0, height: 24,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFAF8F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
        ),
      ],
    );
  }
}
