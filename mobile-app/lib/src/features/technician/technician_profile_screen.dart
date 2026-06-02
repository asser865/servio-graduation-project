import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/reviews_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/user_account.dart';
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

// ── Constants ─────────────────────────────────────────────────────────────────

const _kHeroExpandedHeight = 300.0;
const _kNavyAnchor = Color(0xFF1A1D23);
const _kBrownAnchor = Color(0xFF3E2723);
const _kTaupe = Color(0xFF9A8C73);
const _kSurfaceWarm = Color(0xFFF3EDE7);
const _kBgLight = Color(0xFFFBF9F6);

// ── Main Screen ───────────────────────────────────────────────────────────────

class TechnicianSettingsProfileScreen extends StatefulWidget {
  const TechnicianSettingsProfileScreen({super.key});

  @override
  State<TechnicianSettingsProfileScreen> createState() =>
      _TechnicianSettingsProfileScreenState();
}

class _TechnicianSettingsProfileScreenState
    extends State<TechnicianSettingsProfileScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Animation controllers ──
  late final AnimationController _entranceCtrl;
  late final AnimationController _statsCtrl;
  late final AnimationController _badgeCtrl;

  late final Animation<double> _section0;
  late final Animation<double> _section1;
  late final Animation<double> _section2;
  late final Animation<double> _section3;
  late final Animation<double> _section4;

  // ── Scroll ──
  final ScrollController _scrollCtrl = ScrollController();
  bool _headerOpaque = false;

  // ── Data ──
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
      duration: const Duration(milliseconds: 1400),
    );
    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _section0 = _curved(0.00, 0.40);
    _section1 = _curved(0.15, 0.55);
    _section2 = _curved(0.25, 0.65);
    _section3 = _curved(0.35, 0.75);
    _section4 = _curved(0.45, 0.85);

    _entranceCtrl.forward();
    _statsCtrl.forward();

    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchExtraData());
  }

  Animation<double> _curved(double start, double end) => CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  void _onScroll() {
    final opaque = _scrollCtrl.offset > (_kHeroExpandedHeight - kToolbarHeight - 16);
    if (opaque != _headerOpaque) setState(() => _headerOpaque = opaque);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchExtraData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceCtrl.dispose();
    _statsCtrl.dispose();
    _badgeCtrl.dispose();
    _scrollCtrl.dispose();
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

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _push(Widget screen) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  Future<void> _logout() async {
    final session = context.read<SessionProvider>();
    await session.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthLandingScreen()),
      (Route<dynamic> _) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    final jobs = account?.completedJobs ?? 0;
    final rating = account?.averageRating ?? 0.0;
    final hourlyRate = account?.hourlyRate ?? 0.0;

    final appBg = isDark
        ? const Color(0xFF262B34)
        : const Color(0xFFE4E2DF).withValues(alpha: 0.5);
    final appIcon =
        isDark ? const Color(0xFFE3D5CA) : const Color(0xFF45474B);
    final supportBg = isDark
        ? const Color(0xFF7C2D12).withValues(alpha: 0.2)
        : const Color(0xFFFFF7ED);
    final supportIcon =
        isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
    final legalBg = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
        : const Color(0xFFEFF6FF);
    final legalIcon =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13161C) : _kBgLight,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          // ── Collapsible hero app bar ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: _kHeroExpandedHeight,
            pinned: true,
            stretch: true,
            backgroundColor: _headerOpaque
                ? _kNavyAnchor.withValues(alpha: 0.96)
                : Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _headerOpaque ? 1.0 : 0.0,
              child: Text(
                account?.name ?? 'Profile',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            actions: <Widget>[
              _GlassButton(
                icon: Icons.edit_rounded,
                onTap: () => _push(const TechnicianSettingsScreen()),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const <StretchMode>[StretchMode.zoomBackground],
              background: _HeroBackground(
                account: account,
                badgeCtrl: _badgeCtrl,
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.only(
              left: ServioSpacing.screenPadding,
              right: ServioSpacing.screenPadding,
              bottom: bottomInset + 96,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                // ── Stats dashboard ────────────────────────────────────────
                _FadeSlide(
                  animation: _section0,
                  child: _StatsDashboard(
                    statsCtrl: _statsCtrl,
                    jobs: jobs,
                    rating: rating,
                    hourlyRate: hourlyRate,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Accordion: Profile Overview ────────────────────────────
                _FadeSlide(
                  animation: _section1,
                  child: _AccordionSection(
                    icon: Icons.fingerprint_rounded,
                    title: 'Profile Overview',
                    initiallyExpanded: true,
                    isDark: isDark,
                    child: _BioContent(
                      bio: account?.bio ?? '',
                      isDark: isDark,
                      servio: servio,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Accordion: Specializations ─────────────────────────────
                _FadeSlide(
                  animation: _section1,
                  child: _AccordionSection(
                    icon: Icons.handyman_rounded,
                    title: 'Specializations',
                    isDark: isDark,
                    child: _SpecializationsContent(
                      skills: account?.skills ?? <String>[],
                      categories: account?.categories ?? <String>[],
                      isDark: isDark,
                      servio: servio,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Accordion: Schedule ────────────────────────────────────
                _FadeSlide(
                  animation: _section2,
                  child: _AccordionSection(
                    icon: Icons.calendar_today_rounded,
                    title: 'Schedule',
                    isDark: isDark,
                    child: _ScheduleContent(
                      availability: account?.availability ?? <AvailabilitySlot>[],
                      isDark: isDark,
                      servio: servio,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Accordion: Client Testimonials ─────────────────────────
                _FadeSlide(
                  animation: _section2,
                  child: _AccordionSection(
                    icon: Icons.star_rounded,
                    title: 'Client Testimonials',
                    isDark: isDark,
                    child: _TestimonialsContent(
                      reviews: _reviews,
                      loading: _extraLoading,
                      error: _extraError,
                      onRetry: _fetchExtraData,
                      isDark: isDark,
                      servio: servio,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Accordion: Recent Jobs ─────────────────────────────────
                _FadeSlide(
                  animation: _section3,
                  child: _AccordionSection(
                    icon: Icons.work_history_rounded,
                    title: 'Recent Jobs',
                    isDark: isDark,
                    child: _PortfolioContent(
                      jobs: _portfolio,
                      loading: _extraLoading,
                      error: _extraError,
                      onRetry: _fetchExtraData,
                      onViewAll: () => _push(_AllJobsScreen(jobs: _portfolio)),
                      isDark: isDark,
                      servio: servio,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Accordion: Operational Area ────────────────────────────
                _FadeSlide(
                  animation: _section3,
                  child: _AccordionSection(
                    icon: Icons.explore_rounded,
                    title: 'Operational Area',
                    isDark: isDark,
                    child: _AreaContent(
                      locationLabel: account?.locationLabel ?? '',
                      city: account?.city ?? '',
                      isDark: isDark,
                      servio: servio,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── App section ────────────────────────────────────────────
                _FadeSlide(
                  animation: _section4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _SectionHeader(label: 'App', isDark: isDark),
                      _MenuGroup(
                        isDark: isDark,
                        children: <Widget>[
                          _NavTile(
                            icon: Icons.verified_user_rounded,
                            iconColor: appIcon,
                            backgroundColor: appBg,
                            label: 'Verification',
                            subtitle: 'Manage your identity documents',
                            onTap: () =>
                                _push(const WorkerVerificationScreen()),
                          ),
                          _NavTile(
                            icon: Icons.schedule_rounded,
                            iconColor: appIcon,
                            backgroundColor: appBg,
                            label: 'Availability',
                            subtitle: 'Manage your working hours',
                            onTap: () =>
                                _push(const AvailabilityManagerScreen()),
                          ),
                          _NavTile(
                            icon: Icons.settings_rounded,
                            iconColor: appIcon,
                            backgroundColor: appBg,
                            label: 'Settings',
                            subtitle: 'Profile, security, preferences',
                            onTap: () =>
                                _push(const TechnicianSettingsScreen()),
                          ),
                          _NavTile(
                            icon: Icons.report_problem_rounded,
                            iconColor: supportIcon,
                            backgroundColor: supportBg,
                            label: 'Report a Problem',
                            subtitle: 'Send us feedback or issues',
                            onTap: () => _push(const ReportProblemScreen()),
                          ),
                          _NavTile(
                            icon: Icons.contact_support_rounded,
                            iconColor: supportIcon,
                            backgroundColor: supportBg,
                            label: 'Contact Us',
                            subtitle: 'Get help from our team',
                            onTap: () => _push(const ContactScreen()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Legal section ──────────────────────────────────────────
                _FadeSlide(
                  animation: _section4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _SectionHeader(label: 'Legal', isDark: isDark),
                      _MenuGroup(
                        isDark: isDark,
                        children: <Widget>[
                          _NavTile(
                            icon: Icons.info_rounded,
                            iconColor: legalIcon,
                            backgroundColor: legalBg,
                            label: 'About SERVIO',
                            onTap: () => _push(const AboutScreen()),
                          ),
                          _NavTile(
                            icon: Icons.description_rounded,
                            iconColor: legalIcon,
                            backgroundColor: legalBg,
                            label: 'Terms of Service',
                            onTap: () => _push(const TermsOfServiceScreen()),
                          ),
                          _NavTile(
                            icon: Icons.privacy_tip_rounded,
                            iconColor: legalIcon,
                            backgroundColor: legalBg,
                            label: 'Privacy Policy',
                            onTap: () => _push(const PrivacyPolicyScreen()),
                          ),
                          _NavTile(
                            icon: Icons.quiz_rounded,
                            iconColor: legalIcon,
                            backgroundColor: legalBg,
                            label: 'FAQ',
                            subtitle: 'Frequently asked questions',
                            onTap: () => _push(const FaqScreen()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Logout ─────────────────────────────────────────────────
                _FadeSlide(
                  animation: _section4,
                  child: _LogoutButton(onTap: _logout),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Background ───────────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({
    required this.account,
    required this.badgeCtrl,
  });

  final dynamic account;
  final AnimationController badgeCtrl;

  @override
  Widget build(BuildContext context) {
    final name = (account?.name as String?) ?? 'Technician';
    final initials = account?.initials ?? 'T';
    final isVerified = (account?.isVerified as bool?) ?? false;
    final specialty = _firstSpecialty(account);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Gradient background
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_kNavyAnchor, _kBrownAnchor],
            ),
          ),
        ),
        // Subtle texture dots
        CustomPaint(painter: _HeroDotsPainter()),
        // Content
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 16),
              // Avatar
              Stack(
                children: <Widget>[
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF9A8C73),
                          Color(0xFF5C4A35),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (isVerified)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: AnimatedBuilder(
                        animation: badgeCtrl,
                        builder: (_, child) => Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(
                                  alpha: 0.4 * badgeCtrl.value,
                                ),
                                blurRadius: 12,
                                spreadRadius: 4 * badgeCtrl.value,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              // Role badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 1,
                    color: _kTaupe.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    specialty.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kSurfaceWarm.withValues(alpha: 0.9),
                      letterSpacing: 0.18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 1,
                    color: _kTaupe.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _firstSpecialty(dynamic account) {
    final categories = (account?.categories as List<dynamic>?) ?? <dynamic>[];
    if (categories.isNotEmpty) return _readable(categories.first.toString());
    final skills = (account?.skills as List<dynamic>?) ?? <dynamic>[];
    if (skills.isNotEmpty) return _readable(skills.first.toString());
    return 'Master Artisan';
  }
}

// ── Hero dots texture painter ─────────────────────────────────────────────────

class _HeroDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    const spacing = 32.0;
    const radius = 1.5;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Glass AppBar button ───────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Stats Dashboard ───────────────────────────────────────────────────────────

class _StatsDashboard extends StatelessWidget {
  const _StatsDashboard({
    required this.statsCtrl,
    required this.jobs,
    required this.rating,
    required this.hourlyRate,
    required this.isDark,
  });

  final AnimationController statsCtrl;
  final int jobs;
  final double rating;
  final double hourlyRate;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.9);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            _StatCell(
              ctrl: statsCtrl,
              value: hourlyRate,
              label: 'Hourly',
              format: (v) => '${v.toInt()} EGP',
              isDark: isDark,
            ),
            _VerticalDivider(isDark: isDark),
            _StatCell(
              ctrl: statsCtrl,
              value: jobs.toDouble(),
              label: 'Jobs',
              format: (v) => v.toInt().toString(),
              isDark: isDark,
            ),
            _VerticalDivider(isDark: isDark),
            _StatCell(
              ctrl: statsCtrl,
              value: rating,
              label: 'Rating',
              format: (v) => v.toStringAsFixed(1),
              suffix: Icons.star_rounded,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.ctrl,
    required this.value,
    required this.label,
    required this.format,
    required this.isDark,
    this.suffix,
  });

  final AnimationController ctrl;
  final double value;
  final String label;
  final String Function(double) format;
  final IconData? suffix;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? const Color(0xFF9A8C73)
        : const Color(0xFF6B6560);
    final valueColor = isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: AnimatedBuilder(
          animation: CurvedAnimation(
            parent: ctrl,
            curve: Curves.easeOutCubic,
          ),
          builder: (_, __) {
            final cur = value * ctrl.value;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    letterSpacing: 0.12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      format(cur),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                        height: 1,
                      ),
                    ),
                    if (suffix != null) ...<Widget>[
                      const SizedBox(width: 3),
                      Icon(suffix, size: 16, color: const Color(0xFFF59E0B)),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        color: (isDark ? Colors.white : _kTaupe).withValues(alpha: 0.1),
      );
}

// ── Accordion Section ─────────────────────────────────────────────────────────

class _AccordionSection extends StatefulWidget {
  const _AccordionSection({
    required this.icon,
    required this.title,
    required this.child,
    required this.isDark,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool isDark;
  final bool initiallyExpanded;

  @override
  State<_AccordionSection> createState() => _AccordionSectionState();
}

class _AccordionSectionState extends State<_AccordionSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.initiallyExpanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOutCubic,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1E2229) : Colors.white;
    final border = widget.isDark
        ? const Color(0xFF9A8C73).withValues(alpha: 0.08)
        : const Color(0xFF9A8C73).withValues(alpha: 0.05);
    final iconBg = widget.isDark
        ? const Color(0xFF262B34)
        : const Color(0xFFEFEEEB);
    final titleColor =
        widget.isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor;
    final chevronColor = widget.isDark
        ? const Color(0xFF9A8C73)
        : const Color(0xFF6B6560);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row
            InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, size: 20, color: titleColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 24,
                        color: chevronColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expandable content
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accordion content widgets ─────────────────────────────────────────────────

class _BioContent extends StatelessWidget {
  const _BioContent({
    required this.bio,
    required this.isDark,
    required this.servio,
  });

  final String bio;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    if (bio.isEmpty) {
      return _EmptyInline(
        message: 'No bio added yet.',
        servio: servio,
      );
    }
    return Text(
      bio,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        height: 1.65,
        color: isDark ? const Color(0xFFBDB5AA) : const Color(0xFF45474B),
      ),
    );
  }
}

class _SpecializationsContent extends StatelessWidget {
  const _SpecializationsContent({
    required this.skills,
    required this.categories,
    required this.isDark,
    required this.servio,
  });

  final List<String> skills;
  final List<String> categories;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final all = <String>[
      ...categories.map(_readable),
      ...skills.map(_readable),
    ].where((t) => t.isNotEmpty).toSet().toList();

    if (all.isEmpty) {
      return _EmptyInline(
        message: 'No specializations added yet.',
        servio: servio,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: all
          .map((t) => _SpecChip(label: t, isDark: isDark))
          .toList(),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF262B34)
            : const Color(0xFFEFEEEB),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(
          color: const Color(0xFF9A8C73).withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor,
        ),
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  const _ScheduleContent({
    required this.availability,
    required this.isDark,
    required this.servio,
  });

  final List<AvailabilitySlot> availability;
  final bool isDark;
  final ServioThemeExtension servio;

  static const _days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = <String>[
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];

  bool _isAvailable(int index) {
    final day = _dayNames[index];
    return availability.any(
      (s) => s.day.toLowerCase().startsWith(day.substring(0, 3)) &&
          s.from.isNotEmpty &&
          s.to.isNotEmpty,
    );
  }

  String _hoursLabel() {
    if (availability.isEmpty) return '';
    final workSlots = availability.where((s) => s.from.isNotEmpty && s.to.isNotEmpty);
    if (workSlots.isEmpty) return '';
    final first = workSlots.first;
    return '${first.from}  —  ${first.to}';
  }

  @override
  Widget build(BuildContext context) {
    if (availability.isEmpty) {
      return _EmptyInline(
        message: 'No schedule set yet.',
        servio: servio,
      );
    }

    final hours = _hoursLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(_days.length, (i) {
            final active = _isAvailable(i);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: active
                          ? _kNavyAnchor
                          : (isDark
                              ? const Color(0xFF262B34)
                              : const Color(0xFFEFEEEB)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _days[i],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF9A8C73)
                                  : const Color(0xFF6B6560)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (hours.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: isDark
                    ? const Color(0xFF9A8C73)
                    : const Color(0xFF6B6560),
              ),
              const SizedBox(width: 8),
              Text(
                hours,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFE3D5CA)
                      : _kNavyAnchor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TestimonialsContent extends StatelessWidget {
  const _TestimonialsContent({
    required this.reviews,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.isDark,
    required this.servio,
  });

  final List<ReviewResult> reviews;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    if (loading) return _ShimmerList(count: 2, height: 90, isDark: isDark);
    if (error != null && reviews.isEmpty) {
      return _ErrorCard(message: error!, onRetry: onRetry, isDark: isDark);
    }
    if (reviews.isEmpty) {
      return _EmptyInline(message: 'No reviews yet.', servio: servio);
    }

    final avg =
        reviews.fold(0.0, (sum, r) => sum + r.rating) / reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _RatingBadge(avg: avg, total: reviews.length, isDark: isDark),
        const SizedBox(height: 12),
        ...reviews.take(5).map((r) => _ReviewCard(review: r, isDark: isDark)),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({
    required this.avg,
    required this.total,
    required this.isDark,
  });

  final double avg;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          avg.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor,
            height: 1,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: List<Widget>.generate(5, (i) {
                final filled = i < avg.round();
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: const Color(0xFFF59E0B),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '$total ${total == 1 ? 'review' : 'reviews'}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF9A8C73)
                    : const Color(0xFF6B6560),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.isDark});

  final ReviewResult review;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF262B34)
        : const Color(0xFFF5F3F0);
    final initials = review.reviewerName.isNotEmpty
        ? review.reviewerName[0].toUpperCase()
        : 'A';
    final date =
        '${review.createdAt.day.toString().padLeft(2, '0')}/'
        '${review.createdAt.month.toString().padLeft(2, '0')}/'
        '${review.createdAt.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE3D5CA)
                            : _kNavyAnchor,
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
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE3D5CA)
                              : _kNavyAnchor,
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF9A8C73),
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
                      size: 13,
                      color: const Color(0xFFF59E0B),
                    );
                  }),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '"${review.comment}"',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? const Color(0xFFBDB5AA)
                      : const Color(0xFF45474B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortfolioContent extends StatelessWidget {
  const _PortfolioContent({
    required this.jobs,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onViewAll,
    required this.isDark,
    required this.servio,
  });

  final List<BackendBooking> jobs;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    if (loading) return _ShimmerList(count: 3, height: 80, isDark: isDark);
    if (error != null && jobs.isEmpty) {
      return _ErrorCard(message: error!, onRetry: onRetry, isDark: isDark);
    }
    if (jobs.isEmpty) {
      return _EmptyInline(
        message: 'No completed jobs yet.',
        servio: servio,
      );
    }

    final visible = jobs.take(5).toList();
    final hasMore = jobs.length > 5;

    return Column(
      children: <Widget>[
        ...visible.map((job) => _PortfolioCard(job: job, isDark: isDark)),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.list_rounded, size: 18),
                label: Text('View All (${jobs.length} jobs)'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFF9A8C73).withValues(alpha: 0.3),
                  ),
                  foregroundColor:
                      isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.job, required this.isDark});

  final BackendBooking job;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF262B34) : const Color(0xFFF5F3F0);
    final dateStr =
        '${job.scheduledDate.day.toString().padLeft(2, '0')}/'
        '${job.scheduledDate.month.toString().padLeft(2, '0')}/'
        '${job.scheduledDate.year}';
    final location = <String>[job.addressStreet, job.addressCity]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: bg,
          child: InkWell(
            onTap: () => showTransactionDetailsSheet(context, job: job),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                    child: const Icon(
                      Icons.build_rounded,
                      color: ServioColors.deepBrown,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          job.serviceName.isNotEmpty
                              ? job.serviceName
                              : 'Service',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFE3D5CA)
                                : _kNavyAnchor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF9A8C73),
                            ),
                          ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF9A8C73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${(job.totalAmount * 0.95).toInt()} EGP',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9A8C73),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF22C55E),
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

class _AreaContent extends StatelessWidget {
  const _AreaContent({
    required this.locationLabel,
    required this.city,
    required this.isDark,
    required this.servio,
  });

  final String locationLabel;
  final String city;
  final bool isDark;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final label = locationLabel.isNotEmpty
        ? locationLabel
        : (city.isNotEmpty ? city : '');

    if (label.isEmpty) {
      return _EmptyInline(
        message: 'No service area configured.',
        servio: servio,
      );
    }

    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF262B34)
                : const Color(0xFFEFEEEB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.location_on_rounded,
            size: 20,
            color: isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFE3D5CA) : _kNavyAnchor,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.message, required this.servio});

  final String message;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: servio.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
}

class _ShimmerList extends StatefulWidget {
  const _ShimmerList({
    required this.count,
    required this.height,
    required this.isDark,
  });

  final int count;
  final double height;
  final bool isDark;

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final opacity = 0.3 + 0.35 * _ctrl.value;
        final shimmerColor = widget.isDark
            ? Colors.white.withValues(alpha: opacity * 0.15)
            : const Color(0xFF9A8C73).withValues(alpha: opacity * 0.2);
        return Column(
          children: List<Widget>.generate(
            widget.count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(16),
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
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF9A8C73),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

// ── Fade + slide entrance ─────────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, Widget? child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: isDark
              ? const Color(0xFF9A8C73)
              : const Color(0xFF6B6560),
        ),
      ),
    );
  }
}

// ── Menu group ────────────────────────────────────────────────────────────────

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.children,
    required this.isDark,
  });

  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E2229) : Colors.white;
    final border = const Color(0xFF9A8C73).withValues(alpha: 0.08);
    final divider = const Color(0xFF9A8C73).withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              children[i],
              if (i != children.length - 1)
                Divider(height: 1, indent: 64, endIndent: 16, color: divider),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE3D5CA) : const Color(0xFF262B34);
    final subtitleColor =
        isDark ? const Color(0xFF9A8C73) : const Color(0xFF6B6560);
    final chevronColor =
        isDark ? const Color(0xFF9A8C73) : const Color(0xFFBBB5B0);

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: backgroundColor ?? iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: chevronColor,
              ),
            ],
          ),
        ),
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
    const dangerColor = Color(0xFFEF4444);
    return Semantics(
      button: true,
      label: 'Log Out',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: dangerColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            border: Border.all(
              color: dangerColor.withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.logout_rounded, color: dangerColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: dangerColor,
                ),
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Jobs',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF13161C) : _kBgLight,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        itemCount: jobs.length,
        itemBuilder: (context, index) =>
            _PortfolioCard(job: jobs[index], isDark: isDark),
      ),
    );
  }
}

// ── Utility ───────────────────────────────────────────────────────────────────

String _readable(String v) {
  final s = v.trim().replaceAll(RegExp(r'[-_]+'), ' ');
  if (s.isEmpty) return '';
  return s.split(' ').map((w) {
    if (w.isEmpty) return '';
    final u = w.toUpperCase();
    if (u == 'HVAC' || u == 'AC') return u;
    return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
  }).join(' ');
}
