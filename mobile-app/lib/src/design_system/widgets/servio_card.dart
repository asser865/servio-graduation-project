import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

/// SERVIO surface card with optional press interaction.
///
/// When [onTap] is provided the card scales to 0.98 on press,
/// matching the web's translateY(-2px) card-hover pattern adapted for touch.
class ServioCard extends StatefulWidget {
  const ServioCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(ServioSpacing.cardPadding),
    this.radius = ServioRadius.card,
    this.elevated = false,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  State<ServioCard> createState() => _ServioCardState();
}

class _ServioCardState extends State<ServioCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ServioMotion.fast,
      reverseDuration: ServioMotion.normal,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    final card = AnimatedContainer(
      duration: ServioMotion.micro,
      curve: ServioMotion.spring,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: widget.borderColor ??
              servio.border.withValues(alpha: isDark ? 0.45 : 1.0),
        ),
        boxShadow: widget.elevated
            ? (isDark ? ServioShadows.elevatedDark : ServioShadows.elevated)
            : (isDark ? ServioShadows.restDark : ServioShadows.rest),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return card;
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: card),
    );
  }
}
