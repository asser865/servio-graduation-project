import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../messages/messages_screen.dart';
import 'ai_smart_match_screen.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';
import 'services_marketplace_screen.dart';

/// Top-level shell for the customer section.
///
/// Owns the persistent floating bottom navigation bar and hosts all five
/// customer tabs in an [IndexedStack] so tab widgets stay alive across
/// switches — no rebuild, no navigation-bar flicker.
///
/// Floating nav bar: 16px horizontal margin, 12px above safe-area bottom,
/// 64dp height, 24dp border-radius, elevated shadow.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _currentIndex;

  static const double _navHeight = 64;
  static const double _navMarginH = 16;
  static const double _navMarginBottom = 12;

  // Total bottom space reserved so scroll views don't hide behind the nav bar.
  static const double _navReservedHeight = _navHeight + _navMarginBottom + _navMarginBottom;

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
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeBottom = mq.padding.bottom;
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          // Propagate extra bottom padding to all tab children so their
          // scroll views end above the floating nav bar.
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(
                bottom: safeBottom + _navReservedHeight,
              ),
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: const <Widget>[
                CustomerHomeScreen(),
                ServicesMarketplaceScreen(),
                AiSmartMatchScreen(),
                MessagesScreen(),
                CustomerProfileScreen(),
              ],
            ),
          ),

          // Floating navigation bar
          Positioned(
            left: _navMarginH,
            right: _navMarginH,
            bottom: safeBottom + _navMarginBottom,
            child: ServioBottomNavigationBar(
              items: navItems,
              currentIndex: _currentIndex,
              onTap: (int index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}
