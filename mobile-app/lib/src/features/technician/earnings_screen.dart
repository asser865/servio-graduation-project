import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import 'availability_manager_screen.dart';
import 'job_queue_screen.dart';
import 'technician_dashboard_screen.dart';
import 'technician_profile_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _periodIndex = 0;
  static const List<String> _periods = <String>['This Week', 'This Month', 'All Time'];

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
          ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
          ServioBottomNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
          ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 2,
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TechnicianDashboardScreen(),
              ),
            );
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const JobQueueScreen(),
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
        title: const Text('Earnings'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List<Widget>.generate(_periods.length, (int index) {
                final active = index == _periodIndex;
                return GestureDetector(
                  onTap: () => setState(() => _periodIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? servio.accent : servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      _periods[index],
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: active ? Colors.white : servio.textSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ServioGradients.brand,
                borderRadius: BorderRadius.circular(ServioRadius.xl),
                boxShadow: ServioShadows.rest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total Earnings',
                    style: theme.textTheme.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '12,850 EGP',
                    style: theme.textTheme.displayLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pending: 1,200 EGP',
                    style: theme.textTheme.bodyMedium?.copyWith(color: ServioColors.accentLight),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Withdraw'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Overview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ServioCard(
                radius: ServioRadius.lg,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const <Widget>[
                    _BarColumn(label: 'Mon', height: 54, active: false),
                    _BarColumn(label: 'Tue', height: 82, active: true),
                    _BarColumn(label: 'Wed', height: 66, active: true),
                    _BarColumn(label: 'Thu', height: 110, active: true),
                    _BarColumn(label: 'Fri', height: 94, active: true),
                    _BarColumn(label: 'Sat', height: 70, active: false),
                    _BarColumn(label: 'Sun', height: 120, active: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Transactions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            const _TransactionCard(
              date: '26/03/2026',
              service: 'Kitchen faucet leak repair',
              customer: 'Mostafa Abdelaal',
              amount: '850 EGP',
              released: false,
            ),
            const SizedBox(height: 12),
            const _TransactionCard(
              date: '25/03/2026',
              service: 'Pipe inspection',
              customer: 'Nour Hany',
              amount: '420 EGP',
              released: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.label,
    required this.height,
    required this.active,
  });

  final String label;
  final double height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 22,
          height: height,
          decoration: BoxDecoration(
            color: active ? ServioColors.accent : ServioColors.neutralWarm,
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.servio.textSecondary),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.date,
    required this.service,
    required this.customer,
    required this.amount,
    required this.released,
  });

  final String date;
  final String service;
  final String customer;
  final String amount;
  final bool released;

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
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
                const SizedBox(height: 6),
                Text(service, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(customer, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                amount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: servio.accent),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ServioColors.tint(released ? servio.success : servio.warning),
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  released ? 'Released' : 'Pending',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: released ? servio.success : servio.warning,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
