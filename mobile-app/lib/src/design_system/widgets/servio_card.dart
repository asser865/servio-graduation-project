import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

class ServioCard extends StatelessWidget {
  const ServioCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(ServioSpacing.cardPadding),
    this.radius = ServioRadius.md,
    this.elevated = false,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return AnimatedContainer(
      duration: ServioMotion.micro,
      curve: ServioMotion.curve,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? servio.border),
        boxShadow: elevated ? ServioShadows.elevated : ServioShadows.rest,
      ),
      child: child,
    );
  }
}
