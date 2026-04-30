import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/users_api.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'earnings_screen.dart';
import 'job_queue_screen.dart';
import 'technician_dashboard_screen.dart';
import 'technician_profile_screen.dart';

class AvailabilityManagerScreen extends StatefulWidget {
  const AvailabilityManagerScreen({super.key});

  @override
  State<AvailabilityManagerScreen> createState() => _AvailabilityManagerScreenState();
}

class _AvailabilityManagerScreenState extends State<AvailabilityManagerScreen> {
  final Map<String, bool> _days = <String, bool>{
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': false,
    'Fri': true,
    'Sat': false,
    'Sun': true,
  };

  Future<void> _saveAvailability() async {
    final activeDays = _days.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    try {
      final client = context.read<ApiClient>();
      await UsersApi(client).updateAvailability(<String, dynamic>{
        'days': activeDays,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update availability.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final activeDays = _days.entries.where((MapEntry<String, bool> e) => e.value).toList();

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
          ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
          ServioBottomNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
          ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 3,
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
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EarningsScreen(),
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
        title: const Text('Availability'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.keys.map((String day) {
                final available = _days[day]!;
                return GestureDetector(
                  onTap: () => setState(() => _days[day] = !available),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: available ? servio.success : servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: available ? Colors.white : servio.textSecondary,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ...activeDays.map((MapEntry<String, bool> entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ServioCard(
                  radius: ServioRadius.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 14),
                      Row(
                        children: const <Widget>[
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(labelText: 'Available from', hintText: '09:00 AM'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(labelText: 'Until', hintText: '05:00 PM'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(onPressed: () {}, child: const Text('Add another range +')),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            ServioPrimaryButton(label: 'Save Availability', onPressed: _saveAvailability),
          ],
        ),
      ),
    );
  }
}
