import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/payments_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../../design_system/widgets/servio_skeleton.dart';
import 'earnings_screen.dart';
import 'job_details_screen.dart';
import 'job_queue_screen.dart';
import 'technician_profile_screen.dart';
import '../shared/notifications_screen.dart';
import '../../core/state/notifications_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Technician Dashboard – Overview (matches website technician-dashboard.html)
// ─────────────────────────────────────────────────────────────────────────────

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  List<BackendBooking> _jobs = [];
  EarningsSummary? _earnings;
  bool _loading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    final client = context.read<ApiClient>();
    final session = context.read<SessionProvider>();
    final workerId = session.account?.id.trim() ?? '';
    if (workerId.isEmpty || session.account?.role != UserRole.technician) return;

    try {
      final bookingsFuture = BookingsApi(client).getWorkerBookings(workerId: workerId);
      final earningsFuture = PaymentsApi(client).getEarnings();

      final results = await Future.wait([bookingsFuture, earningsFuture]);
      final jobs = (results[0] as List<BackendBooking>)
          .where((job) => job.workerId.trim() == workerId)
          .toList();
      final earnings = results[1] as EarningsSummary;

      if (mounted) {
        setState(() {
          _jobs = jobs;
          _earnings = earnings;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = context.read<ApiClient>();
    final session = context.read<SessionProvider>();
    var workerId = session.account?.id.trim() ?? '';

    if (workerId.isEmpty || session.account?.role != UserRole.technician) {
      final profileError = await session.loadCurrentWorkerProfile();
      if (!mounted) return;
      if (profileError != null) {
        setState(() {
          _error = profileError;
          _loading = false;
        });
        return;
      }
      workerId = session.account?.id.trim() ?? '';
    }

    if (workerId.isEmpty) {
      setState(() {
        _error = 'Log in as a technician to view dashboard.';
        _loading = false;
      });
      return;
    }

    try {
      final bookingsFuture =
          BookingsApi(client).getWorkerBookings(workerId: workerId);
      final earningsFuture = PaymentsApi(client).getEarnings();

      final results = await Future.wait([bookingsFuture, earningsFuture]);
      final jobs = (results[0] as List<BackendBooking>)
          .where((job) => job.workerId.trim() == workerId)
          .toList();
      final earnings = results[1] as EarningsSummary;

      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _earnings = earnings;
        _loading = false;
      });
      // Refresh notification feed in background after jobs load.
      unawaited(
        context.read<NotificationsProvider>().refresh(
              role: UserRole.technician,
              workerId: workerId,
            ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;
    final firstName = (account?.name ?? 'Ahmed').split(' ').first;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ServioSkeleton(height: 32, width: 200),
                const SizedBox(height: 8),
                const ServioSkeleton(height: 16, width: 120),
                const SizedBox(height: 24),
                const ServioSkeleton(height: 140, radius: ServioRadius.lg),
                const SizedBox(height: 24),
                const ServioSkeleton(height: 24, width: 150),
                const SizedBox(height: 12),
                const ServioSkeleton(height: 100, radius: ServioRadius.md),
                const SizedBox(height: 12),
                const ServioSkeleton(height: 100, radius: ServioRadius.md),
              ],
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final pendingJobs = _jobs.where((j) => j.status == 'pending').toList();
    final upcomingJobs = _jobs
        .where((j) => [
              'accepted',
              'confirmed',
              'scheduled',
              'in_progress',
              'en_route'
            ].contains(j.status))
        .toList();
    final recentJobs = _jobs
        .where((j) =>
            ['completed', 'done', 'cancelled', 'rejected'].contains(j.status))
        .toList();

    // Sort appropriately
    upcomingJobs.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    recentJobs.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: ServioColors.accent,
          onRefresh: _fetchData,
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
                _WelcomeBanner(
                  firstName: firstName,
                  pendingCount: pendingJobs.length,
                ),
                const SizedBox(height: 24),

                // ── Stat Cards Grid ──────────────────────────────
                _StatCardGrid(
                  totalJobs: _jobs.length,
                  totalEarnings: _earnings?.totalEarnings ?? 0,
                  avgRating: account?.averageRating ?? 0.0,
                  reviewCount: account?.reviewCount ?? 0,
                  pendingJobs: pendingJobs.length,
                  completedJobs: _earnings?.completedJobs ??
                      recentJobs
                          .where((j) =>
                              j.status == 'completed' || j.status == 'done')
                          .length,
                  pendingPayout: _earnings?.pendingPayout ?? 0,
                ),
                const SizedBox(height: 24),

                // ── Incoming Requests ─────────────────────────────
                if (pendingJobs.isNotEmpty) ...[
                  ServioSectionHeading(
                    title: 'Incoming Requests',
                    actionLabel: 'View all →',
                    onActionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const JobQueueScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ...pendingJobs.take(3).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IncomingRequestCard(job: job),
                      )),
                  const SizedBox(height: 12),
                ],

                // ── Upcoming Schedule ─────────────────────────────
                if (upcomingJobs.isNotEmpty) ...[
                  const ServioSectionHeading(title: 'Upcoming Schedule'),
                  const SizedBox(height: 12),
                  ...upcomingJobs.take(3).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ScheduleItem(job: job),
                      )),
                  const SizedBox(height: 14),
                ],

                // ── Recent Activity ───────────────────────────────
                if (recentJobs.isNotEmpty) ...[
                  ServioSectionHeading(
                    title: 'Recent Activity',
                    actionLabel: 'View all →',
                    onActionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const EarningsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ...recentJobs.take(4).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityCard(job: job),
                      )),
                ],
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
  const _WelcomeBanner({
    required this.firstName,
    required this.pendingCount,
  });

  final String firstName;
  final int pendingCount;

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
                        color: isDark
                            ? ServioColors.navyDark.withValues(alpha: 0.7)
                            : Colors.white70,
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
                      pendingCount > 0
                          ? 'You have $pendingCount new job request${pendingCount == 1 ? '' : 's'} waiting.'
                          : 'You have no new job requests at the moment.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? ServioColors.navyDark.withValues(alpha: 0.7)
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Notification bell
              Consumer<NotificationsProvider>(
                builder: (context, notifProvider, _) {
                  final count = notifProvider.unreadCount;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const NotificationsScreen()),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark ? ServioColors.navyDark : Colors.white)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.notifications_none_rounded,
                            color:
                                isDark ? ServioColors.navyDark : Colors.white,
                          ),
                          if (count > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 16),
                                height: 16,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: const BoxDecoration(
                                  color: ServioColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
                      MaterialPageRoute<void>(
                          builder: (_) => const JobQueueScreen()),
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
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              const TechnicianSettingsProfileScreen()),
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
    final bg = filled ? fg.withValues(alpha: 0.2) : Colors.transparent;

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
  const _StatCardGrid({
    required this.totalJobs,
    required this.totalEarnings,
    required this.avgRating,
    required this.reviewCount,
    required this.pendingJobs,
    required this.completedJobs,
    required this.pendingPayout,
  });

  final int totalJobs;
  final double totalEarnings;
  final double avgRating;
  final int reviewCount;
  final int pendingJobs;
  final int completedJobs;
  final double pendingPayout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
                child: _StatCard(
              label: 'Total Jobs',
              value: '$totalJobs',
              change: '$completedJobs completed',
              icon: Icons.check_box_outlined,
              iconColor: ServioColors.accent,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
              label: 'Total Earnings',
              value: 'EGP ${totalEarnings.toStringAsFixed(0)}',
              change: 'Lifetime',
              icon: Icons.payments_outlined,
              iconColor: ServioColors.success,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
                child: _StatCard(
              label: 'Avg Rating',
              value: avgRating.toStringAsFixed(1),
              change: 'Based on $reviewCount reviews',
              icon: Icons.star_border_rounded,
              iconColor: ServioColors.warning,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
              label: 'Pending Requests',
              value: '$pendingJobs',
              change: pendingJobs > 0 ? 'Action needed' : 'All caught up',
              icon: Icons.pending_actions_rounded,
              iconColor: ServioColors.info,
              changeColor:
                  pendingJobs > 0 ? ServioColors.info : ServioColors.success,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
                child: _StatCard(
              label: 'Completed Jobs',
              value: '$completedJobs',
              change: 'Successfully done',
              icon: Icons.assignment_outlined,
              iconColor: ServioColors.success,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
              label: 'Outstanding',
              value: '${pendingPayout.toStringAsFixed(0)} EGP',
              change: 'Pending payout',
              icon: Icons.credit_card_rounded,
              iconColor: ServioColors.warning,
              changeColor: ServioColors.warning,
              highlight: true,
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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary),
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
  const _IncomingRequestCard({required this.job});

  final BackendBooking job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => JobDetailsScreen(jobId: job.id),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: ServioCard(
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
                  Text(job.serviceName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: <Widget>[
                      if (job.customerName.isNotEmpty) ...[
                        Text(job.customerName,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary)),
                        Text('·',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary)),
                      ],
                      Text(job.addressCity,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary)),
                      Text('·',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary)),
                      Text('EGP ${job.totalAmount.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.accent,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ServioStatusChip(
                label: 'New', type: ServioStatusChipType.warning),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Item – matches website dash-schedule-item
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({required this.job});

  final BackendBooking job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final day = DateFormat('dd').format(job.scheduledDate);
    final month = DateFormat('MMM').format(job.scheduledDate).toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => JobDetailsScreen(jobId: job.id),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: ServioCard(
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
                  Text(job.serviceName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Text(
                        job.scheduledTime,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('·',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary)),
                      ),
                      Text(
                        job.addressCity,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Card – preserved from original
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.job});

  final BackendBooking job;

  ServioStatusChipType _chipType(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return ServioStatusChipType.success;
      case 'cancelled':
      case 'rejected':
        return ServioStatusChipType.danger;
      default:
        return ServioStatusChipType.info;
    }
  }

  String _chipLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => JobDetailsScreen(jobId: job.id),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: ServioCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(job.serviceName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (job.customerName.isNotEmpty) ...[
                    Text(
                      job.customerName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ServioStatusChip(
                    label: _chipLabel(job.status),
                    type: _chipType(job.status),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${job.totalAmount.toStringAsFixed(0)} EGP',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: servio.accent),
            ),
          ],
        ),
      ),
    );
  }
}
