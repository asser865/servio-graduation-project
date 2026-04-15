import 'package:flutter/material.dart';

final class ServioColors {
  const ServioColors._();

  // ── Light mode ──────────────────────────────────────────────
  static const Color backgroundLight     = Color(0xFFFAF8F5);
  static const Color backgroundSoftLight = Color(0xFFF3EDE7);
  static const Color surfaceLight        = Color(0xFFFFFFFF);
  static const Color surfaceAltLight     = Color(0xFFF7F3EF);
  static const Color textPrimaryLight    = Color(0xFF222831);
  static const Color textSecondaryLight  = Color(0xFF6B6560);
  static const Color borderLight         = Color(0xFFDDD5CC);

  // ── Dark mode ───────────────────────────────────────────────
  static const Color backgroundDark      = Color(0xFF1A1D23);
  static const Color backgroundSoftDark  = Color(0xFF262B34);
  static const Color surfaceDark         = Color(0xFF222831);
  static const Color surfaceAltDark      = Color(0xFF1E2229);
  static const Color surfaceRaisedDark   = Color(0xFF2D323B);
  static const Color textPrimaryDark     = Color(0xFFE3D5CA);
  static const Color textSecondaryDark   = Color(0xFF9A8C73);
  static const Color borderDark          = Color(0xFF393E46);

  // ── Brand palette ───────────────────────────────────────────
  static const Color accent       = Color(0xFF9A8C73);
  static const Color accentLight  = Color(0xFFBFB09A);
  static const Color neutralWarm  = Color(0xFFE3D5CA);
  static const Color deepBrown    = Color(0xFF3C2415);
  static const Color brownLight   = Color(0xFF5C3D2E);
  static const Color navyDark     = Color(0xFF222831);
  static const Color navySoft     = Color(0xFF393E46);

  // ── Status ──────────────────────────────────────────────────
  static const Color success  = Color(0xFF22C55E);
  static const Color warning  = Color(0xFFE67E22);
  static const Color info     = Color(0xFF2980B9);
  static const Color danger   = Color(0xFFEF4444);

  static Color tint(Color color) => color.withValues(alpha: 0.12);
}

final class ServioGradients {
  const ServioGradients._();

  static const Alignment _tl = Alignment.topLeft;
  static const Alignment _br = Alignment.bottomRight;

  static const LinearGradient brand = LinearGradient(
    begin: _tl,
    end: _br,
    colors: <Color>[ServioColors.deepBrown, ServioColors.navyDark],
  );

  // Dark-mode inverted brand gradient (warm sand → taupe)
  static const LinearGradient brandDark = LinearGradient(
    begin: _tl,
    end: _br,
    colors: <Color>[ServioColors.neutralWarm, Color(0xFFA68B7B)],
  );

  // 90deg matches web: linear-gradient(90deg, #9A8C73, #BFB09A)
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[ServioColors.accent, ServioColors.accentLight],
  );

  static const LinearGradient warm = LinearGradient(
    begin: _tl,
    end: _br,
    colors: <Color>[ServioColors.neutralWarm, Color(0xFFC8B9AA)],
  );

  // Splash / loader progress bar
  static const LinearGradient loader = LinearGradient(
    colors: <Color>[
      ServioColors.deepBrown,
      ServioColors.brownLight,
      ServioColors.accent,
      ServioColors.accentLight,
      ServioColors.neutralWarm,
    ],
  );
}

final class ServioRadius {
  const ServioRadius._();

  static const double sm      = 10;
  static const double md      = 14;
  static const double lg      = 18;
  static const double xl      = 22;
  static const double xxl     = 28;
  static const double card    = 16;  // recommended mobile card radius
  static const double navItem = 12;  // dashboard / bottom-nav item pill
  static const double full    = 9999;
}

final class ServioSpacing {
  const ServioSpacing._();

  static const double screenPadding = 20;
  static const double sectionGap    = 32;
  static const double cardPadding   = 16;
  static const double tapTarget     = 44; // minimum touch target (iOS HIG)
}

final class ServioMotion {
  const ServioMotion._();

  // ── The SERVIO signature spring ─────────────────────────────
  // Source: cubic-bezier(0.22, 1, 0.36, 1) from the web frontend
  static const Curve spring = Cubic(0.22, 1.0, 0.36, 1.0);

  // Scroll-reveal easing (separate from interactive spring)
  static const Curve reveal = Cubic(0.2, 0.8, 0.2, 1.0);

  static const Curve standard = Curves.ease;

  // ── Duration scale ──────────────────────────────────────────
  static const Duration fast            = Duration(milliseconds: 180);
  static const Duration normal          = Duration(milliseconds: 220);
  static const Duration micro           = Duration(milliseconds: 300);
  static const Duration page            = Duration(milliseconds: 700);
  static const Duration stackNavigation = Duration(milliseconds: 350);
  static const Duration tabSwitch       = Duration(milliseconds: 300);
  static const Duration bottomSheet     = Duration(milliseconds: 400);
  static const Duration toast           = Duration(milliseconds: 300);

  // ── Convenience alias (used in theme) ───────────────────────
  /// Primary curve for UI interactions — use [spring] for
  /// element entrance, AnimatedContainer, hero transitions, etc.
  static const Curve curve = spring;
}

final class ServioShadows {
  const ServioShadows._();

  // Light mode
  static const List<BoxShadow> rest = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(34, 40, 49, 0.06),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(34, 40, 49, 0.10),
      blurRadius: 36,
      offset: Offset(0, 14),
    ),
  ];

  // Dark mode
  static const List<BoxShadow> restDark = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.30),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevatedDark = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.40),
      blurRadius: 36,
      offset: Offset(0, 14),
    ),
  ];
}
