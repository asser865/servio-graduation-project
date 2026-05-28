import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import 'technician_change_password_screen.dart';

class TechnicianSecurityScreen extends StatelessWidget {
  const TechnicianSecurityScreen({super.key});

  void _showPlaceholder(BuildContext context, String feature) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          feature,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$feature is coming soon.',
          style: const TextStyle(
            fontFamily: 'Inter',
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Premium custom HSL colors matching other settings pages
    final securityBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF);
    final securityIcon = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: ServioSpacing.screenPadding,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Security Settings',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your credentials and monitor account access securely.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontSize: 14,
                color: servio.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: securityIcon,
                  backgroundColor: securityBg,
                  label: 'Change Password',
                  subtitle: 'Update your login password regularly.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TechnicianChangePasswordScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.verified_user_outlined,
                  iconColor: securityIcon,
                  backgroundColor: securityBg,
                  label: 'Two-Factor Authentication',
                  subtitle: 'Add an extra layer of security.',
                  onTap: () => _showPlaceholder(context, 'Two-Factor Authentication'),
                ),
                _NavTile(
                  icon: Icons.sms_outlined,
                  iconColor: securityIcon,
                  backgroundColor: securityBg,
                  label: 'Enable SMS Authentication',
                  subtitle: 'Receive access codes on your phone.',
                  onTap: () => _showPlaceholder(context, 'SMS Authentication'),
                ),
                _NavTile(
                  icon: Icons.history_rounded,
                  iconColor: securityIcon,
                  backgroundColor: securityBg,
                  label: 'Login Activity',
                  subtitle: 'Monitor active logins on other devices.',
                  onTap: () => _showPlaceholder(context, 'Login Activity'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped card container ────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
  });

  final List<Widget> children;

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
          color: servio.border.withValues(alpha: 0.3),
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
