import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../messages/messages_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
          ServioBottomNavItem(icon: Icons.grid_view_rounded, label: 'Services'),
          ServioBottomNavItem(icon: Icons.auto_awesome_rounded, label: 'Smart Match', highlighted: true),
          ServioBottomNavItem(icon: Icons.calendar_month_rounded, label: 'Bookings'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 4,
        onTap: (_) {},
      ),
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: ServioGradients.warm,
                        shape: BoxShape.circle,
                        border: Border.all(color: servio.accent, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          'MA',
                          style: theme.textTheme.headlineMedium?.copyWith(color: ServioColors.deepBrown),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: servio.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Mostafa Abdelaal', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Member since 2023',
                  style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: const <Widget>[
                Expanded(child: _ProfileStat(value: '12', label: 'Bookings')),
                Expanded(child: _ProfileStat(value: '8', label: 'Reviews')),
                Expanded(child: _ProfileStat(value: '2023', label: 'Since')),
              ],
            ),
            const SizedBox(height: 24),
            Text('Account', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _SettingsCard(
              items: <String>[
                'Edit Profile',
                'My Addresses',
                'Change Password',
                'Notification Settings',
              ],
            ),
            const SizedBox(height: 16),
            Text('Preferences', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _SettingsCard(
              items: <String>[
                'Dark Mode',
                'Language EN / AR',
              ],
            ),
            const SizedBox(height: 16),
            Text('Support', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _SettingsCard(
              items: const <String>[
                'Help Center',
                'Report a Problem',
                'Contact Us',
              ],
              onItemTap: (String item) {
                if (item == 'Contact Us') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MessagesScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Legal', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _SettingsCard(
              items: <String>[
                'Terms of Service',
                'Privacy Policy',
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Log Out',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: servio.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: servio.accent),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.items,
    this.onItemTap,
  });

  final List<String> items;
  final ValueChanged<String>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: items.map((String item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onTap: onItemTap == null ? null : () => onItemTap!(item),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(item)),
                  Icon(Icons.chevron_right_rounded, color: servio.textSecondary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
