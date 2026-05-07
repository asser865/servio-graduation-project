import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../messages/messages_screen.dart';
import 'ai_smart_match_screen.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';
import 'services_marketplace_screen.dart';

/// Top-level shell for the customer section.
///
/// The shared shell owns the persistent floating bottom navigation bar while
/// customer tab content changes inside an IndexedStack.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static const List<ServioBottomNavItem> _items = <ServioBottomNavItem>[
    ServioBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
    ServioBottomNavItem(icon: Icons.grid_view_rounded, label: 'Services'),
    ServioBottomNavItem(
      icon: Icons.auto_awesome_rounded,
      label: 'Smart Match',
      highlighted: true,
    ),
    ServioBottomNavItem(
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Messages',
    ),
    ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadMessages = context.watch<MessagesProvider>().totalUnread;

    final navItems = <ServioBottomNavItem>[
      _items[0],
      _items[1],
      _items[2],
      ServioBottomNavItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Messages',
        badgeCount: unreadMessages,
      ),
      _items[4],
    ];

    return ServioTabShell(
      items: navItems,
      initialIndex: initialIndex,
      pages: const <Widget>[
        CustomerHomeScreen(),
        ServicesMarketplaceScreen(),
        AiSmartMatchScreen(),
        MessagesScreen(),
        CustomerProfileScreen(),
      ],
    );
  }
}
