import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

class ServioBottomNavItem {
  const ServioBottomNavItem({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Marks feature tabs such as Smart Match.
  ///
  /// All selected tabs now use the same accent gradient treatment so the
  /// bottom bar stays visually consistent.
  final bool highlighted;

  /// When > 0 a red dot badge is shown on the icon.
  final int badgeCount;
}

/// SERVIO floating bottom navigation bar.
///
/// Design spec:
/// - Floating pill: horizontal margin 16, bottom margin 12 (above safe area).
/// - Surface background + border-radius 24 + elevated shadow.
/// - Active tab: accent gradient pill with high-contrast icon + label.
/// - Inactive: textSecondary icon + label.
/// - Height: 64dp content area.
/// - Static selected state so the persistent bar does not animate on tab change.
///
/// This widget is always rendered inside a [Positioned] at the bottom of a
/// [Stack] in the shell scaffold. It does NOT include safe-area handling or
/// positioning margins — those are owned by the shell.
class ServioBottomNavigationBar extends StatelessWidget {
  const ServioBottomNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<ServioBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? servio.surfaceRaised : Theme.of(context).colorScheme.surface;

    final shadows =
        isDark ? ServioShadows.elevatedDark : ServioShadows.elevated;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: List<Widget>.generate(items.length, (int index) {
          final item = items[index];
          final isActive = index == currentIndex;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(index),
              child: _NavTab(
                item: item,
                isActive: isActive,
                servio: servio,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.isActive,
    required this.servio,
  });

  final ServioBottomNavItem item;
  final bool isActive;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? ServioColors.deepBrown : servio.textSecondary;
    final labelColor = iconColor;

    // Decide which icon widget to render (with badge, with pulse ring, or plain)
    Widget iconWidget = Icon(item.icon, size: 22, color: iconColor);

    if (item.badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: ServioColors.danger,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wrap highlighted (Smart Match) icon with radar-ping ring when not active
    if (item.highlighted && !isActive) {
      iconWidget = _SmartMatchPing(child: iconWidget);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: isActive ? ServioGradients.accent : null,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(ServioRadius.navItem),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            iconWidget,
            const SizedBox(height: 4),
            SizedBox(
              height: 13,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 10,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expanding radar-ping ring that pulses behind the Smart Match icon.
///
/// A single ring grows from 0.5× to 1.8× and fades from 35% to 0% opacity
/// over 2 400 ms, then immediately repeats — giving a continuous "live" feel
/// without being distracting.
class _SmartMatchPing extends StatefulWidget {
  const _SmartMatchPing({required this.child});

  final Widget child;

  @override
  State<_SmartMatchPing> createState() => _SmartMatchPingState();
}

class _SmartMatchPingState extends State<_SmartMatchPing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _scale = Tween<double>(begin: 0.5, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SizedBox constrains layout to icon size (22×22); the ring visually
    // overflows via Transform.scale without adding layout height.
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? _) {
              return Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ServioColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}
