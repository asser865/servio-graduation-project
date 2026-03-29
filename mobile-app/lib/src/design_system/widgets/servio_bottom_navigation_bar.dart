import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

class ServioBottomNavItem {
  const ServioBottomNavItem({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
}

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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: isDark ? servio.surfaceRaised : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
            border: Border.all(
              color: servio.border.withValues(alpha: isDark ? 0.45 : 1),
            ),
            boxShadow: isDark ? null : ServioShadows.rest,
          ),
          child: Row(
            children: List<Widget>.generate(items.length, (int index) {
              final item = items[index];
              final isActive = index == currentIndex;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ServioRadius.xl),
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: ServioMotion.tabSwitch,
                      curve: ServioMotion.curve,
                      decoration: BoxDecoration(
                        gradient: isActive && item.highlighted ? ServioGradients.accent : null,
                        borderRadius: BorderRadius.circular(ServioRadius.xl),
                        color: isActive && !item.highlighted
                            ? servio.backgroundSoft
                            : Colors.transparent,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: item.highlighted ? 6 : 8,
                        horizontal: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            item.icon,
                            size: item.highlighted ? 24 : 22,
                            color: isActive
                                ? (item.highlighted ? Colors.white : servio.accent)
                                : servio.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: isActive
                                      ? (item.highlighted ? Colors.white : servio.accent)
                                      : servio.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
