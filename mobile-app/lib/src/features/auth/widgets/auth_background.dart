import 'package:flutter/material.dart';
import '../../../design_system/servio_tokens.dart';

/// Full-screen background for auth screens.
///
/// Dark mode: deep brown→navy gradient fills the entire screen.
/// Light mode: brand gradient anchors the top [lightHeaderHeight] px,
/// then warm cream below it with a 22 px rounded cutout.
/// Set [fullBleed] for the richer auth showcase background used by sign in.
///
/// Place as `Positioned.fill` as the first child of the screen's Stack:
/// ```dart
/// Positioned.fill(child: AuthBackground(lightHeaderHeight: 210))
/// ```
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    this.lightHeaderHeight = 240.0,
    this.fullBleed = false,
  });

  final double lightHeaderHeight;
  final bool fullBleed;

  static const _kDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C2415), Color(0xFF222831), Color(0xFF1E2633)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (fullBleed) {
      return _FullBleedAuthBackground(isDark: isDark);
    }

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

class _FullBleedAuthBackground extends StatelessWidget {
  const _FullBleedAuthBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor =
        isDark ? ServioColors.backgroundDark : ServioColors.backgroundLight;
    final headerGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0D0A09),
              ServioColors.deepBrown,
              ServioColors.navyDark,
              ServioColors.backgroundDark,
            ],
            stops: <double>[0, 0.32, 0.68, 1],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ServioColors.deepBrown,
              ServioColors.brownLight,
              ServioColors.navyDark,
            ],
          );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: baseColor)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height * 0.58,
          child: DecoratedBox(decoration: BoxDecoration(gradient: headerGradient)),
        ),
        Positioned(
          top: MediaQuery.sizeOf(context).height * 0.46,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  baseColor.withValues(alpha: 0),
                  baseColor.withValues(alpha: 0.72),
                  baseColor,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -180,
          right: -170,
          child: _AmbientGlow(
            size: 430,
            color: isDark
                ? ServioColors.accentLight.withValues(alpha: 0.32)
                : ServioColors.accent.withValues(alpha: 0.26),
          ),
        ),
        Positioned(
          top: 120,
          left: -180,
          child: _AmbientGlow(
            size: 360,
            color: isDark
                ? ServioColors.brownLight.withValues(alpha: 0.36)
                : ServioColors.neutralWarm.withValues(alpha: 0.30),
          ),
        ),
        Positioned(
          right: -130,
          bottom: -150,
          child: _AmbientGlow(
            size: 340,
            color: isDark
                ? ServioColors.navySoft.withValues(alpha: 0.42)
                : ServioColors.accentLight.withValues(alpha: 0.22),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.55, -0.45),
                radius: 1.18,
                colors: <Color>[
                  Colors.white.withValues(alpha: isDark ? 0.035 : 0.065),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color,
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
