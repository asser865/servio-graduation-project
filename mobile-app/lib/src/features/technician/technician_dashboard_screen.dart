import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/payments_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../core/state/notifications_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_skeleton.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../shared/notifications_screen.dart';
import 'availability_manager_screen.dart';
import 'earnings_screen.dart';
import 'job_details_screen.dart';
import 'job_queue_screen.dart';
import 'payout_request_screen.dart';

const double _kRadius = 28.0;
const double _kMonthlyGoal = 10000.0;

// ═════════════════════════════════════════════════════════════════════════════
// TechnicianDashboardScreen
// ═════════════════════════════════════════════════════════════════════════════

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState
    extends State<TechnicianDashboardScreen> {
  List<BackendBooking> _jobs = [];
  EarningsSummary? _earnings;
  bool _loading = true;
  String? _error;
  bool _isOnline = false;
  Timer? _pollingTimer;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
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
    if (workerId.isEmpty || session.account?.role != UserRole.technician) {
      return;
    }
    try {
      final results = await Future.wait([
        BookingsApi(client).getWorkerBookings(workerId: workerId),
        PaymentsApi(client).getEarnings(),
      ]);
      final jobs = (results[0] as List<BackendBooking>)
          .where((j) => j.workerId.trim() == workerId)
          .toList();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _earnings = results[1] as EarningsSummary;
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
      final err = await session.loadCurrentWorkerProfile();
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _error = err;
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
      final results = await Future.wait([
        BookingsApi(client).getWorkerBookings(workerId: workerId),
        PaymentsApi(client).getEarnings(),
      ]);
      final jobs = (results[0] as List<BackendBooking>)
          .where((j) => j.workerId.trim() == workerId)
          .toList();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _earnings = results[1] as EarningsSummary;
        _loading = false;
      });
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
    final firstName = (account?.name ?? 'Technician').split(' ').first;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ServioSkeleton(height: 32, width: 200),
                SizedBox(height: 8),
                ServioSkeleton(height: 16, width: 140),
                SizedBox(height: 24),
                ServioSkeleton(height: 160, radius: ServioRadius.xxl),
                SizedBox(height: 16),
                ServioSkeleton(height: 160, radius: ServioRadius.xxl),
                SizedBox(height: 16),
                ServioSkeleton(height: 130, radius: ServioRadius.xl),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _fetchData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final pendingJobs =
        _jobs.where((j) => j.status == 'pending').toList();
    final upcomingJobs = _jobs
        .where((j) => [
              'accepted',
              'confirmed',
              'scheduled',
              'in_progress',
              'en_route',
            ].contains(j.status))
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final recentJobs = _jobs
        .where((j) =>
            ['completed', 'done', 'cancelled', 'rejected'].contains(j.status))
        .toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    // Active job: prefer in_progress/en_route, fallback to first upcoming
    BackendBooking? activeJob;
    final inProgress = upcomingJobs
        .where((j) => j.status == 'in_progress' || j.status == 'en_route');
    if (inProgress.isNotEmpty) {
      activeJob = inProgress.first;
    } else if (upcomingJobs.isNotEmpty) {
      activeJob = upcomingJobs.first;
    }

    final totalEarnings = _earnings?.totalEarnings ?? 0.0;
    final completedCount = _earnings?.completedJobs ?? 0;
    final pendingPayout = _earnings?.pendingPayout ?? 0.0;
    final avgRating = account?.averageRating ?? 0.0;
    final reviewCount = account?.reviewCount ?? 0;
    final goalPercent = (totalEarnings / _kMonthlyGoal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: servio.accent,
          onRefresh: _fetchData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashHeader(
                  greeting: _greeting,
                  firstName: firstName,
                  account: account,
                  isDark: isDark,
                  servio: servio,
                ),
                const SizedBox(height: 20),
                _EarningsKpiCard(
                  totalEarnings: totalEarnings,
                  completedJobs: completedCount,
                  pendingPayout: pendingPayout,
                  servio: servio,
                ),
                const SizedBox(height: 16),
                _StatusHubCard(
                  isOnline: _isOnline,
                  onToggle: (v) => setState(() => _isOnline = v),
                  isDark: isDark,
                  servio: servio,
                ),
                const SizedBox(height: 16),
                _AiRecommendationCard(
                  pendingCount: pendingJobs.length,
                  upcomingCount: upcomingJobs.length,
                  servio: servio,
                ),
                const SizedBox(height: 16),
                if (activeJob != null) ...[
                  _ActiveJobCard(job: activeJob, isDark: isDark, servio: servio),
                  const SizedBox(height: 16),
                ],
                _GoalRatingRow(
                  totalEarnings: totalEarnings,
                  goalPercent: goalPercent,
                  avgRating: avgRating,
                  reviewCount: reviewCount,
                  isDark: isDark,
                  servio: servio,
                ),
                const SizedBox(height: 28),
                if (pendingJobs.isNotEmpty) ...[
                  ServioSectionHeading(
                    title: 'Incoming Requests',
                    actionLabel: 'View all →',
                    onActionTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const JobQueueScreen(showBackButton: true)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...pendingJobs.take(3).map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _IncomingRequestCard(job: job, isDark: isDark, servio: servio),
                        ),
                      ),
                  const SizedBox(height: 12),
                ],
                if (upcomingJobs.length > 1 ||
                    (upcomingJobs.isNotEmpty && activeJob == null)) ...[
                  const ServioSectionHeading(title: 'Upcoming Schedule'),
                  const SizedBox(height: 12),
                  ...upcomingJobs
                      .where(
                          (j) => activeJob == null || j.id != activeJob.id)
                      .take(3)
                      .map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ScheduleItem(job: job, isDark: isDark, servio: servio),
                        ),
                      ),
                  const SizedBox(height: 14),
                ],
                if (recentJobs.isNotEmpty) ...[
                  ServioSectionHeading(
                    title: 'Recent Activity',
                    actionLabel: 'View all →',
                    onActionTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const EarningsScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recentJobs.take(4).map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityCard(job: job, isDark: isDark, servio: servio),
                        ),
                      ),
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
// Servio surface card (replaces old glassmorphism, uses warm palette tokens)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding,
    this.isDark = false,
    this.servio,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool isDark;
  final ServioThemeExtension? servio;

  @override
  Widget build(BuildContext context) {
    final s = servio ?? context.servio;
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? s.surfaceRaised : ServioColors.surfaceLight;
    final border = dark
        ? s.border.withValues(alpha: 0.45)
        : s.border;
    final shadow = dark ? ServioShadows.restDark : ServioShadows.rest;

    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header row: greeting + name + notification bell + avatar
// ─────────────────────────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  const _DashHeader({
    required this.greeting,
    required this.firstName,
    required this.account,
    required this.isDark,
    required this.servio,
  });

  final String greeting;
  final String firstName;
  final UserAccount? account;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final initials = (account?.name ?? 'T')
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;
    final bellBg = (isDark ? Colors.white : ServioColors.navyDark)
        .withValues(alpha: 0.06);
    final bellBorder = servio.accent.withValues(alpha: 0.2);
    final bellIcon = isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final avatarBg = isDark
        ? ServioColors.backgroundSoftDark
        : ServioColors.backgroundSoftLight;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        Consumer<NotificationsProvider>(
          builder: (context, notif, _) => GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: bellBg,
                shape: BoxShape.circle,
                border: Border.all(color: bellBorder),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      color: bellIcon, size: 22),
                  if (notif.unreadCount > 0)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: servio.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Avatar: brand gradient border + surface bg
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ServioGradients.accent,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(
              child: Container(
                color: avatarBg,
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings KPI card (dark navy primary card)
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsKpiCard extends StatelessWidget {
  const _EarningsKpiCard({
    required this.totalEarnings,
    required this.completedJobs,
    required this.pendingPayout,
    required this.servio,
  });

  final double totalEarnings;
  final int completedJobs;
  final double pendingPayout;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: ServioGradients.brand,
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color: ServioColors.navyDark.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Earnings',
                style: TextStyle(
                  color: ServioColors.accentLight.withValues(alpha: 0.9),
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: servio.success, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: servio.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: totalEarnings),
            duration: const Duration(milliseconds: 1600),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              'EGP ${NumberFormat('#,##0').format(value.toInt())}',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completedJobs jobs completed',
            style: TextStyle(
              color: ServioColors.neutralWarm.withValues(alpha: 0.85),
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
          if (pendingPayout > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ServioColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ServioColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: ServioColors.success, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'EGP ${pendingPayout.toStringAsFixed(0)} pending payout',
                    style: const TextStyle(
                      color: ServioColors.success,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status hub: online toggle + 4 quick action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _StatusHubCard extends StatelessWidget {
  const _StatusHubCard({
    required this.isOnline,
    required this.onToggle,
    required this.isDark,
    required this.servio,
  });

  final bool isOnline;
  final ValueChanged<bool> onToggle;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;

    return _GlassCard(
      isDark: isDark,
      servio: servio,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isOnline ? servio.accent : textSecondary,
                    ),
                    child: Text(isOnline ? 'Online' : 'Offline'),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isOnline,
                    onChanged: onToggle,
                    activeColor: Colors.white,
                    activeTrackColor: ServioColors.navyDark,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: servio.border,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _HubButton(
                      icon: Icons.calendar_month_outlined,
                      label: 'Availability',
                      isDark: isDark,
                      servio: servio,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const AvailabilityManagerScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HubButton(
                      icon: Icons.payments_outlined,
                      label: 'Withdraw',
                      isDark: isDark,
                      servio: servio,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PayoutRequestScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _HubButton(
                      icon: Icons.work_outline_rounded,
                      label: 'My Jobs',
                      isDark: isDark,
                      servio: servio,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const JobQueueScreen(showBackButton: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HubButton(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      isDark: isDark,
                      servio: servio,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const JobQueueScreen(showBackButton: true),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubButton extends StatelessWidget {
  const _HubButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    required this.servio,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? servio.surfaceRaised : servio.surfaceAlt;
    final iconColor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final labelColor = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(color: servio.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Smart Insight card (dark navy + gold breathing glow)
// ─────────────────────────────────────────────────────────────────────────────

class _AiRecommendationCard extends StatefulWidget {
  const _AiRecommendationCard({
    required this.pendingCount,
    required this.upcomingCount,
    required this.servio,
  });

  final int pendingCount;
  final int upcomingCount;
  final ServioThemeExtension servio;

  @override
  State<_AiRecommendationCard> createState() =>
      _AiRecommendationCardState();
}

class _AiRecommendationCardState extends State<_AiRecommendationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.15, end: 0.45)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _insight {
    if (widget.pendingCount > 0) {
      return 'You have ${widget.pendingCount} pending job request${widget.pendingCount > 1 ? 's' : ''} awaiting your response. Accept quickly to boost your completion rate.';
    }
    if (widget.upcomingCount > 0) {
      return 'You have ${widget.upcomingCount} upcoming job${widget.upcomingCount > 1 ? 's' : ''} scheduled. Stay prepared and arrive on time to maintain your top rating.';
    }
    return 'No pending jobs right now. Stay online to receive new requests and maximise your earnings in your service area.';
  }

  @override
  Widget build(BuildContext context) {
    final servio = widget.servio;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kRadius),
          boxShadow: [
            BoxShadow(
              color: servio.accent.withValues(alpha: _glow.value * 0.4),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: ServioGradients.brand,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
            color: servio.accent.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: servio.accentLight, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'AI Smart Insight',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _insight,
              style: TextStyle(
                color: ServioColors.neutralWarm.withValues(alpha: 0.9),
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const JobQueueScreen(showBackButton: true)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: servio.accentLight.withValues(alpha: 0.7)),
                  foregroundColor: servio.accentLight,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                icon: const Icon(Icons.work_outline_rounded, size: 16),
                label: const Text(
                  'VIEW JOB QUEUE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active job card with vertical timeline
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({
    required this.job,
    required this.isDark,
    required this.servio,
  });

  final BackendBooking job;
  final bool isDark;
  final ServioThemeExtension servio;

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'en_route':
        return 'En Route';
      case 'accepted':
        return 'Accepted';
      case 'confirmed':
        return 'Confirmed';
      case 'scheduled':
        return 'Scheduled';
      default:
        return s;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'in_progress':
        return const Color(0xFFE9C349);
      case 'en_route':
        return const Color(0xFF4ADE80);
      case 'accepted':
      case 'confirmed':
        return const Color(0xFF60A5FA);
      default:
        return ServioColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;
    final dateStr = DateFormat('dd MMM').format(job.scheduledDate);
    final isActive =
        job.status == 'in_progress' || job.status == 'en_route';
    final isAccepted = ['accepted', 'confirmed', 'scheduled'].contains(
      job.status.toLowerCase(),
    );

    return _GlassCard(
      isDark: isDark,
      servio: servio,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Job',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(job.status).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _statusLabel(job.status).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusBg(job.status),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job.serviceName,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: textSecondary),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  job.addressCity.isNotEmpty
                      ? job.addressCity
                      : 'Address on file',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Timeline
          _buildTimeline(dateStr, isActive, isAccepted),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JobDetailsScreen(jobId: job.id),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ServioColors.navyDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text(
                'VIEW DETAILS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
      String dateStr, bool isActive, bool isAccepted) {
    final steps = [
      (
        label: 'Accepted',
        sub: dateStr,
        dotColor: ServioColors.navyDark,
        active: false,
        dim: false,
      ),
      (
        label: isActive ? 'In Progress' : 'Dispatched',
        sub: job.scheduledTime.isNotEmpty ? job.scheduledTime : 'Scheduled',
        dotColor: isActive
            ? ServioColors.accent
            : (isAccepted ? ServioColors.navyDark : ServioColors.neutralWarm),
        active: isActive,
        dim: !isActive && !isAccepted,
      ),
      (
        label: 'Completion expected',
        sub: job.scheduledTime.isNotEmpty ? job.scheduledTime : '--',
        dotColor: ServioColors.neutralWarm,
        active: false,
        dim: true,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        final isLast = i == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: s.dotColor,
                      shape: BoxShape.circle,
                      boxShadow: s.active
                          ? [
                              BoxShadow(
                                color: ServioColors.accent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  if (!isLast)
                    Container(
                       width: 2,
                       height: 28,
                       margin: const EdgeInsets.symmetric(vertical: 2),
                       color: ServioColors.neutralWarm,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: s.dim
                            ? (isDark
                                ? ServioColors.textSecondaryDark
                                : ServioColors.textSecondaryLight)
                            : (isDark
                                ? ServioColors.textPrimaryDark
                                : ServioColors.navyDark),
                      ),
                    ),
                    Text(
                      s.sub,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark
                            ? ServioColors.textSecondaryDark
                            : ServioColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal + Rating row
// ─────────────────────────────────────────────────────────────────────────────

class _GoalRatingRow extends StatelessWidget {
  const _GoalRatingRow({
    required this.totalEarnings,
    required this.goalPercent,
    required this.avgRating,
    required this.reviewCount,
    required this.isDark,
    required this.servio,
  });

  final double totalEarnings;
  final double goalPercent;
  final double avgRating;
  final int reviewCount;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _GlassCard(
            isDark: isDark,
            servio: servio,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earnings Goal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: ServioColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  'EGP ${NumberFormat('#,##0').format(totalEarnings.toInt())} ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'of ${NumberFormat('#,##0').format(_kMonthlyGoal.toInt())}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: goalPercent * 100),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOut,
                      builder: (_, value, __) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: servio.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: goalPercent),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOut,
                  builder: (_, value, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: servio.border,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(servio.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _GlassCard(
            isDark: isDark,
            servio: servio,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rating',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.star_rounded, color: servio.accent, size: 20),
                  ],
                ),
                if (reviewCount > 0)
                  Text(
                    '$reviewCount reviews',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                const SizedBox(height: 10),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0,
                        end: (avgRating / 5.0).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOut,
                    builder: (_, value, __) => SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 4,
                        backgroundColor: servio.border,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(servio.accent),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                ),
                if (avgRating >= 4.8) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: ServioGradients.brand,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'TOP TIER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incoming Request Card
// ─────────────────────────────────────────────────────────────────────────────

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.job,
    required this.isDark,
    required this.servio,
  });

  final BackendBooking job;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => JobDetailsScreen(jobId: job.id)),
      ),
      behavior: HitTestBehavior.opaque,
      child: _GlassCard(
        isDark: isDark,
        servio: servio,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: servio.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.build_outlined, size: 20, color: servio.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.serviceName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (job.customerName.isNotEmpty) job.customerName,
                      if (job.addressCity.isNotEmpty) job.addressCity,
                      'EGP ${job.totalAmount.toStringAsFixed(0)}',
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: servio.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: servio.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'NEW',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: servio.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Item
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({
    required this.job,
    required this.isDark,
    required this.servio,
  });

  final BackendBooking job;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;
    final day = DateFormat('dd').format(job.scheduledDate);
    final month =
        DateFormat('MMM').format(job.scheduledDate).toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => JobDetailsScreen(jobId: job.id)),
      ),
      behavior: HitTestBehavior.opaque,
      child: _GlassCard(
        isDark: isDark,
        servio: servio,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: servio.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                border: Border.all(color: servio.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      height: 1,
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: servio.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.serviceName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (job.scheduledTime.isNotEmpty) job.scheduledTime,
                      if (job.addressCity.isNotEmpty) job.addressCity,
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.job,
    required this.isDark,
    required this.servio,
  });

  final BackendBooking job;
  final bool isDark;
  final ServioThemeExtension servio;

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
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textSecondary = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => JobDetailsScreen(jobId: job.id)),
      ),
      behavior: HitTestBehavior.opaque,
      child: _GlassCard(
        isDark: isDark,
        servio: servio,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.serviceName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (job.customerName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      job.customerName,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ServioStatusChip(
                    label: _chipLabel(job.status),
                    type: _chipType(job.status),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'EGP ${job.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
