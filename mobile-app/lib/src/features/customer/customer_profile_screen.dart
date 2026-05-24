import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../auth/auth_landing_screen.dart';
import '../marketing/about_screen.dart';
import '../marketing/faq_screen.dart';
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
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            // Hero header.
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileHeaderDelegate(
                topPadding: MediaQuery.paddingOf(context).top,
                initials: account?.initials ?? 'U',
                name: account?.name ?? 'Guest',
                email: account?.email ?? '',
                role: 'Customer',
              ),
            ),

            // Scrollable content.
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                24,
                ServioSpacing.screenPadding,
                ServioSpacing.screenPadding + 24 + bottomInset,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    // Stats
                    _StatsRow(stats: <_Stat>[
                      _Stat(value: '$bookingsCount', label: 'Bookings'),
                      const _Stat(value: '0', label: 'Reviews'),
                      const _Stat(value: '2025', label: 'Since'),
                    ]),
                    const SizedBox(height: ServioSpacing.sectionGap),

                    // ── Activity ─────────────────────────────────────────────
                    const _SectionHeader(label: 'Activity'),
                    _MenuGroup(
                      children: <Widget>[
                        _NavTile(
                          icon: Icons.history_rounded,
                          iconColor: context.servio.accent,
                          label: 'Bookings',
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
                              builder: (_) => const ReportProblemScreen(),
                            ),
                          ),
                        ),
                        _NavTile(
                          icon: Icons.shield_outlined,
                          iconColor: context.servio.info,
                          label: 'Support',
                          subtitle: 'Issues, disputes & resolved cases',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SupportScreen(),
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
                        _NavTile(
                          icon: Icons.quiz_outlined,
                          iconColor: context.servio.accent,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero profile header ───────────────────────────────────────────────────────

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileHeaderDelegate({
    required this.topPadding,
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
  });

  final double topPadding;
  final String initials;
  final String name;
  final String email;
  final String role;

  @override
  double get maxExtent => topPadding + 300;

  @override
  double get minExtent => topPadding + 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0).toDouble();
    final eased = ServioMotion.reveal.transform(progress);
    final expandedOpacity = (1 - progress * 1.45).clamp(0.0, 1.0).toDouble();
    final compactOpacity =
        ((progress - 0.34) / 0.66).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: ServioGradients.brand),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: maxExtent,
            child: Opacity(
              opacity: expandedOpacity,
              child: Transform.translate(
                offset: Offset(0, -24 * eased),
                child: _ExpandedProfileHeader(
                  initials: initials,
                  name: name,
                  email: email,
                  role: role,
                  topPadding: topPadding,
                ),
              ),
            ),
          ),
          Positioned(
            left: ServioSpacing.screenPadding,
            right: ServioSpacing.screenPadding,
            top: topPadding + 10,
            child: Opacity(
              opacity: compactOpacity,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - eased)),
                child: _CompactProfileHeader(
                  initials: initials,
                  name: name,
                  role: role,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        initials != oldDelegate.initials ||
        name != oldDelegate.name ||
        email != oldDelegate.email ||
        role != oldDelegate.role;
  }
}

class _ExpandedProfileHeader extends StatelessWidget {
  const _ExpandedProfileHeader({
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
    required this.topPadding,
  });

  final String initials;
  final String name;
  final String email;
  final String role;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding + 14, 24, 30),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Spacer(),
          _ProfileAvatar(initials: initials, size: 92, iconSize: 30),
          const SizedBox(height: 14),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          _ProfileRoleChip(role: role),
        ],
      ),
    );
  }
}

class _CompactProfileHeader extends StatelessWidget {
  const _CompactProfileHeader({
    required this.initials,
    required this.name,
    required this.role,
  });

  final String initials;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        _ProfileAvatar(initials: initials, size: 40, iconSize: 0),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ProfileRoleChip(role: role),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.size,
    required this.iconSize,
  });

  final String initials;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final borderWidth = size >= 80 ? 2.5 : 1.5;
    final textStyle = size >= 80
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.titleMedium;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: borderWidth,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: textStyle?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (iconSize > 0)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: ServioColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileRoleChip extends StatelessWidget {
  const _ProfileRoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        role,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              letterSpacing: 0.5,
            ),
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
