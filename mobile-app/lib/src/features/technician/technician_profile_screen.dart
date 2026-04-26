import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../auth/role_selection_screen.dart';
import '../marketing/about_screen.dart';
import '../marketing/contact_screen.dart';
import 'verification_upload_screen.dart';

class TechnicianSettingsProfileScreen extends StatelessWidget {
  const TechnicianSettingsProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.mode == ThemeMode.dark ||
        (themeProvider.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
          ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
          ServioBottomNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
          ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
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
                          account?.initials ?? 'T',
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
                Text(account?.name ?? 'Technician', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  account?.email ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: const <Widget>[
                Expanded(child: _ProfileStat(value: '48', label: 'Jobs')),
                Expanded(child: _ProfileStat(value: '4.9', label: 'Rating')),
                Expanded(child: _ProfileStat(value: '2023', label: 'Since')),
              ],
            ),
            const SizedBox(height: 24),
            Text('Professional Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Specialties', style: theme.textTheme.labelLarge?.copyWith(color: servio.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const <Widget>[
                      _MiniChip(label: 'Plumbing'),
                      _MiniChip(label: 'Leak Repair'),
                      _MiniChip(label: 'Installations'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingRow(label: 'Service Area', value: 'Cairo - Giza - New Cairo'),
                  _SettingRow(label: 'Hourly Rate', value: '350 EGP / hour'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Verification Status', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 14),
                  const _StatusRow(label: 'National ID License', status: 'Verified', success: true),
                  const SizedBox(height: 10),
                  const _StatusRow(label: 'Insurance Certificate', status: 'Verified', success: true),
                  const SizedBox(height: 10),
                  const _StatusRow(label: 'Background Check', status: 'Under Review', success: false),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VerificationUploadScreen(),
                        ),
                      );
                    },
                    child: const Text('Manage Documents'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Settings', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              onToggleDark: (bool v) => themeProvider.setMode(
                v ? ThemeMode.dark : ThemeMode.light,
              ),
              onLogout: () async {
                await context.read<SessionProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (Route<dynamic> _) => false,
                  );
                }
              },
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: servio.accent),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.status,
    required this.success,
  });

  final String label;
  final String status;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Row(
      children: <Widget>[
        Icon(
          success ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: success ? servio.success : servio.warning,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          status,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: success ? servio.success : servio.warning,
              ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.isDark,
    required this.onToggleDark,
    required this.onLogout,
  });

  final bool isDark;
  final ValueChanged<bool> onToggleDark;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          const _SimpleSetting(label: 'Edit Profile'),
          const _SimpleSetting(label: 'Notification Settings'),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: <Widget>[
                const Expanded(child: Text('Dark Mode')),
                Switch(
                  value: isDark,
                  onChanged: onToggleDark,
                  activeColor: servio.accent,
                ),
              ],
            ),
          ),
          const _SimpleSetting(label: 'Help Center'),
          _SimpleSetting(
            label: 'About Us',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const AboutScreen(),
              ));
            },
          ),
          _SimpleSetting(
            label: 'Contact Us',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ContactScreen(),
              ));
            },
          ),
          GestureDetector(
            onTap: onLogout,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Log Out',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: servio.danger,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleSetting extends StatelessWidget {
  const _SimpleSetting({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Icon(Icons.chevron_right_rounded, color: servio.textSecondary),
          ],
        ),
      ),
    );
  }
}
