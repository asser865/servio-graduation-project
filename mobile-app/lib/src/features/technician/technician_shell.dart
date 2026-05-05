import 'package:flutter/material.dart';

import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'availability_manager_screen.dart';
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
    ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
    ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ServioTabShell(
      items: _items,
      initialIndex: initialIndex,
      pages: const <Widget>[
        TechnicianDashboardScreen(),
        JobQueueScreen(),
        EarningsScreen(),
        AvailabilityManagerScreen(),
        TechnicianSettingsProfileScreen(),
      ],
    );
  }
}
