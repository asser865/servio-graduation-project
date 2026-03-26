import 'package:flutter/material.dart';

final class ServioColors {
  const ServioColors._();

  static const Color backgroundLight = Color(0xFFFAF8F5);
  static const Color backgroundSoftLight = Color(0xFFF3EDE7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceAltLight = Color(0xFFF7F3EF);
  static const Color textPrimaryLight = Color(0xFF222831);
  static const Color textSecondaryLight = Color(0xFF6B6560);
  static const Color borderLight = Color(0xFFDDD5CC);
  static const Color accent = Color(0xFF9A8C73);
  static const Color accentLight = Color(0xFFBFB09A);
  static const Color neutralWarm = Color(0xFFE3D5CA);
  static const Color deepBrown = Color(0xFF3C2415);
  static const Color navyDark = Color(0xFF222831);

  static const Color backgroundDark = Color(0xFF1A1D23);
  static const Color backgroundSoftDark = Color(0xFF222831);
  static const Color surfaceDark = Color(0xFF222831);
  static const Color surfaceRaisedDark = Color(0xFF2D323B);
  static const Color textPrimaryDark = Color(0xFFE3D5CA);
  static const Color textSecondaryDark = Color(0xFF9A8C73);
  static const Color borderDark = Color(0xFF393E46);

  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFE67E22);
  static const Color info = Color(0xFF2980B9);
  static const Color danger = Color(0xFFC0392B);

  static Color tint(Color color) => color.withValues(alpha: 0.12);
}

final class ServioGradients {
  const ServioGradients._();

  static const Alignment begin = Alignment.topLeft;
  static const Alignment end = Alignment.bottomRight;

  static const LinearGradient brand = LinearGradient(
    begin: begin,
    end: end,
    colors: <Color>[
      ServioColors.deepBrown,
      ServioColors.navyDark,
    ],
  );

  static const LinearGradient accent = LinearGradient(
    begin: begin,
    end: end,
    colors: <Color>[
      ServioColors.accent,
      ServioColors.accentLight,
    ],
  );

  static const LinearGradient warm = LinearGradient(
    begin: begin,
    end: end,
    colors: <Color>[
      ServioColors.neutralWarm,
      Color(0xFFC8B9AA),
    ],
  );
}

final class ServioRadius {
  const ServioRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double full = 9999;
}

final class ServioSpacing {
  const ServioSpacing._();

  static const double screenPadding = 20;
  static const double sectionGap = 32;
  static const double cardPadding = 16;
  static const double tapTarget = 44;
}

final class ServioMotion {
  const ServioMotion._();

  static const Curve curve = Cubic(0.2, 0.8, 0.2, 1);

  static const Duration micro = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 700);
  static const Duration stackNavigation = Duration(milliseconds: 350);
  static const Duration tabSwitch = Duration(milliseconds: 300);
  static const Duration bottomSheet = Duration(milliseconds: 400);
  static const Duration toast = Duration(milliseconds: 300);
}

final class ServioShadows {
  const ServioShadows._();

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
}
