import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/reviews_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    final jobs = account?.completedJobs ?? 0;
    final rating = account?.averageRating ?? 0.0;
    final minRate = account?.hourlyRate ?? 0.0;

    final createdAt = account?.createdAt;
    final sinceYear = createdAt != null ? createdAt.year.toString() : '2025';

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
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: ServioSpacing.screenPadding,
          right: ServioSpacing.screenPadding,
          top: 16,
          bottom: bottomInset + ServioSpacing.screenPadding + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Top profile card ────────────────────────────────────────────────
            _FadeSlide(
              animation: _section0,
              child: Container(
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
                                  account?.initials ?? 'T',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (account?.isVerified ?? false)
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
                                account?.name ?? 'Technician',
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
                                    'Member since $sinceYear',
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
                    _StatsRow(
                      statsCtrl: _statsCtrl,
                      jobs: jobs,
                      rating: rating,
                      minRate: minRate,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Professional summary ──────────────────────────────────────────
            _FadeSlide(
              animation: _section1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionHeader(label: 'Professional'),
                  _ProfessionalCard(account: account),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Recent Jobs portfolio ────────────────────────────────────────
            _FadeSlide(
              animation: _section3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionHeader(label: 'Recent Jobs'),
                  _PortfolioSection(
                    jobs: _portfolio,
                    loading: _extraLoading,
                    error: _extraError,
                    onRetry: _fetchExtraData,
                    onViewAll: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _AllJobsScreen(jobs: _portfolio),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Reviews ──────────────────────────────────────────────────────
            _FadeSlide(
              animation: _section4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 20),

            // ── App ──────────────────────────────────────────────────────────
            _FadeSlide(
              animation: _section5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionHeader(label: 'App'),
                  _MenuGroup(
                    children: <Widget>[
                      _NavTile(
                        icon: Icons.verified_user_rounded,
                        iconColor: appIcon,
                        backgroundColor: appBg,
                        label: 'Verification',
                        subtitle: 'Manage your identity documents',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WorkerVerificationScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.schedule_rounded,
                        iconColor: appIcon,
                        backgroundColor: appBg,
                        label: 'Availability',
                        subtitle: 'Manage your working hours',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AvailabilityManagerScreen(),
                          ),
                        ),
                      ),
                      _NavTile(
                        icon: Icons.settings_rounded,
                        iconColor: appIcon,
                        backgroundColor: appBg,
                        label: 'Settings',
                        subtitle: 'Profile, security, preferences',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TechnicianSettingsScreen(),
                          ),
                        ),
                      ),
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Legal ────────────────────────────────────────────────────────
            _FadeSlide(
              animation: _section5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Logout ───────────────────────────────────────────────────────
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
            const SizedBox(height: 12),
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
    required this.isDark,
  });

  final AnimationController statsCtrl;
  final int jobs;
  final double rating;
  final double minRate;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _AnimatedStatItem(
          controller: statsCtrl,
          targetValue: jobs.toDouble(),
          label: 'Jobs',
          format: (v) => v.toInt().toString(),
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _AnimatedStatItem(
          controller: statsCtrl,
          targetValue: rating,
          label: 'Rating',
          format: (v) => v.toStringAsFixed(1),
          suffix: ' ★',
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _AnimatedStatItem(
          controller: statsCtrl,
          targetValue: minRate,
          label: 'Min Rate',
          format: (v) => '${v.toInt()} EGP',
          isDark: isDark,
        ),
      ],
    );
  }
}

class _AnimatedStatItem extends StatelessWidget {
  const _AnimatedStatItem({
    required this.controller,
    required this.targetValue,
    required this.label,
    required this.format,
    required this.isDark,
    this.suffix = '',
  });

  final AnimationController controller;
  final double targetValue;
  final String label;
  final String Function(double) format;
  final String suffix;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final anim = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    return Expanded(
      child: AnimatedBuilder(
        animation: anim,
        builder: (BuildContext context, Widget? _) {
          final current = targetValue * anim.value;
          final valueStr = '${format(current)}$suffix';
          return Container(
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
                  valueStr,
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
          );
        },
      ),
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

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Bio
          if (bio.isNotEmpty) ...<Widget>[
            Text(
              'About',
              style: theme.textTheme.labelLarge?.copyWith(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: servio.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Specialties
          if (allTags.isNotEmpty) ...<Widget>[
            Text(
              'Specialties',
              style: theme.textTheme.labelLarge?.copyWith(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: servio.textSecondary,
              ),
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
      return const _EmptyCard(
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
      child: Container(
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
          child: InkWell(
            onTap: () => showTransactionDetailsSheet(context, job: job),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      borderRadius: BorderRadius.circular(12),
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'Inter',
                              color: servio.textSecondary,
                            ),
                          ),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'Inter',
                            color: servio.textSecondary,
                          ),
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
                          fontFamily: 'Poppins',
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
          ),
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

    if (error != null && reviews.isEmpty) {
      return Container(); // Shimmer takes care or empty card
    }

    if (reviews.isEmpty) {
      return const _EmptyCard(
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

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Column(
            children: <Widget>[
              Text(
                avg.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFamily: 'Poppins',
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
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  color: servio.textSecondary,
                ),
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'Inter',
                            color: servio.textSecondary,
                          )),
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'Inter',
                            color: servio.textSecondary,
                          ),
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
      child: Container(
        padding: const EdgeInsets.all(16),
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
                        fontFamily: 'Poppins',
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          color: servio.textSecondary,
                        ),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  height: 1.5,
                  color: servio.textSecondary,
                ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: servio.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.wifi_off_rounded, color: servio.textSecondary, size: 28),
          const SizedBox(height: 8),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontFamily: 'Inter', color: servio.textSecondary),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: servio.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: servio.textSecondary, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontFamily: 'Inter', color: servio.textSecondary),
          ),
        ],
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

// ── Menu group ────────────────────────────────────────────────────────────────

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

// ── Nav tile ──────────────────────────────────────────────────────────────────

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
            ?.copyWith(fontFamily: 'Inter', color: servio.accent),
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
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'Inter'),
            ),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontFamily: 'Inter', color: servio.textSecondary),
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
