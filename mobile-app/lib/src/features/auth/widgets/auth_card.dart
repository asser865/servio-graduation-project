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
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x12FFFFFF) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0x1CFFFFFF) : ServioColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        boxShadow: isDark ? null : ServioShadows.elevated,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
