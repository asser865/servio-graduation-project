import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../shared/account_screen.dart';
import 'customer_security_screen.dart';
import 'edit_profile_screen.dart';
import 'my_addresses_screen.dart';
import 'notification_settings_screen.dart';
import 'invoices_screen.dart';
import 'saved_payments_screen.dart';

class CustomerSettingsScreen extends StatelessWidget {
  const CustomerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    final isDark = themeProvider.mode == ThemeMode.dark ||
        (themeProvider.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    // Premium custom colors matching Stitch v2
    final profileBg = isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7);
    final profileIcon = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23);

    final securityBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF);
    final securityIcon = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    final notificationsBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.2) : const Color(0xFFFFF7ED);
    final notificationsIcon = isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);

    final darkModeBg = isDark ? const Color(0xFF262B34) : const Color(0xFFE4E2DF).withValues(alpha: 0.5);
    final darkModeIcon = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF45474B);

    final languageBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF);
    final languageIcon = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    final accountBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.2) : const Color(0xFFFEF2F2);
    final accountIcon = isDark ? const Color(0xFFF87171) : const Color(0xFFBA1A1A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
      ),
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: ServioSpacing.screenPadding,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Profile ──────────────────────────────────────────────────────
            const _SectionHeader(label: 'Profile'),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.person_rounded,
                  iconColor: profileIcon,
                  backgroundColor: profileBg,
                  label: 'Edit Profile',
                  subtitle: 'Name, photo, contact details',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.location_on_rounded,
                  iconColor: profileIcon,
                  backgroundColor: profileBg,
                  label: 'My Addresses',
                  subtitle: 'Saved home and work locations',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyAddressesScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.credit_card_rounded,
                  iconColor: profileIcon,
                  backgroundColor: profileBg,
                  label: 'My Payments',
                  subtitle: 'Manage saved cards and payment methods',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SavedPaymentsScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.description_rounded,
                  iconColor: profileIcon,
                  backgroundColor: profileBg,
                  label: 'Invoices & Receipts',
                  subtitle: 'View and download payment invoices',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InvoicesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Security ─────────────────────────────────────────────────────
            const _SectionHeader(label: 'Security'),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.shield_rounded,
                  iconColor: securityIcon,
                  backgroundColor: securityBg,
                  label: 'Security',
                  subtitle: 'Password, 2FA, login activity',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomerSecurityScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Preferences ───────────────────────────────────────────────────
            const _SectionHeader(label: 'Preferences'),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.notifications_rounded,
                  iconColor: notificationsIcon,
                  backgroundColor: notificationsBg,
                  label: 'Notifications',
                  subtitle: 'Alerts, reminders, updates',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                _SwitchTile(
                  icon: Icons.wb_sunny_rounded, // always wb_sunny matching Stitch redesign!
                  iconColor: darkModeIcon,
                  backgroundColor: darkModeBg,
                  label: 'Dark Mode',
                  subtitle: isDark ? 'Dark theme active' : 'Light theme active',
                  value: isDark,
                  onChanged: (bool v) => themeProvider.setMode(
                    v ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
                _DropdownTile(
                  icon: Icons.language_rounded,
                  iconColor: languageIcon,
                  backgroundColor: languageBg,
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
            const SizedBox(height: 12),

            // ── Account ───────────────────────────────────────────────────────
            const _SectionHeader(label: 'Account'),
            _SettingsGroup(
              borderColor: accountIcon.withValues(alpha: 0.2),
              children: <Widget>[
                _NavTile(
                  icon: Icons.person_remove_rounded,
                  iconColor: accountIcon,
                  backgroundColor: accountBg,
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
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: context.servio.textSecondary.withValues(alpha: 0.7),
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
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
    final theme = Theme.of(context);
    final dividerColor = servio.border.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? servio.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(34, 40, 49, 0.04),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 16,
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
    this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: <Widget>[
              _IconBox(
                icon: icon,
                color: iconColor,
                backgroundColor: backgroundColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? null : const Color(0xFF262B34),
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          fontSize: 13,
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
                color: servio.textSecondary.withValues(alpha: 0.7),
                size: 22,
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
    this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          children: <Widget>[
            _IconBox(
              icon: icon,
              color: iconColor,
              backgroundColor: backgroundColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? null : const Color(0xFF262B34),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'Inter',
                        fontSize: 13,
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
              activeColor: isDarkMode ? servio.neutralWarm : const Color(0xFF1A1D23),
              activeTrackColor: isDarkMode ? servio.neutralWarm.withValues(alpha: 0.3) : const Color(0xFF1A1D23).withValues(alpha: 0.3),
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
    this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: <Widget>[
          _IconBox(
            icon: icon,
            color: iconColor,
            backgroundColor: backgroundColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: isDarkMode ? null : const Color(0xFF262B34),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                color: isDarkMode ? theme.textTheme.bodyMedium?.color : const Color(0xFF6B6560),
              ),
              icon: const Icon(Icons.expand_more_rounded, size: 20),
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
  const _IconBox({
    required this.icon,
    required this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.12);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
