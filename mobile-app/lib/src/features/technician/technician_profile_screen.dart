import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/reviews_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../auth/auth_landing_screen.dart';
import '../marketing/about_screen.dart';
import '../marketing/contact_screen.dart';
import '../marketing/faq_screen.dart';
import '../marketing/privacy_policy_screen.dart';
import '../marketing/terms_of_service_screen.dart';
import '../shared/report_problem_screen.dart';
import 'availability_manager_screen.dart';
import 'technician_settings_screen.dart';
import 'transaction_details_sheet.dart';
import 'worker_verification_screen.dart';

class TechnicianSettingsProfileScreen extends StatefulWidget {
  const TechnicianSettingsProfileScreen({super.key});

  @override
  State<TechnicianSettingsProfileScreen> createState() =>
      _TechnicianSettingsProfileScreenState();
}

class _TechnicianSettingsProfileScreenState
    extends State<TechnicianSettingsProfileScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entranceCtrl;
  late final AnimationController _statsCtrl;

  late final Animation<double> _section0;
  late final Animation<double> _section1;
  late final Animation<double> _section3;
  late final Animation<double> _section4;
  late final Animation<double> _section5;

  List<ReviewResult> _reviews = <ReviewResult>[];
  List<BackendBooking> _portfolio = <BackendBooking>[];
  bool _extraLoading = true;
  String? _extraError;

  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _statsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    Animation<double> curved(double start, double end) => CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );

    _section0 = curved(0.00, 0.40);
    _section1 = curved(0.10, 0.50);
    _section3 = curved(0.20, 0.60);
    _section4 = curved(0.30, 0.70);
    _section5 = curved(0.40, 0.80);

    _entranceCtrl.forward();
    _statsCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchExtraData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchExtraData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchExtraData() async {
    final now = DateTime.now();
    if (_lastFetch != null &&
        now.difference(_lastFetch!) < const Duration(seconds: 30)) {
      return;
    }
    _lastFetch = now;
    if (!mounted) return;
    setState(() {
      _extraLoading = true;
      _extraError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final session = context.read<SessionProvider>();
      final workerId = session.account?.id ?? '';

      // Refresh account data to get latest completedJobs / isVerified / createdAt
      unawaited(session.loadCurrentWorkerProfile().catchError((_) => null));

      final results = await Future.wait(<Future<dynamic>>[
        ReviewsApi(client).getWorkerReviews(workerId),
        BookingsApi(client).getWorkerBookings(workerId: workerId),
      ]);

      if (!mounted) return;
      final reviews = results[0] as List<ReviewResult>;
      final bookings = results[1] as List<BackendBooking>;

      final completed = bookings
          .where((b) =>
              b.status == 'completed' ||
              b.status == 'done' ||
              b.status == 'awaiting_customer_confirmation')
          .toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      setState(() {
        _reviews = reviews;
        _portfolio = completed;
        _extraLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _extraLoading = false;
          _extraError = 'Could not load profile data.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    final jobs = account?.completedJobs ?? 0;
    final rating = account?.averageRating ?? 0.0;
    final minRate = account?.hourlyRate ?? 0.0;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileHeaderDelegate(
                topPadding: MediaQuery.paddingOf(context).top,
                initials: account?.initials ?? 'T',
                name: account?.name ?? 'Technician',
                email: account?.email ?? '',
                role: 'Technician',
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                24,
                ServioSpacing.screenPadding,
                ServioSpacing.screenPadding + 24 + bottomInset,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  // ── Stats ────────────────────────────────────────────────
                  _FadeSlide(
                    animation: _section0,
                    child: _StatsRow(
                      statsCtrl: _statsCtrl,
                      jobs: jobs,
                      rating: rating,
                      minRate: minRate,
                    ),
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Professional Summary ─────────────────────────────────
                  _FadeSlide(
                    animation: _section1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SectionHeader(label: 'Professional'),
                        _ProfessionalCard(account: account),
                      ],
                    ),
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Recent Jobs Portfolio ────────────────────────────────
                  _FadeSlide(
                    animation: _section3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SectionHeader(label: 'Recent Jobs'),
                        _PortfolioSection(
                          jobs: _portfolio,
                          loading: _extraLoading,
                          error: _extraError,
                          onRetry: _fetchExtraData,
                          onViewAll: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _AllJobsScreen(jobs: _portfolio),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Reviews ──────────────────────────────────────────────
                  _FadeSlide(
                    animation: _section4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SectionHeader(label: 'Reviews'),
                        _ReviewsSection(
                          reviews: _reviews,
                          loading: _extraLoading,
                          error: _extraError,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── App ───────────────────────────────────────────────────
                  _FadeSlide(
                    animation: _section5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SectionHeader(label: 'App'),
                        _MenuGroup(children: <Widget>[
                          _NavTile(
                            icon: Icons.verified_user_outlined,
                            iconColor: context.servio.accent,
                            label: 'Verification',
                            subtitle: 'Manage your identity documents',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const WorkerVerificationScreen(),
                              ),
                            ),
                          ),
                          _NavTile(
                            icon: Icons.schedule_rounded,
                            iconColor: context.servio.success,
                            label: 'Availability',
                            subtitle: 'Manage your working hours',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const AvailabilityManagerScreen(),
                              ),
                            ),
                          ),
                          _NavTile(
                            icon: Icons.settings_outlined,
                            iconColor: context.servio.accent,
                            label: 'Settings',
                            subtitle: 'Profile, security, preferences',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const TechnicianSettingsScreen(),
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
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Legal ─────────────────────────────────────────────────
                  _FadeSlide(
                    animation: _section5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SectionHeader(label: 'Legal'),
                        _MenuGroup(children: <Widget>[
                          _NavTile(
                            icon: Icons.info_outline_rounded,
                            iconColor: context.servio.accent,
                            label: 'About SERVIO',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const AboutScreen()),
                            ),
                          ),
                          _NavTile(
                            icon: Icons.description_outlined,
                            iconColor: context.servio.accent,
                            label: 'Terms of Service',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const TermsOfServiceScreen()),
                            ),
                          ),
                          _NavTile(
                            icon: Icons.privacy_tip_outlined,
                            iconColor: context.servio.accent,
                            label: 'Privacy Policy',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const PrivacyPolicyScreen()),
                            ),
                          ),
                          _NavTile(
                            icon: Icons.quiz_outlined,
                            iconColor: context.servio.accent,
                            label: 'FAQ',
                            subtitle: 'Frequently asked questions',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const FaqScreen()),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: ServioSpacing.sectionGap),

                  // ── Logout ────────────────────────────────────────────────
                  _FadeSlide(
                    animation: _section5,
                    child: _LogoutButton(
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
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fade + slide entrance wrapper ─────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.statsCtrl,
    required this.jobs,
    required this.rating,
    required this.minRate,
  });

  final AnimationController statsCtrl;
  final int jobs;
  final double rating;
  final double minRate;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final dividerColor = servio.border.withValues(alpha: 0.6);

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _AnimatedStatItem(
              controller: statsCtrl,
              targetValue: jobs.toDouble(),
              label: 'Jobs',
              format: (v) => v.toInt().toString(),
            ),
          ),
          SizedBox(
              height: 36,
              child: VerticalDivider(color: dividerColor, width: 1)),
          Expanded(
            child: _AnimatedStatItem(
              controller: statsCtrl,
              targetValue: rating,
              label: 'Rating',
              format: (v) => v.toStringAsFixed(1),
              suffix: '★',
            ),
          ),
          SizedBox(
              height: 36,
              child: VerticalDivider(color: dividerColor, width: 1)),
          Expanded(
            child: _AnimatedStatItem(
              controller: statsCtrl,
              targetValue: minRate,
              label: 'Min Rate',
              format: (v) => '${v.toInt()} EGP',
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatItem extends StatelessWidget {
  const _AnimatedStatItem({
    required this.controller,
    required this.targetValue,
    required this.label,
    required this.format,
    this.suffix = '',
  });

  final AnimationController controller;
  final double targetValue;
  final String label;
  final String Function(double) format;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final anim = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (BuildContext context, Widget? _) {
        final current = targetValue * anim.value;
        return Column(
          children: <Widget>[
            Text(
              format(current),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: servio.accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        );
      },
    );
  }
}

// ── Professional card ─────────────────────────────────────────────────────────

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.account});

  final dynamic account; // UserAccount?

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    final bio = (account?.bio as String?) ?? '';
    final skills = (account?.skills as List<String>?) ?? <String>[];
    final categories = (account?.categories as List<String>?) ?? <String>[];
    final locationLabel = (account?.locationLabel as String?) ?? '';
    final hourlyRate = (account?.hourlyRate as double?) ?? 0;
    final yearsExp = (account?.yearsExperience as int?) ?? 0;
    final createdAt = account?.createdAt as DateTime?;

    final allTags = <String>[
      ...categories.map(_readable),
      ...skills.map(_readable),
    ].where((t) => t.isNotEmpty).toSet().take(8).toList();

    final sinceYear = createdAt != null ? createdAt.year.toString() : '';

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Bio
          if (bio.isNotEmpty) ...<Widget>[
            Text(
              'About',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 16),
          ],

          // Specialties
          if (allTags.isNotEmpty) ...<Widget>[
            Text(
              'Specialties',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((t) => _MiniChip(label: t)).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Details
          if (locationLabel.isNotEmpty)
            _DetailRow(label: 'Service Area', value: locationLabel),
          if (hourlyRate > 0)
            _DetailRow(
                label: 'Hourly Rate', value: '${hourlyRate.toInt()} EGP / hr'),
          if (yearsExp > 0)
            _DetailRow(
                label: 'Experience',
                value: '$yearsExp ${yearsExp == 1 ? 'year' : 'years'}'),
          if (sinceYear.isNotEmpty)
            _DetailRow(label: 'Member Since', value: sinceYear),
        ],
      ),
    );
  }
}

String _readable(String v) {
  final s = v.trim().replaceAll(RegExp(r'[-_]+'), ' ');
  if (s.isEmpty) return '';
  return s.split(' ').map((w) {
    if (w.isEmpty) return '';
    final u = w.toUpperCase();
    if (u == 'HVAC' || u == 'AC') return u;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

// ── Portfolio section ─────────────────────────────────────────────────────────

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({
    required this.jobs,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onViewAll,
  });

  final List<BackendBooking> jobs;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _ShimmerList(count: 3, height: 80);

    if (error != null && jobs.isEmpty) {
      return _ErrorCard(message: error!, onRetry: onRetry);
    }

    if (jobs.isEmpty) {
      return _EmptyCard(
        icon: Icons.work_history_outlined,
        message: 'No completed jobs yet.',
      );
    }

    final visible = jobs.take(5).toList();
    final hasMore = jobs.length > 5;

    return Column(
      children: <Widget>[
        ...visible.map((job) => _PortfolioCard(job: job)),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.list_rounded, size: 18),
                label: Text('View All (${jobs.length} jobs)'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.job});

  final BackendBooking job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final dateStr = '${job.scheduledDate.day.toString().padLeft(2, '0')}/'
        '${job.scheduledDate.month.toString().padLeft(2, '0')}/'
        '${job.scheduledDate.year}';
    final location = <String>[job.addressStreet, job.addressCity]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ServioCard(
        radius: ServioRadius.lg,
        onTap: () => showTransactionDetailsSheet(context, job: job),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: ServioGradients.warm,
                borderRadius: BorderRadius.circular(ServioRadius.md),
              ),
              child: const Icon(Icons.build_rounded,
                  color: ServioColors.deepBrown, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    job.serviceName.isNotEmpty ? job.serviceName : 'Service',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (location.isNotEmpty)
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${(job.totalAmount * 0.95).toInt()} EGP',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: servio.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(ServioColors.success),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Text(
                    'Completed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ServioColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.loading,
    required this.error,
  });

  final List<ReviewResult> reviews;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _ShimmerList(count: 2, height: 96);

    if (reviews.isEmpty) {
      return _EmptyCard(
        icon: Icons.star_outline_rounded,
        message: 'No reviews yet.',
      );
    }

    final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / reviews.length;

    // Rating distribution: count per star (1–5)
    final dist = <int, int>{};
    for (final r in reviews) {
      final star = r.rating.round().clamp(1, 5);
      dist[star] = (dist[star] ?? 0) + 1;
    }

    return Column(
      children: <Widget>[
        _RatingDistribution(avg: avg, total: reviews.length, dist: dist),
        const SizedBox(height: 12),
        ...reviews.take(5).map((r) => _ReviewCard(review: r)),
      ],
    );
  }
}

class _RatingDistribution extends StatelessWidget {
  const _RatingDistribution({
    required this.avg,
    required this.total,
    required this.dist,
  });

  final double avg;
  final int total;
  final Map<int, int> dist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Column(
            children: <Widget>[
              Text(
                avg.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: servio.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: List<Widget>.generate(5, (i) {
                  final filled = i < avg.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: ServioColors.warning,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$total ${total == 1 ? 'review' : 'reviews'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: servio.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: List<Widget>.generate(5, (i) {
                final star = 5 - i;
                final count = dist[star] ?? 0;
                final fraction = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      Text('$star',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: servio.textSecondary)),
                      const SizedBox(width: 4),
                      Icon(Icons.star_rounded,
                          size: 10, color: ServioColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: LayoutBuilder(builder: (ctx, constraints) {
                          return Stack(
                            children: <Widget>[
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: servio.border.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: fraction,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: ServioColors.warning,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewResult review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final date = '${review.createdAt.day.toString().padLeft(2, '0')}/'
        '${review.createdAt.month.toString().padLeft(2, '0')}/'
        '${review.createdAt.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(ServioColors.accent),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      review.reviewerName.isNotEmpty
                          ? review.reviewerName[0].toUpperCase()
                          : 'A',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ServioColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        review.reviewerName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        date,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List<Widget>.generate(5, (i) {
                    final filled = i < review.rating.round();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14,
                      color: ServioColors.warning,
                    );
                  }),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                review.comment,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(height: 1.5, color: servio.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared UI helpers ─────────────────────────────────────────────────────────

class _ShimmerList extends StatefulWidget {
  const _ShimmerList({required this.count, required this.height});
  final int count;
  final double height;
  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.4 + 0.4 * _anim.value;
        return Column(
          children: List<Widget>.generate(
            widget.count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: servio.border.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          Icon(Icons.wifi_off_rounded, color: servio.textSecondary, size: 28),
          const SizedBox(height: 8),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: servio.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          Icon(icon, color: servio.textSecondary, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
        ],
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
    return Row(
      children: <Widget>[
        _ProfileAvatar(initials: initials, size: 40, iconSize: 0),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
              child: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white, size: 14),
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

// ── Menu group ────────────────────────────────────────────────────────────────

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
                    Text(label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary)),
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

// ── Mini chip ─────────────────────────────────────────────────────────────────

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
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: servio.accent),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
      ),
    );
  }
}

// ── All jobs screen ───────────────────────────────────────────────────────────

class _AllJobsScreen extends StatelessWidget {
  const _AllJobsScreen({required this.jobs});

  final List<BackendBooking> jobs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Jobs'),
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        itemCount: jobs.length,
        itemBuilder: (context, index) => _PortfolioCard(job: jobs[index]),
      ),
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
