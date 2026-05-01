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
import '../marketing/privacy_policy_screen.dart';
import '../marketing/terms_of_service_screen.dart';
import 'availability_manager_screen.dart';
import 'earnings_screen.dart';
import 'job_queue_screen.dart';
import 'technician_dashboard_screen.dart';
import 'technician_settings_screen.dart';
import 'verification_upload_screen.dart';

class TechnicianSettingsProfileScreen extends StatelessWidget {
  const TechnicianSettingsProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: ServioColors.deepBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
          ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
          ServioBottomNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
          ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 4,
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
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AvailabilityManagerScreen(),
              ),
            );
          }
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Hero header – edge to edge ─────────────────────────────────
            _ProfileHeader(
              initials: account?.initials ?? 'T',
              name: account?.name ?? 'Technician',
              email: account?.email ?? '',
              role: 'Technician',
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
                    _Stat(value: '48', label: 'Jobs'),
                    _Stat(value: '4.9', label: 'Rating'),
                    _Stat(value: '2023', label: 'Since'),
                  ]),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Professional details ──────────────────────────────────
                  const _SectionHeader(label: 'Professional'),
                  _ProfessionalCard(context: context),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Verification ──────────────────────────────────────────
                  const _SectionHeader(label: 'Verification'),
                  _VerificationCard(context: context),
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
                            builder: (_) => const TechnicianSettingsScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.flag_outlined,
                        iconColor: context.servio.warning,
                        label: 'Report a Problem',
                        subtitle: 'Send us feedback or issues',
                        onTap: () => _showPlaceholder(context, 'Report a Problem'),
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
                            builder: (_) => const RoleSelectionScreen(),
                          ),
                          (Route<dynamic> _) => false,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String feature) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(feature),
        content: Text('$feature is coming soon.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Professional details card ─────────────────────────────────────────────────

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final servio = ctx.servio;
    final theme = Theme.of(ctx);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Specialties',
            style: theme.textTheme.labelLarge?.copyWith(color: servio.textSecondary),
          ),
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
          _DetailRow(label: 'Service Area', value: 'Cairo · Giza · New Cairo'),
          const SizedBox(height: 10),
          _DetailRow(label: 'Hourly Rate', value: '350 EGP / hr'),
        ],
      ),
    );
  }
}

// ── Verification card ─────────────────────────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final servio = ctx.servio;
    final theme = Theme.of(ctx);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Verification Status', style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          _StatusRow(
            label: 'National ID License',
            status: 'Verified',
            success: true,
            servio: servio,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            label: 'Insurance Certificate',
            status: 'Verified',
            success: true,
            servio: servio,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            label: 'Background Check',
            status: 'Under Review',
            success: false,
            servio: servio,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VerificationUploadScreen(),
                ),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Manage Documents'),
              style: OutlinedButton.styleFrom(
                foregroundColor: servio.accent,
                side: BorderSide(color: servio.accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                ),
              ),
            ),
          ),
        ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(ServioRadius.full),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
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
    final dividerColor = context.servio.border.withValues(alpha: 0.5);

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

// ── Mini chip (specialty tag) ─────────────────────────────────────────────────

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
        border: Border.all(color: servio.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: servio.accent),
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

// ── Status row (verification) ─────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.status,
    required this.success,
    required this.servio,
  });

  final String label;
  final String status;
  final bool success;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          success ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: success ? servio.success : servio.warning,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
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
