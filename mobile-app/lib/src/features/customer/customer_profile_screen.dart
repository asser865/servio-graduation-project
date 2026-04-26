import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../auth/role_selection_screen.dart';
import '../marketing/about_screen.dart';
import '../marketing/contact_screen.dart';
import '../messages/messages_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isDark = themeProvider.mode == ThemeMode.dark ||
        (themeProvider.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
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
                          account?.initials ?? 'U',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(color: ServioColors.deepBrown),
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
                        child: const Icon(Icons.camera_alt_outlined,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  account?.name ?? 'Guest',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  account?.email ?? '',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: const <Widget>[
                Expanded(child: _ProfileStat(value: '12', label: 'Bookings')),
                Expanded(child: _ProfileStat(value: '8', label: 'Reviews')),
                Expanded(child: _ProfileStat(value: '2025', label: 'Since')),
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
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                children: <Widget>[
                  _SwitchRow(
                    label: 'Dark Mode',
                    value: isDark,
                    onChanged: (bool v) => themeProvider.setMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SwitchRow(
                    label: localeProvider.isArabic
                        ? 'Language: العربية'
                        : 'Language: English',
                    value: localeProvider.isArabic,
                    onChanged: (_) => localeProvider.toggle(),
                  ),
                ],
              ),
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
                      builder: (_) => const ContactScreen(),
                    ),
                  );
                } else if (item == 'Report a Problem') {
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
            _SettingsCard(
              items: const <String>[
                'About SERVIO',
                'Terms of Service',
                'Privacy Policy',
              ],
              onItemTap: (String item) {
                if (item == 'About SERVIO') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                await context.read<SessionProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                        builder: (_) => const RoleSelectionScreen()),
                    (Route<dynamic> _) => false,
                  );
                }
              },
              child: Text(
                'Log Out',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: servio.danger, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
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
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: servio.accent),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: servio.accent,
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items, this.onItemTap});

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
                  Icon(Icons.chevron_right_rounded,
                      color: servio.textSecondary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
