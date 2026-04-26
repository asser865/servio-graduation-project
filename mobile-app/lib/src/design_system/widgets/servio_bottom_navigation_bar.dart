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

  /// When true the active state uses the accent gradient instead of a
  /// plain background fill — used for the Smart Match AI tab.
  final bool highlighted;

  /// When > 0 a red dot badge is shown on the icon.
  final int badgeCount;
}

/// SERVIO bottom navigation bar.
///
/// Design spec:
/// - Edge-to-edge, no horizontal floating margin.
/// - Surface background + 1px top border (matches web nav separator).
/// - Active tab: accent-coloured icon + label, subtle backgroundSoft pill.
/// - Active highlighted tab: accent gradient pill (AI feature).
/// - Inactive: textSecondary icon + label.
/// - Height: 56dp content + SafeArea bottom inset.
/// - Spring animation on active state transition.
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 1px top divider — matches web nav border
        Divider(
          height: 1,
          thickness: 1,
          color: servio.border.withValues(alpha: isDark ? 0.35 : 0.7),
        ),
        ColoredBox(
          color: surface,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
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
            ),
          ),
        ),
      ],
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
    final iconColor = isActive
        ? (item.highlighted ? Colors.white : servio.accent)
        : servio.textSecondary;
    final labelColor = iconColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: AnimatedContainer(
        duration: ServioMotion.tabSwitch,
        curve: ServioMotion.spring,
        decoration: BoxDecoration(
          gradient:
              isActive && item.highlighted ? ServioGradients.accent : null,
          color: isActive && !item.highlighted
              ? servio.backgroundSoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ServioRadius.navItem),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedScale(
              scale: isActive ? 1.0 : 0.92,
              duration: ServioMotion.tabSwitch,
              curve: ServioMotion.spring,
              child: item.badgeCount > 0
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Icon(item.icon, size: 22, color: iconColor),
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
                    )
                  : Icon(item.icon, size: 22, color: iconColor),
            ),
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
