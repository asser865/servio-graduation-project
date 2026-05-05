import 'package:flutter/material.dart';

import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import 'availability_manager_screen.dart';
import 'earnings_screen.dart';
import 'job_queue_screen.dart';
import 'technician_dashboard_screen.dart';
import 'technician_profile_screen.dart';

/// Top-level shell for the technician section.
///
/// Owns the persistent floating bottom navigation bar and hosts all five
/// technician tabs in an [IndexedStack] so tab widgets stay alive across
/// switches — no rebuild, no navigation-bar flicker.
///
/// Floating nav bar: 16px horizontal margin, 12px above safe-area bottom,
/// 64dp height, 24dp border-radius, elevated shadow.
class TechnicianShell extends StatefulWidget {
  const TechnicianShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  late int _currentIndex;

  static const double _navHeight = 64;
  static const double _navMarginH = 16;
  static const double _navMarginBottom = 12;

  static const double _navReservedHeight = _navHeight + _navMarginBottom + _navMarginBottom;

  static const List<ServioBottomNavItem> _items = <ServioBottomNavItem>[
    ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
    ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
    ServioBottomNavItem(
        icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
    ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
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
                TechnicianDashboardScreen(),
                JobQueueScreen(),
                EarningsScreen(),
                AvailabilityManagerScreen(),
                TechnicianSettingsProfileScreen(),
              ],
            ),
          ),

          // Floating navigation bar
          Positioned(
            left: _navMarginH,
            right: _navMarginH,
            bottom: safeBottom + _navMarginBottom,
            child: ServioBottomNavigationBar(
              items: _items,
              currentIndex: _currentIndex,
              onTap: (int index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}
