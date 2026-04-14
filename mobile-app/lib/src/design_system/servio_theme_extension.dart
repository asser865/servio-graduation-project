import 'package:flutter/material.dart';

@immutable
class ServioThemeExtension extends ThemeExtension<ServioThemeExtension> {
  const ServioThemeExtension({
    required this.backgroundSoft,
    required this.surfaceAlt,
    required this.surfaceRaised,
    required this.textSecondary,
    required this.border,
    required this.accent,
    required this.accentLight,
    required this.neutralWarm,
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
  });

  final Color backgroundSoft;
  final Color surfaceAlt;
  final Color surfaceRaised;
  final Color textSecondary;
  final Color border;
  final Color accent;
  final Color accentLight;
  final Color neutralWarm;
  final Color success;
  final Color warning;
  final Color info;
  final Color danger;

  @override
  ThemeExtension<ServioThemeExtension> copyWith({
    Color? backgroundSoft,
    Color? surfaceAlt,
    Color? surfaceRaised,
    Color? textSecondary,
    Color? border,
    Color? accent,
    Color? accentLight,
    Color? neutralWarm,
    Color? success,
    Color? warning,
    Color? info,
    Color? danger,
  }) {
    return ServioThemeExtension(
      backgroundSoft: backgroundSoft ?? this.backgroundSoft,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      neutralWarm: neutralWarm ?? this.neutralWarm,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      danger: danger ?? this.danger,
    );
  }

  @override
  ThemeExtension<ServioThemeExtension> lerp(
    covariant ThemeExtension<ServioThemeExtension>? other,
    double t,
  ) {
    if (other is! ServioThemeExtension) {
      return this;
    }

    return ServioThemeExtension(
      backgroundSoft: Color.lerp(backgroundSoft, other.backgroundSoft, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      neutralWarm: Color.lerp(neutralWarm, other.neutralWarm, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension ServioThemeX on BuildContext {
  ServioThemeExtension get servio {
    return Theme.of(this).extension<ServioThemeExtension>()!;
  }
}
