import 'package:flutter/material.dart';

import 'servio_theme_extension.dart';
import 'servio_tokens.dart';

final class ServioTheme {
  const ServioTheme._();

  static ThemeData light() {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.48,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.17,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    );

    // primary = navyDark (#222831): the primary action / nav-active colour in light mode.
    // accent (#9A8C73) is the warm taupe used for highlights — NOT the primary.
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ServioColors.navyDark,
      onPrimary: Colors.white,
      primaryContainer: ServioColors.backgroundSoftLight,
      onPrimaryContainer: ServioColors.navyDark,
      secondary: ServioColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: ServioColors.neutralWarm,
      onSecondaryContainer: ServioColors.deepBrown,
      tertiary: ServioColors.accentLight,
      onTertiary: ServioColors.navyDark,
      error: ServioColors.danger,
      onError: Colors.white,
      surface: ServioColors.surfaceLight,
      onSurface: ServioColors.textPrimaryLight,
      onSurfaceVariant: ServioColors.textSecondaryLight,
      outline: ServioColors.borderLight,
      outlineVariant: ServioColors.backgroundSoftLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: ServioColors.backgroundLight,
      splashFactory: NoSplash.splashFactory,
      textTheme: textTheme.apply(
        bodyColor: ServioColors.textPrimaryLight,
        displayColor: ServioColors.textPrimaryLight,
      ),
      colorScheme: colorScheme,
    );

    return _buildTheme(
      base,
      const ServioThemeExtension(
        backgroundSoft: ServioColors.backgroundSoftLight,
        surfaceAlt: ServioColors.surfaceAltLight,
        surfaceRaised: ServioColors.surfaceLight,
        textSecondary: ServioColors.textSecondaryLight,
        border: ServioColors.borderLight,
        accent: ServioColors.accent,
        accentLight: ServioColors.accentLight,
        neutralWarm: ServioColors.neutralWarm,
        success: ServioColors.success,
        warning: ServioColors.warning,
        info: ServioColors.info,
        danger: ServioColors.danger,
      ),
      isDark: false,
    );
  }

  static ThemeData dark() {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.48,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.17,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    );

    // Dark mode: primary flips to warm sand (#E3D5CA) — the design's dark-primary token.
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ServioColors.neutralWarm,
      onPrimary: ServioColors.navyDark,
      primaryContainer: ServioColors.surfaceDark,
      onPrimaryContainer: ServioColors.neutralWarm,
      secondary: ServioColors.accent,
      onSecondary: ServioColors.navyDark,
      secondaryContainer: ServioColors.surfaceRaisedDark,
      onSecondaryContainer: ServioColors.accentLight,
      tertiary: ServioColors.accentLight,
      onTertiary: ServioColors.navyDark,
      error: ServioColors.danger,
      onError: Colors.white,
      surface: ServioColors.surfaceDark,
      onSurface: ServioColors.textPrimaryDark,
      onSurfaceVariant: ServioColors.textSecondaryDark,
      outline: ServioColors.borderDark,
      outlineVariant: ServioColors.surfaceRaisedDark,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: ServioColors.backgroundDark,
      splashFactory: NoSplash.splashFactory,
      textTheme: textTheme.apply(
        bodyColor: ServioColors.textPrimaryDark,
        displayColor: ServioColors.textPrimaryDark,
      ),
      colorScheme: colorScheme,
    );

    return _buildTheme(
      base,
      const ServioThemeExtension(
        backgroundSoft: ServioColors.backgroundSoftDark,  // #262B34 (was wrong before)
        surfaceAlt: ServioColors.surfaceAltDark,
        surfaceRaised: ServioColors.surfaceRaisedDark,
        textSecondary: ServioColors.textSecondaryDark,
        border: ServioColors.borderDark,
        accent: ServioColors.accent,
        accentLight: ServioColors.accentLight,
        neutralWarm: ServioColors.neutralWarm,
        success: ServioColors.success,
        warning: ServioColors.warning,
        info: ServioColors.info,
        danger: ServioColors.danger,
      ),
      isDark: true,
    );
  }

  static ThemeData _buildTheme(
    ThemeData base,
    ServioThemeExtension extension, {
    required bool isDark,
  }) {
    final borderSide = BorderSide(color: extension.border);
    final roundedFull = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ServioRadius.full),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[extension],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: base.colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ServioRadius.md),
          side: BorderSide(color: extension.border.withValues(alpha: isDark ? 0.45 : 1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extension.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: base.textTheme.labelLarge?.copyWith(color: extension.textSecondary),
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: extension.textSecondary),
        errorStyle: base.textTheme.labelSmall?.copyWith(color: extension.danger),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ServioRadius.sm),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ServioRadius.sm),
          borderSide: BorderSide(color: extension.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ServioRadius.sm),
          borderSide: BorderSide(color: extension.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ServioRadius.sm),
          borderSide: BorderSide(color: extension.danger, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: roundedFull,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          textStyle: base.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: roundedFull,
          side: BorderSide(color: extension.accent, width: 1.5),
          foregroundColor: extension.accent,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: extension.accent,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ServioRadius.full),
        ),
        side: BorderSide.none,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: extension.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: extension.backgroundSoft,
      ),
      dividerTheme: DividerThemeData(
        color: extension.border,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? extension.surfaceRaised : base.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isDark ? extension.surfaceRaised : base.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ServioRadius.xl),
          ),
        ),
      ),
    );
  }
}
