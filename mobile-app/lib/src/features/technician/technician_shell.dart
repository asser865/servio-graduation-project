import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../messages/messages_screen.dart';
import 'earnings_screen.dart';
import 'job_queue_screen.dart';
import 'technician_dashboard_screen.dart';
import 'technician_profile_screen.dart';

/// Top-level shell for the technician section.
///
/// The shared shell owns the persistent floating bottom navigation bar while
/// technician tab content changes inside an IndexedStack.
class TechnicianShell extends StatelessWidget {
  const TechnicianShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static const List<ServioBottomNavItem> _items = <ServioBottomNavItem>[
    ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
    ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
    ServioBottomNavItem(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Earnings',
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
        TechnicianDashboardScreen(),
        JobQueueScreen(),
        EarningsScreen(),
        MessagesScreen(),
        TechnicianSettingsProfileScreen(),
      ],
    );
  }
}
