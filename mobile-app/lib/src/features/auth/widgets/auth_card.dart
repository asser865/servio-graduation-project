import 'package:flutter/material.dart';
import '../../../design_system/servio_tokens.dart';

/// Mode-aware form card for auth screens.
///
/// Dark mode: frosted glass — rgba(255,255,255,0.07) fill.
/// Light mode: white elevated card with soft shadow.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.frosted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x12FFFFFF)
            : (frosted ? Colors.white.withValues(alpha: 0.78) : Colors.white),
        border: Border.all(
          color: isDark
              ? const Color(0x1CFFFFFF)
              : (frosted
                  ? Colors.white.withValues(alpha: 0.86)
                  : ServioColors.borderLight),
        ),
        borderRadius:
            BorderRadius.circular(frosted ? ServioRadius.xl : ServioRadius.lg),
        boxShadow: isDark ? null : ServioShadows.elevated,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
