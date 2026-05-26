import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../auth/auth_landing_screen.dart';
import '../marketing/about_screen.dart';
import '../marketing/faq_screen.dart';
import '../marketing/contact_screen.dart';
import 'support_screen.dart';
import '../marketing/privacy_policy_screen.dart';
import '../marketing/terms_of_service_screen.dart';
import '../shared/report_problem_screen.dart';
import 'customer_settings_screen.dart';
import 'my_bookings_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;
    final bookingsCount = context.watch<BookingsProvider?>()?.all.length ?? 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    final activityBg = isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7);
    final activityIcon = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23);

    final appBg = isDark ? const Color(0xFF262B34) : const Color(0xFFE4E2DF).withValues(alpha: 0.5);
    final appIcon = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF45474B);

    final supportBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.2) : const Color(0xFFFFF7ED);
    final supportIcon = isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);

    final legalBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF);
    final legalIcon = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: const <Widget>[],
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: ServioSpacing.screenPadding,
          right: ServioSpacing.screenPadding,
          top: 16,
          bottom: 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: servio.border.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(26, 29, 37, 0.03),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: servio.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF262B34) : Colors.white,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                account?.initials ?? 'U',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9A8C73),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF262B34) : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account?.name ?? 'Guest User',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 14,
                                  color: servio.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Member since 2025',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: servio.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatItem('Bookings', '$bookingsCount', isDark, context),
                      const SizedBox(width: 10),
                      _buildStatItem('Reviews', '0', isDark, context),
                      const SizedBox(width: 10),
                      _buildStatItem('Spent', '1.2k EGP', isDark, context),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(label: 'Activity'),
            _MenuGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.history_rounded,
                  iconColor: activityIcon,
                  backgroundColor: activityBg,
                  label: 'Bookings',
                  subtitle: 'Past and upcoming bookings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyBookingsScreen(initialTabIndex: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionHeader(label: 'App'),
            _MenuGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.settings_rounded,
                  iconColor: appIcon,
                  backgroundColor: appBg,
                  label: 'Settings',
                  subtitle: 'Profile, security, preferences',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomerSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionHeader(label: 'Support'),
            _MenuGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.report_problem_rounded,
                  iconColor: supportIcon,
                  backgroundColor: supportBg,
                  label: 'Report a Problem',
                  subtitle: 'Send us feedback or issues',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportProblemScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.shield_rounded,
                  iconColor: supportIcon,
                  backgroundColor: supportBg,
                  label: 'Support & Cases',
                  subtitle: 'Disputes & resolved cases',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupportScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.contact_support_rounded,
                  iconColor: supportIcon,
                  backgroundColor: supportBg,
                  label: 'Contact Us',
                  subtitle: 'Get help from our team',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ContactScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionHeader(label: 'Legal'),
            _MenuGroup(
              children: <Widget>[
                _NavTile(
                  icon: Icons.info_rounded,
                  iconColor: legalIcon,
                  backgroundColor: legalBg,
                  label: 'About SERVIO',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.description_rounded,
                  iconColor: legalIcon,
                  backgroundColor: legalBg,
                  label: 'Terms of Service',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsOfServiceScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.privacy_tip_rounded,
                  iconColor: legalIcon,
                  backgroundColor: legalBg,
                  label: 'Privacy Policy',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.quiz_rounded,
                  iconColor: legalIcon,
                  backgroundColor: legalBg,
                  label: 'FAQ',
                  subtitle: 'Frequently asked questions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FaqScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _LogoutButton(
              onTap: () async {
                await context.read<SessionProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuthLandingScreen(),
                    ),
                    (Route<dynamic> _) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark, BuildContext context) {
    final servio = context.servio;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: servio.border.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
                color: servio.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

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
                color: servio.textSecondary.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Semantics(
      button: true,
      label: 'Log Out',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: servio.danger.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            border: Border.all(color: servio.danger.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.logout_rounded, color: servio.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                'Log Out',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: servio.danger,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
