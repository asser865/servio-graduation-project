import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../auth/auth_landing_screen.dart';
import '../marketing/about_screen.dart';
import '../marketing/contact_screen.dart';
import '../marketing/privacy_policy_screen.dart';
import '../marketing/terms_of_service_screen.dart';
import '../messages/messages_screen.dart';
import 'customer_settings_screen.dart';
import 'my_bookings_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      // AppBar shares the header gradient top colour for a seamless look.
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: ServioColors.deepBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Hero header – edge to edge ─────────────────────────────────
            _ProfileHeader(
              initials: account?.initials ?? 'U',
              name: account?.name ?? 'Guest',
              email: account?.email ?? '',
              role: 'Customer',
            ),

            // ── Scrollable content ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                24,
                ServioSpacing.screenPadding,
                ServioSpacing.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Stats
                  _StatsRow(stats: const <_Stat>[
                    _Stat(value: '12', label: 'Bookings'),
                    _Stat(value: '8', label: 'Reviews'),
                    _Stat(value: '2025', label: 'Since'),
                  ]),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Activity ─────────────────────────────────────────────
                  const _SectionHeader(label: 'Activity'),
                  _MenuGroup(
                    children: <Widget>[
                      _NavTile(
                        icon: Icons.history_rounded,
                        iconColor: context.servio.accent,
                        label: 'History',
                        subtitle: 'Past and upcoming bookings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const MyBookingsScreen(initialTabIndex: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── App ───────────────────────────────────────────────────
                  const _SectionHeader(label: 'App'),
                  _MenuGroup(
                    children: <Widget>[
                      _NavTile(
                        icon: Icons.settings_outlined,
                        iconColor: context.servio.accent,
                        label: 'Settings',
                        subtitle: 'Profile, security, preferences',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CustomerSettingsScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.flag_outlined,
                        iconColor: context.servio.warning,
                        label: 'Report a Problem',
                        subtitle: 'Send us feedback or issues',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MessagesScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.headset_mic_outlined,
                        iconColor: context.servio.info,
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
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Legal ─────────────────────────────────────────────────
                  const _SectionHeader(label: 'Legal'),
                  _MenuGroup(
                    children: <Widget>[
                      _NavTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: context.servio.accent,
                        label: 'About SERVIO',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.description_outlined,
                        iconColor: context.servio.accent,
                        label: 'Terms of Service',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: context.servio.accent,
                        label: 'Privacy Policy',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Logout ────────────────────────────────────────────────
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
                  SizedBox(height: 24 + bottomInset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero profile header ───────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
  });

  final String initials;
  final String name;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(gradient: ServioGradients.brand),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 2.5),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ServioColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          if (email.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              email,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(ServioRadius.full),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              role,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _Stat {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final dividerColor = servio.border.withValues(alpha: 0.6);

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < stats.length; i++) ...<Widget>[
            Expanded(child: _StatItem(stat: stats[i])),
            if (i != stats.length - 1)
              SizedBox(
                height: 36,
                child: VerticalDivider(color: dividerColor, width: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Column(
      children: <Widget>[
        Text(
          stat.value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: servio.accent, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: servio.textSecondary),
        ),
      ],
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

// ── Menu group (card container) ───────────────────────────────────────────────

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        context.servio.border.withValues(alpha: 0.5);

    return ServioCard(
      radius: ServioRadius.lg,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              children[i],
              if (i != children.length - 1)
                Divider(height: 1, indent: 56, color: dividerColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: servio.textSecondary, size: 20),
            ],
          ),
        ),
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

// ── Logout button ─────────────────────────────────────────────────────────────

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
            border:
                Border.all(color: servio.danger.withValues(alpha: 0.35)),
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
