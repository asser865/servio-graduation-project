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
            item.badgeCount > 0
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
