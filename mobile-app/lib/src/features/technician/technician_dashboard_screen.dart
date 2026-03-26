import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'availability_manager_screen.dart';
import 'earnings_screen.dart';
import 'job_queue_screen.dart';
import 'technician_profile_screen.dart';
import '../shared/notifications_screen.dart';

class TechnicianDashboardScreen extends StatelessWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        currentIndex: 0,
        onTap: (int index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const JobQueueScreen(),
              ),
            );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Good Morning, Ahmed.', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          '26/03/2026',
                          style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                            boxShadow: ServioShadows.rest,
                          ),
                          child: Icon(Icons.notifications_none_rounded, color: servio.accent),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ServioColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const <Widget>[
                    _KpiCard(
                      title: 'Today\'s Earnings',
                      value: '850 EGP',
                      icon: Icons.payments_outlined,
                      color: ServioColors.accent,
                    ),
                    SizedBox(width: 12),
                    _KpiCard(
                      title: 'Pending Jobs',
                      value: '3',
                      icon: Icons.pending_actions_rounded,
                      color: ServioColors.warning,
                    ),
                    SizedBox(width: 12),
                    _KpiCard(
                      title: 'Completed This Week',
                      value: '11',
                      icon: Icons.task_alt_rounded,
                      color: ServioColors.success,
                    ),
                    SizedBox(width: 12),
                    _KpiCard(
                      title: 'Rating',
                      value: '4.9',
                      icon: Icons.star_border_rounded,
                      color: ServioColors.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                  border: Border.all(color: servio.warning, width: 2),
                  boxShadow: ServioShadows.rest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ServioStatusChip(
                      label: 'New Job Request',
                      type: ServioStatusChipType.warning,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: ServioGradients.warm,
                            shape: BoxShape.circle,
                            border: Border.all(color: servio.accent, width: 2),
                          ),
                          child: const Center(child: Text('MH')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Mostafa Abdelaal', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Kitchen faucet leak repair',
                                style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'New Cairo • 10:00 AM',
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Offered price: 850 EGP',
                      style: theme.textTheme.titleMedium?.copyWith(color: servio.accent),
                    ),
                    const SizedBox(height: 16),
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Recent Activity', style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              const _ActivityCard(
                service: 'Pipe inspection',
                customer: 'Nour Hany',
                amount: '420 EGP',
                statusLabel: 'Completed',
                statusType: ServioStatusChipType.success,
              ),
              const SizedBox(height: 12),
              const _ActivityCard(
                service: 'Electrical outlet fix',
                customer: 'Karim Adel',
                amount: '300 EGP',
                statusLabel: 'Confirmed',
                statusType: ServioStatusChipType.info,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.servio.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.service,
    required this.customer,
    required this.amount,
    required this.statusLabel,
    required this.statusType,
  });

  final String service;
  final String customer;
  final String amount;
  final String statusLabel;
  final ServioStatusChipType statusType;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(service, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  customer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
                const SizedBox(height: 8),
                ServioStatusChip(label: statusLabel, type: statusType),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: servio.accent),
          ),
        ],
      ),
    );
  }
}
