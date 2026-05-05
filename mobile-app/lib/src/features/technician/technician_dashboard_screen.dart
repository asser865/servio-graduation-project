import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'earnings_screen.dart';
import 'job_queue_screen.dart';
import 'technician_profile_screen.dart';
import '../shared/notifications_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Technician Dashboard – Overview (matches website technician-dashboard.html)
// ─────────────────────────────────────────────────────────────────────────────

class TechnicianDashboardScreen extends StatelessWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;
    final firstName = (account?.name ?? 'Ahmed').split(' ').first;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: ServioColors.accent,
          onRefresh: () async => Future<void>.delayed(const Duration(seconds: 1)),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ServioSpacing.screenPadding,
              ServioSpacing.screenPadding,
              ServioSpacing.screenPadding,
              ServioSpacing.screenPadding + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Welcome Banner ────────────────────────────────
                _WelcomeBanner(firstName: firstName),
                const SizedBox(height: 24),

                // ── Stat Cards Grid ──────────────────────────────
                const _StatCardGrid(),
                const SizedBox(height: 24),

                // ── Incoming Requests ─────────────────────────────
                ServioSectionHeading(
                  title: 'Incoming Requests',
                  actionLabel: 'View all →',
                  onActionTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const JobQueueScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const _IncomingRequestCard(
                  service: 'Plumbing — Burst Pipe',
                  customer: 'Ahmed Hassan',
                  location: 'Cairo, Maadi',
                  price: '~EGP 350',
                  statusLabel: 'New',
                  statusType: ServioStatusChipType.warning,
                ),
                const SizedBox(height: 12),
                const _IncomingRequestCard(
                  service: 'Electrical — Panel Upgrade',
                  customer: 'Sara Mohamed',
                  location: 'Heliopolis',
                  price: '~EGP 600',
                  statusLabel: 'New',
                  statusType: ServioStatusChipType.warning,
                ),
                const SizedBox(height: 24),

                // ── Upcoming Schedule ─────────────────────────────
                const ServioSectionHeading(title: 'Upcoming Schedule'),
                const SizedBox(height: 12),
                const _ScheduleItem(day: '29', month: 'MAR', title: 'Plumbing — Burst Pipe', time: '10:00 AM', location: 'Maadi'),
                const SizedBox(height: 10),
                const _ScheduleItem(day: '30', month: 'MAR', title: 'Electrical — Panel Upgrade', time: '02:30 PM', location: 'Nasr City'),
                const SizedBox(height: 10),
                const _ScheduleItem(day: '02', month: 'APR', title: 'Air Conditioning', time: '09:00 AM', location: 'Heliopolis'),
                const SizedBox(height: 24),

                // ── Recent Activity ───────────────────────────────
                ServioSectionHeading(
                  title: 'Recent Activity',
                  actionLabel: 'View all →',
                  onActionTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const EarningsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const _ActivityCard(
                  service: 'Pipe inspection',
                  customer: 'Nour Hany',
                  amount: '420 EGP',
                  statusLabel: 'Completed',
                  statusType: ServioStatusChipType.success,
                ),
                const SizedBox(height: 12),
                const _ActivityCard(
                  service: 'Electrical outlet fix',
                  customer: 'Karim Adel',
                  amount: '300 EGP',
                  statusLabel: 'Confirmed',
                  statusType: ServioStatusChipType.info,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome Banner – matches website dash-welcome--tech
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.firstName});

  final String firstName;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        boxShadow: isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _greeting,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? ServioColors.navyDark.withValues(alpha: 0.7) : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back, $firstName!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: isDark ? ServioColors.navyDark : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You have 2 new job requests waiting.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? ServioColors.navyDark.withValues(alpha: 0.7) : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Notification bell
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? ServioColors.navyDark : Colors.white).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.notifications_none_rounded,
                        color: isDark ? ServioColors.navyDark : Colors.white,
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ServioColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick actions row
          Row(
            children: <Widget>[
              Expanded(
                child: _BannerActionButton(
                  label: 'View Jobs',
                  icon: Icons.work_outline_rounded,
                  filled: true,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const JobQueueScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BannerActionButton(
                  label: 'View Profile',
                  icon: Icons.person_outline_rounded,
                  filled: false,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TechnicianSettingsProfileScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  const _BannerActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? ServioColors.navyDark : Colors.white;
    final bg = filled
        ? fg.withValues(alpha: 0.2)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: filled ? null : Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Card Grid – matches website tech-stat-grid (6 cards → 2-col mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardGrid extends StatelessWidget {
  const _StatCardGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: const <Widget>[
            Expanded(child: _StatCard(
              label: 'Total Jobs', value: '47', change: '+3 this month',
              icon: Icons.check_box_outlined, iconColor: ServioColors.accent,
            )),
            SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'This Month', value: 'EGP 3,200', change: '+EGP 800 vs last',
              icon: Icons.payments_outlined, iconColor: ServioColors.success,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const <Widget>[
            Expanded(child: _StatCard(
              label: 'Avg Rating', value: '4.8', change: 'Based on 24 reviews',
              icon: Icons.star_border_rounded, iconColor: Color(0xFFF59E0B),
            )),
            SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Pending Requests', value: '2', change: 'Action needed',
              icon: Icons.pending_actions_rounded, iconColor: Color(0xFF6E56CF),
              changeColor: Color(0xFF6E56CF),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const <Widget>[
            Expanded(child: _StatCard(
              label: 'Pending Proposals', value: '2', change: 'Awaiting review',
              icon: Icons.assignment_outlined, iconColor: Color(0xFFF59E0B),
            )),
            SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Outstanding', value: '1,350 EGP', change: 'Due 31 Mar',
              icon: Icons.credit_card_rounded, iconColor: Color(0xFFD97706),
              changeColor: Color(0xFFD97706), highlight: true,
            )),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.iconColor,
    this.changeColor,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String change;
  final IconData icon;
  final Color iconColor;
  final Color? changeColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: highlight ? iconColor : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            change,
            style: theme.textTheme.labelSmall?.copyWith(
              color: changeColor ?? ServioColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incoming Request Card – matches website job-card-v2
// ─────────────────────────────────────────────────────────────────────────────

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.service,
    required this.customer,
    required this.location,
    required this.price,
    required this.statusLabel,
    required this.statusType,
  });

  final String service;
  final String customer;
  final String location;
  final String price;
  final String statusLabel;
  final ServioStatusChipType statusType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Icon(Icons.build_outlined, size: 20, color: servio.accent),
          ),
          const SizedBox(width: 12),
          // Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(service, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: <Widget>[
                    Text(customer, style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
                    Text('·', style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
                    Text(location, style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
                    Text('·', style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
                    Text(price, style: theme.textTheme.bodySmall?.copyWith(
                      color: servio.accent,
                      fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ServioStatusChip(label: statusLabel, type: statusType),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Item – matches website dash-schedule-item
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({
    required this.day,
    required this.month,
    required this.title,
    required this.time,
    required this.location,
  });

  final String day;
  final String month;
  final String title;
  final String time;
  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          // Date block
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  day,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: servio.accent,
                    height: 1,
                  ),
                ),
                Text(
                  month,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: servio.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary)),
                    ),
                    Text(
                      location,
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Card – preserved from original
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.service,
    required this.customer,
    required this.amount,
    required this.statusLabel,
    required this.statusType,
  });

  final String service;
  final String customer;
  final String amount;
  final String statusLabel;
  final ServioStatusChipType statusType;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(service, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  customer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
                const SizedBox(height: 8),
                ServioStatusChip(label: statusLabel, type: statusType),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: servio.accent),
          ),
        ],
      ),
    );
  }
}
