import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'availability_manager_screen.dart';
import 'earnings_screen.dart';
import 'job_details_screen.dart';
import 'technician_profile_screen.dart';

class JobQueueScreen extends StatefulWidget {
  const JobQueueScreen({super.key});

  @override
  State<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends State<JobQueueScreen> {
  int _tabIndex = 0;
  static const List<String> _tabs = <String>['Pending', 'Confirmed', 'In Progress', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
          ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
          ServioBottomNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
          ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 1,
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).pop();
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EarningsScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AvailabilityManagerScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TechnicianSettingsProfileScreen(),
              ),
            );
          }
        },
      ),
      appBar: AppBar(
        title: const Text('Job Queue'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Row(
                children: List<Widget>.generate(_tabs.length, (int index) {
                  final active = index == _tabIndex;
                  final counts = <String>['3', '2', '1', '11'];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = index),
                      child: AnimatedContainer(
                        duration: ServioMotion.micro,
                        curve: ServioMotion.curve,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? Theme.of(context).colorScheme.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              _tabs[index],
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: active ? servio.accent : servio.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ServioColors.tint(
                                  index == 0
                                      ? servio.warning
                                      : index == 3
                                          ? servio.success
                                          : servio.info,
                                ),
                                borderRadius: BorderRadius.circular(ServioRadius.full),
                              ),
                              child: Text(
                                counts[index],
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: index == 0
                                          ? servio.warning
                                          : index == 3
                                              ? servio.success
                                              : servio.info,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: 4,
                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  return _JobCard(
                    tabIndex: _tabIndex,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JobDetailsScreen(statusIndex: _tabIndex),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.tabIndex,
    required this.onOpen,
  });

  final int tabIndex;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final labels = <String>['Pending', 'Confirmed', 'In Progress', 'Completed'];
    final types = <ServioStatusChipType>[
      ServioStatusChipType.warning,
      ServioStatusChipType.info,
      ServioStatusChipType.info,
      ServioStatusChipType.success,
    ];

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: ServioGradients.warm,
                  shape: BoxShape.circle,
                  border: Border.all(color: servio.accent, width: 2),
                ),
                child: const Center(child: Text('M')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Mostafa Abdelaal', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Kitchen faucet leak repair',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
              ServioStatusChip(
                label: labels[tabIndex],
                type: types[tabIndex],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'New Cairo • 10:00 AM • 850 EGP',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 14),
          if (tabIndex == 0)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: servio.success),
                      foregroundColor: servio.success,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: servio.danger),
                      foregroundColor: servio.danger,
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onOpen,
                child: const Text('View Details'),
              ),
            ),
        ],
      ),
    );
  }
}
