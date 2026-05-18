import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../shared/account_screen.dart';
import 'technician_edit_profile_screen.dart';
import 'technician_notification_settings_screen.dart';
import 'technician_security_screen.dart';
import 'payout_summary_screen.dart';
import 'service_area_screen.dart';

class TechnicianSettingsScreen extends StatelessWidget {
  const TechnicianSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    final isDark = themeProvider.mode == ThemeMode.dark ||
        (themeProvider.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: ServioSpacing.screenPadding,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Profile ──────────────────────────────────────────────────────
            _SectionHeader(label: 'Profile'),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: servio.accent,
                  label: 'Edit Profile',
                  subtitle: 'Name, photo, skills, rate',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TechnicianEditProfileScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.map_outlined,
                  iconColor: servio.accent,
                  label: 'Service Area',
                  subtitle: 'Cities and neighborhoods you cover',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ServiceAreaScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: servio.accent,
                  label: 'Payout Summary',
                  subtitle: 'Track earnings, payouts, and completed jobs',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PayoutSummaryScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ServioSpacing.sectionGap),

            // ── Security ─────────────────────────────────────────────────────
            _SectionHeader(label: 'Security'),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.shield_outlined,
                  iconColor: servio.info,
                  label: 'Security',
                  subtitle: 'Password, 2FA, login activity',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TechnicianSecurityScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ServioSpacing.sectionGap),

            // ── Preferences ───────────────────────────────────────────────────
            _SectionHeader(label: 'Preferences'),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.notifications_outlined,
                  iconColor: servio.warning,
                  label: 'Notifications',
                  subtitle: 'Alerts, job updates, reminders',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const TechnicianNotificationSettingsScreen(),
                    ),
                  ),
                ),
                _SwitchTile(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_outlined,
                  iconColor: servio.accent,
                  label: 'Dark Mode',
                  subtitle: isDark ? 'Dark theme active' : 'Light theme active',
                  value: isDark,
                  onChanged: (bool v) => themeProvider.setMode(
                    v ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
                _DropdownTile(
                  icon: Icons.language_rounded,
                  iconColor: servio.info,
                  label: 'Language',
                  value: localeProvider.languageCode,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'en',
                      child: Text('English'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'ar',
                      child: Text('Arabic'),
                    ),
                  ],
                  onChanged: (String? v) {
                    if (v != null) localeProvider.setLocale(Locale(v));
                  },
                ),
              ],
            ),
            const SizedBox(height: ServioSpacing.sectionGap),

            // ── Account ───────────────────────────────────────────────────────
            _SectionHeader(label: 'Account'),
            _SettingsGroup(
              borderColor: servio.danger.withValues(alpha: 0.35),
              children: <Widget>[
                _NavTile(
                  icon: Icons.manage_accounts_outlined,
                  iconColor: servio.danger,
                  label: 'Account Management',
                  subtitle: 'Deactivate or delete your account',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.servio.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ── Grouped card container ────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
    this.borderColor,
  });

  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final dividerColor = servio.border.withValues(alpha: 0.5);

    return ServioCard(
      radius: ServioRadius.lg,
      borderColor: borderColor,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: dividerColor,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Navigation tile (chevron) ─────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.cardPadding,
            vertical: 13,
          ),
          child: Row(
            children: <Widget>[
              _IconBox(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: servio.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: servio.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Switch tile ───────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ServioSpacing.cardPadding,
          vertical: 10,
        ),
        child: Row(
          children: <Widget>[
            _IconBox(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: servio.accent,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dropdown tile ─────────────────────────────────────────────────────────────

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ServioSpacing.cardPadding,
        vertical: 10,
      ),
      child: Row(
        children: <Widget>[
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: theme.textTheme.bodyMedium,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon box ──────────────────────────────────────────────────────────────────

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
