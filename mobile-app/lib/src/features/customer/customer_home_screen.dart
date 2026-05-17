import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/booking_model.dart';
import '../../core/models/service_category.dart';
import '../../core/state/app_state.dart';
import '../../core/state/notifications_provider.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_animated_entry.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'ai_finishing_estimator_screen.dart';
import 'ai_smart_match_screen.dart';
import 'customer_profile_screen.dart';
import 'my_addresses_screen.dart';
import 'my_bookings_screen.dart';
import 'service_detail_screen.dart';
import 'services_marketplace_screen.dart';
import 'technician_listing_screen.dart';
import 'technician_profile_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/search_results_screen.dart';
import '../booking/booking_flow_data.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const _HomeBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.8, curve: ServioMotion.spring),
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.055),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entranceController, curve: ServioMotion.spring));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    final userName = context.watch<SessionProvider>().account?.name ?? 'there';
    final firstName = userName.split(' ').first;
    final initials = userName
        .split(' ')
        .take(2)
        .map((String e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .where((String c) => c.isNotEmpty)
        .join();
    final recentBookings = context.watch<BookingsProvider>().upcoming;
    final featuredTechs =
        context.watch<WorkersProvider>().workers.take(4).toList();
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    }

    return Stack(
      children: <Widget>[
        // ── Layer 1: Animated full-screen gradient + floating icons ──
        AnimatedBuilder(
          animation: _scrollController,
          builder: (BuildContext context, Widget? child) {
            double offset = 0;
            if (_scrollController.hasClients) {
              offset = _scrollController.offset;
              if (offset < 0) offset = 0;
            }
            return Positioned(
              top: -offset * 0.3,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 1.8,
              child: child!,
            );
          },
          child: _BackgroundLayer(isDark: isDark),
        ),

        // ── Layer 2: Scrollable dashboard content ────────────────────
        RefreshIndicator(
          color: servio.accent,
          onRefresh: () async {
            await Future.wait(<Future<void>>[
              context.read<BookingsProvider>().refresh(),
              context.read<NotificationsProvider>().refresh(),
            ]);
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: <Widget>[
                // ── Dashboard header ─────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ServioSpacing.screenPadding,
                      12,
                      ServioSpacing.screenPadding,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ── Wordmark + actions ───────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            _ServioWordmark(isDark: isDark),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              ),
                              child: _HeaderIconButton(
                                isDark: isDark,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      color: isDark
                                          ? ServioColors.navyDark
                                          : Colors.white,
                                      size: 22,
                                    ),
                                    // Pulsing notification badge
                                    const Positioned(
                                      top: 9,
                                      right: 9,
                                      child: _PulsingDot(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _ProfileAvatar(
                              initials: initials,
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CustomerProfileScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Greeting + location pill ─────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    greeting,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? ServioColors.navyDark
                                              .withValues(alpha: 0.58)
                                          : Colors.white
                                              .withValues(alpha: 0.72),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    firstName,
                                    style:
                                        theme.textTheme.headlineLarge?.copyWith(
                                      color: isDark
                                          ? ServioColors.navyDark
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _LocationPill(
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const MyAddressesScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Search bar ───────────────────────────────
                        _HeroSearchBar(isDark: isDark),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Animated content card ────────────────────────────
                FadeTransition(
                  opacity: _entranceFade,
                  child: SlideTransition(
                    position: _entranceSlide,
                    child: Container(
                      margin: const EdgeInsets.only(top: 40),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 32,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Transform.translate(
                        offset: const Offset(0, -48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // ── Booking card ─────────────────────────
                            ServioAnimatedEntry(
                              delay: const Duration(milliseconds: 80),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ServioSpacing.screenPadding,
                                ),
                                child: recentBookings.isNotEmpty
                                    ? _FloatingBookingCard(
                                        booking: recentBookings.first,
                                        locale: locale,
                                      )
                                    : _FloatingEmptyBookingCard(locale: locale),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Services grid ─────────────────────────
                            ServioAnimatedEntry(
                              delay: const Duration(milliseconds: 160),
                              child: Container(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.015)
                                    : servio.backgroundSoft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ServioSpacing.screenPadding,
                                  vertical: 28,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    ServioSectionHeading(
                                      title: locale == 'ar'
                                          ? 'الخدمات'
                                          : 'Services',
                                      actionLabel: locale == 'ar'
                                          ? 'عرض الكل'
                                          : 'See All',
                                      onActionTap: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ServicesMarketplaceScreen(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _CategoriesGrid(locale: locale),
                                  ],
                                ),
                              ),
                            ),

                            // ── AI Smart Match banner ─────────────────
                            ServioAnimatedEntry(
                              delay: const Duration(milliseconds: 240),
                              child: Container(
                                color: theme.scaffoldBackgroundColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ServioSpacing.screenPadding,
                                  vertical: 28,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _HeroBannerCard(
                                      badgeLabel: 'NEW FEATURE',
                                      title: 'AI Smart Match',
                                      body:
                                          'Snap a photo and let AI find the perfect pro.',
                                      ctaLabel: 'Try AI Assistant',
                                      icon: Icons.auto_awesome_rounded,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AiSmartMatchScreen(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _HeroBannerCard(
                                      badgeLabel: 'AI ESTIMATE',
                                      title: 'AI Cost Estimator',
                                      body:
                                          'Get a room finishing budget before you book.',
                                      ctaLabel: 'Estimate Cost',
                                      icon: Icons.calculate_rounded,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AiFinishingEstimatorScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ── Recommended professionals ─────────────
                            ServioAnimatedEntry(
                              delay: const Duration(milliseconds: 320),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.01)
                                      : servio.backgroundSoft
                                          .withValues(alpha: 0.5),
                                  border: Border(
                                    top: BorderSide(
                                      color:
                                          servio.border.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  ServioSpacing.screenPadding,
                                  28,
                                  0,
                                  48,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: ServioSpacing.screenPadding,
                                      ),
                                      child: ServioSectionHeading(
                                        title: locale == 'ar'
                                            ? 'موصى بهم لك'
                                            : 'Recommended For You',
                                        actionLabel: locale == 'ar'
                                            ? 'عرض الكل'
                                            : 'See All',
                                        onActionTap: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const TechnicianListingScreen(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _FeaturedProfessionals(
                                      featuredTechs: featuredTechs,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 40 + bottomInset),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background — gradient + floating ambient service icons
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class _FloatingIconDef {
  const _FloatingIconDef({
    required this.icon,
    required this.xFrac,
    required this.yFrac,
    required this.size,
    required this.phase,
    required this.periodMs,
    this.hAmplitude = 7.0,
    this.hPhase = 0.0,
    this.opacity = 1.0,
  });

  final IconData icon;
  final double xFrac;
  final double yFrac;
  final double size;

  /// 0.0–1.0 starting phase so icons are never in sync.
  final double phase;

  /// Float cycle duration in milliseconds.
  final int periodMs;

  /// Horizontal drift amplitude in pixels. Driven by math.sin for
  /// an independent X-axis path that doesn't mirror vertical movement.
  final double hAmplitude;

  /// Radians offset for the horizontal sine wave.
  final double hPhase;

  /// Per-icon opacity multiplier (0.0–1.0) to simulate depth layers.
  final double opacity;
}

class _BackgroundLayer extends StatefulWidget {
  const _BackgroundLayer({required this.isDark});

  final bool isDark;

  @override
  State<_BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<_BackgroundLayer>
    with TickerProviderStateMixin {
  // Ambient service icons scattered across the gradient header zone.
  // 15 icons ALL within the visible gradient header zone (yFrac ≤ 0.28).
  // Icons with yFrac > ~0.30 are hidden behind the opaque content card.
  // Three depth layers create parallax depth: near (large/fast/opaque),
  // mid (medium), far (small/slow/subtle).
  static const List<_FloatingIconDef> _icons = <_FloatingIconDef>[
    // ── Near layer — large, fast, full opacity ───────────────────────────────
    _FloatingIconDef(
        icon: Icons.cleaning_services_rounded,
        xFrac: 0.82,
        yFrac: 0.04,
        size: 34,
        phase: 0.00,
        periodMs: 4800,
        hAmplitude: 9,
        hPhase: 0.80,
        opacity: 1.0),
    _FloatingIconDef(
        icon: Icons.plumbing_rounded,
        xFrac: 0.06,
        yFrac: 0.11,
        size: 32,
        phase: 0.44,
        periodMs: 5200,
        hAmplitude: 8,
        hPhase: 2.10,
        opacity: 1.0),
    _FloatingIconDef(
        icon: Icons.handyman_rounded,
        xFrac: 0.90,
        yFrac: 0.23,
        size: 30,
        phase: 0.71,
        periodMs: 4600,
        hAmplitude: 10,
        hPhase: 3.60,
        opacity: 1.0),
    _FloatingIconDef(
        icon: Icons.home_repair_service_rounded,
        xFrac: 0.44,
        yFrac: 0.16,
        size: 32,
        phase: 0.28,
        periodMs: 5400,
        hAmplitude: 7,
        hPhase: 1.40,
        opacity: 1.0),
    _FloatingIconDef(
        icon: Icons.construction_rounded,
        xFrac: 0.20,
        yFrac: 0.05,
        size: 28,
        phase: 0.55,
        periodMs: 4200,
        hAmplitude: 11,
        hPhase: 4.20,
        opacity: 1.0),

    // ── Mid layer — medium, moderate, 80 % opacity ───────────────────────────
    _FloatingIconDef(
        icon: Icons.electrical_services_rounded,
        xFrac: 0.18,
        yFrac: 0.21,
        size: 26,
        phase: 0.62,
        periodMs: 6400,
        hAmplitude: 10,
        hPhase: 0.30,
        opacity: 0.80),
    _FloatingIconDef(
        icon: Icons.format_paint_rounded,
        xFrac: 0.63,
        yFrac: 0.07,
        size: 27,
        phase: 0.18,
        periodMs: 5800,
        hAmplitude: 9,
        hPhase: 4.20,
        opacity: 0.80),
    _FloatingIconDef(
        icon: Icons.ac_unit_rounded,
        xFrac: 0.34,
        yFrac: 0.26,
        size: 25,
        phase: 0.85,
        periodMs: 6800,
        hAmplitude: 8,
        hPhase: 1.80,
        opacity: 0.80),
    _FloatingIconDef(
        icon: Icons.local_laundry_service_rounded,
        xFrac: 0.72,
        yFrac: 0.19,
        size: 24,
        phase: 0.36,
        periodMs: 6200,
        hAmplitude: 12,
        hPhase: 3.00,
        opacity: 0.80),
    _FloatingIconDef(
        icon: Icons.carpenter,
        xFrac: 0.52,
        yFrac: 0.27,
        size: 26,
        phase: 0.57,
        periodMs: 5600,
        hAmplitude: 7,
        hPhase: 5.00,
        opacity: 0.80),

    // ── Far layer — small, slow, 55 % opacity ────────────────────────────────
    _FloatingIconDef(
        icon: Icons.auto_awesome_rounded,
        xFrac: 0.55,
        yFrac: 0.02,
        size: 20,
        phase: 0.90,
        periodMs: 7800,
        hAmplitude: 13,
        hPhase: 2.50,
        opacity: 0.55),
    _FloatingIconDef(
        icon: Icons.security_rounded,
        xFrac: 0.27,
        yFrac: 0.13,
        size: 19,
        phase: 0.13,
        periodMs: 8200,
        hAmplitude: 14,
        hPhase: 0.60,
        opacity: 0.55),
    _FloatingIconDef(
        icon: Icons.grass_rounded,
        xFrac: 0.78,
        yFrac: 0.27,
        size: 21,
        phase: 0.48,
        periodMs: 7400,
        hAmplitude: 11,
        hPhase: 4.80,
        opacity: 0.55),
    _FloatingIconDef(
        icon: Icons.wifi_rounded,
        xFrac: 0.09,
        yFrac: 0.27,
        size: 18,
        phase: 0.76,
        periodMs: 8600,
        hAmplitude: 10,
        hPhase: 2.20,
        opacity: 0.55),
    _FloatingIconDef(
        icon: Icons.pest_control_rounded,
        xFrac: 0.38,
        yFrac: 0.08,
        size: 17,
        phase: 0.33,
        periodMs: 9000,
        hAmplitude: 12,
        hPhase: 1.10,
        opacity: 0.55),
  ];

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _offsets;
  late final List<Animation<double>> _rotations;
  late final List<Animation<double>> _scales;

  // Alternate rotation direction per icon for organic feel.
  static const List<double> _rotDir = <double>[
    1,
    -1,
    1,
    -1,
    1,
    -1,
    1,
    -1,
    1,
    -1,
    1,
    -1,
    1,
    -1,
    1,
  ];

  @override
  void initState() {
    super.initState();
    // value: def.phase pre-positions each controller before repeat() starts,
    // avoiding the stop() side-effect of the .value setter on a live controller.
    _controllers = _icons
        .map((def) => AnimationController(
              vsync: this,
              duration: Duration(milliseconds: def.periodMs),
              value: def.phase,
            )..repeat(reverse: true))
        .toList();

    // Vertical float ±18 px.
    _offsets = List<Animation<double>>.generate(
      _icons.length,
      (i) => Tween<double>(begin: -18.0, end: 18.0).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOutSine),
      ),
    );

    // Gentle ±4° rotation — alternating direction per icon.
    _rotations = List<Animation<double>>.generate(
      _icons.length,
      (i) => Tween<double>(
        begin: -0.07 * _rotDir[i],
        end: 0.07 * _rotDir[i],
      ).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOutSine),
      ),
    );

    // Subtle scale breath 0.88 → 1.0 — makes icons feel alive, not stamped.
    _scales = List<Animation<double>>.generate(
      _icons.length,
      (i) => Tween<double>(begin: 0.86, end: 1.0).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOutSine),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = widget.isDark;
    final iconColor = isDark ? ServioColors.navyDark : Colors.white;
    // Base opacity — multiplied by each icon's per-layer depth opacity.
    const double baseOpacity = 0.18;

    final gradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFEDE0D5),
              ServioColors.neutralWarm,
              Color(0xFFA68B7B),
              Color(0xFF907060),
            ],
            stops: <double>[0.0, 0.3, 0.7, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF4A2418),
              ServioColors.deepBrown,
              ServioColors.navyDark,
              Color(0xFF1A1F2E),
            ],
            stops: <double>[0.0, 0.28, 0.65, 1.0],
          );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: <Widget>[
          // ── Static radial blobs ────────────────────────────────────
          Positioned(
            top: -70,
            right: -90,
            child: _DecorativeBlob(
              size: 340,
              color: (isDark ? ServioColors.navyDark : Colors.white)
                  .withValues(alpha: isDark ? 0.07 : 0.09),
            ),
          ),
          Positioned(
            top: 200,
            left: -110,
            child: _DecorativeBlob(
              size: 280,
              color: (isDark ? ServioColors.accent : Colors.white)
                  .withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 20,
            child: _DecorativeBlob(
              size: 200,
              color: (isDark ? ServioColors.navyDark : ServioColors.accent)
                  .withValues(alpha: isDark ? 0.05 : 0.08),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: _DecorativeBlob(
              size: 260,
              color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.03),
            ),
          ),

          // ── Floating ambient service icons (composited layer) ──────
          RepaintBoundary(
            child: Stack(
              children: List<Widget>.generate(_icons.length, (i) {
                final def = _icons[i];
                return Positioned(
                  left: screenSize.width * def.xFrac - def.size / 2,
                  top: screenSize.height * def.yFrac,
                  child: AnimatedBuilder(
                    animation: _controllers[i],
                    builder: (_, Widget? child) {
                      // Horizontal drift via math.sin — fully independent from
                      // the vertical easeInOutSine, giving each icon a unique
                      // Lissajous-like path through the background.
                      final dx = def.hAmplitude *
                          math.sin(
                              _controllers[i].value * math.pi * 2 + def.hPhase);
                      return Transform.translate(
                        offset: Offset(dx, _offsets[i].value),
                        child: Transform.rotate(
                          angle: _rotations[i].value,
                          child: Transform.scale(
                            scale: _scales[i].value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Icon(
                      def.icon,
                      size: def.size,
                      color: iconColor.withValues(
                          alpha: baseOpacity * def.opacity),
                    ),
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

class _DecorativeBlob extends StatelessWidget {
  const _DecorativeBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header components
// ─────────────────────────────────────────────────────────────────────────────

class _ServioWordmark extends StatelessWidget {
  const _ServioWordmark({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      'SERVIO',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w800,
        fontSize: 21,
        letterSpacing: 3.2,
        color: isDark ? ServioColors.navyDark : Colors.white,
        height: 1,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onColor = isDark ? ServioColors.navyDark : Colors.white;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: onColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Notification badge dot that slowly pulses to draw attention.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: ServioColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Profile avatar with spring press animation.
class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.isDark,
    required this.onTap,
  });

  final String initials;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ServioMotion.fast);
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onColor = widget.isDark ? ServioColors.navyDark : Colors.white;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: ServioGradients.warm,
            shape: BoxShape.circle,
            border: Border.all(
              color: onColor.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.initials.isEmpty ? '?' : widget.initials,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: ServioColors.deepBrown,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Location pill with fade-on-press feedback.
class _LocationPill extends StatefulWidget {
  const _LocationPill({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_LocationPill> createState() => _LocationPillState();
}

class _LocationPillState extends State<_LocationPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ServioMotion.fast);
    _opacity = Tween<double>(begin: 1.0, end: 0.55).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = widget.isDark ? ServioColors.navyDark : Colors.white;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: onColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(ServioRadius.full),
            border: Border.all(
              color: onColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.location_on_rounded, size: 15, color: onColor),
              const SizedBox(width: 5),
              Text(
                'Cairo',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: onColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar — AI sparkle icon independently navigates to Smart Match
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSearchBar extends StatelessWidget {
  const _HeroSearchBar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => const SearchResultsScreen(query: '')),
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, color: servio.textSecondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'What do you need help with?',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: servio.textSecondary),
              ),
            ),
            // AI icon — independently tappable + slowly breathes
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiSmartMatchScreen(),
                ),
              ),
              child: const _BreathingAiIcon(),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI sparkle icon with a slow inhale/exhale scale animation.
class _BreathingAiIcon extends StatefulWidget {
  const _BreathingAiIcon();

  @override
  State<_BreathingAiIcon> createState() => _BreathingAiIconState();
}

class _BreathingAiIconState extends State<_BreathingAiIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          gradient: ServioGradients.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 17,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking cards
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingBookingCard extends StatelessWidget {
  const _FloatingBookingCard({
    required this.booking,
    required this.locale,
  });

  final BookingModel booking;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final isInProgress = booking.status == BookingStatus.inProgress;
    final statusType = _homeChipType(booking.status);
    final statusLabel = isInProgress
        ? (locale == 'ar' ? 'قيد التنفيذ' : 'En Route')
        : (locale == 'ar' ? 'قادم' : 'Upcoming');

    final displayStatusLabel = _homeStatusLabel(booking.status).isNotEmpty
        ? _homeStatusLabel(booking.status)
        : statusLabel;

    return ServioCard(
      radius: ServioRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      ServioColors.tint(servio.accent),
                      servio.backgroundSoft,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                ),
                child: Icon(Icons.build_circle_outlined,
                    color: servio.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.serviceName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.date,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      booking.technicianName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
              _AnimatedBookingStatusChip(
                status: booking.status,
                label: displayStatusLabel,
                type: statusType,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: servio.border),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const MyBookingsScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ServioRadius.full)),
                  ),
                  child: Text(locale == 'ar' ? 'التفاصيل' : 'View Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BookingDetailsScreen(
                          data: _flowDataFromBooking(booking),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: servio.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ServioRadius.full)),
                  ),
                  child: Text(locale == 'ar' ? 'تتبع الطلب' : 'Track Status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BookingFlowData _flowDataFromBooking(BookingModel booking) {
    return BookingFlowData(
      backendId: booking.id,
      serviceName: booking.serviceName,
      serviceId: booking.serviceId,
      category: booking.serviceCategory,
      technicianName: booking.technicianName,
      technicianId: booking.technicianId,
      date: booking.date,
      time: booking.time,
      location: booking.location,
      amount: booking.amount,
      reference: booking.reference,
      pin: booking.pin,
      paymentMethod: booking.paymentMethod,
      paymentMethodCode: booking.paymentMethod.toLowerCase().contains('card')
          ? 'card'
          : 'cash',
      savedCardLabel: _cardLabelFor(booking),
      savedCardLast4: booking.paymentCardLast4,
      statusLabel: _homeStatusLabel(booking.status),
      statusCode: _statusCodeFromStatus(booking.status),
    );
  }

  String _cardLabelFor(BookingModel booking) {
    if (booking.paymentCardLabel.isNotEmpty) return booking.paymentCardLabel;
    if (booking.paymentCardLast4.isNotEmpty) {
      return 'Card ending ${booking.paymentCardLast4}';
    }
    return '';
  }

  String _statusCodeFromStatus(BookingStatus status) => switch (status) {
        BookingStatus.pending => 'pending',
        BookingStatus.confirmed => 'confirmed',
        BookingStatus.enRoute => 'en_route',
        BookingStatus.arrived => 'arrived',
        BookingStatus.inProgress => 'in_progress',
        BookingStatus.awaitingCustomerConfirmation =>
          'awaiting_customer_confirmation',
        BookingStatus.completed => 'completed',
        BookingStatus.cancelled => 'cancelled',
        BookingStatus.rejected => 'rejected',
        BookingStatus.disputed => 'disputed',
      };
}

class _AnimatedBookingStatusChip extends StatefulWidget {
  const _AnimatedBookingStatusChip({
    required this.status,
    required this.label,
    required this.type,
  });

  final BookingStatus status;
  final String label;
  final ServioStatusChipType type;

  @override
  State<_AnimatedBookingStatusChip> createState() =>
      _AnimatedBookingStatusChipState();
}

class _AnimatedBookingStatusChipState extends State<_AnimatedBookingStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0,
      upperBound: 1,
    );
    if (_shouldPulse) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AnimatedBookingStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _shouldPulse =>
      widget.status == BookingStatus.enRoute ||
      widget.status == BookingStatus.arrived ||
      widget.status == BookingStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget chip = AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : ServioMotion.normal,
      child: ServioStatusChip(
        key: ValueKey<String>(widget.label),
        label: widget.label,
        type: widget.type,
      ),
    );

    if (_shouldPulse && !reduceMotion) {
      chip = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: 1 + (_pulse.value * 0.035),
          child: child,
        ),
        child: chip,
      );
    }

    return chip;
  }
}

String _homeStatusLabel(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => 'Pending',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.enRoute => 'En Route',
    BookingStatus.arrived => 'Arrived',
    BookingStatus.inProgress => 'In Progress',
    BookingStatus.awaitingCustomerConfirmation => 'Awaiting Confirmation',
    BookingStatus.completed => 'Completed',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.rejected => 'Rejected',
    BookingStatus.disputed => 'Disputed',
    BookingStatus.awaitingCustomerConfirmation => 'Awaiting Confirmation',
    BookingStatus.pendingAdminReview => 'Under Review',
  };
}

ServioStatusChipType _homeChipType(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => ServioStatusChipType.warning,
    BookingStatus.confirmed => ServioStatusChipType.success,
    BookingStatus.enRoute => ServioStatusChipType.info,
    BookingStatus.arrived => ServioStatusChipType.info,
    BookingStatus.inProgress => ServioStatusChipType.info,
    BookingStatus.awaitingCustomerConfirmation => ServioStatusChipType.warning,
    BookingStatus.completed => ServioStatusChipType.success,
    BookingStatus.cancelled => ServioStatusChipType.danger,
    BookingStatus.rejected => ServioStatusChipType.danger,
    BookingStatus.disputed => ServioStatusChipType.warning,
    BookingStatus.awaitingCustomerConfirmation => ServioStatusChipType.warning,
    BookingStatus.pendingAdminReview => ServioStatusChipType.warning,
  };
}

class _FloatingEmptyBookingCard extends StatelessWidget {
  const _FloatingEmptyBookingCard({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return ServioCard(
      radius: ServioRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: ServioGradients.warm,
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: ServioColors.deepBrown,
              size: 23,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  locale == 'ar' ? 'لا توجد حجوزات نشطة' : 'No active bookings',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  locale == 'ar'
                      ? 'احجز خدمتك الأولى الآن'
                      : 'Book your first service today',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServicesMarketplaceScreen(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient:
                    isDark ? ServioGradients.brandDark : ServioGradients.brand,
                borderRadius: BorderRadius.circular(ServioRadius.full),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ServioColors.deepBrown.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                locale == 'ar' ? 'احجز' : 'Book Now',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark ? ServioColors.navyDark : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Services grid
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 0.82,
      crossAxisSpacing: 12,
      mainAxisSpacing: 18,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        _CategoryItem(
          icon: Icons.cleaning_services_rounded,
          label: locale == 'ar' ? 'تنظيف' : 'Cleaning',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'cleaning')),
          ),
        ),
        _CategoryItem(
          icon: Icons.plumbing_rounded,
          label: locale == 'ar' ? 'سباكة' : 'Plumbing',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'plumbing')),
          ),
        ),
        _CategoryItem(
          icon: Icons.electrical_services_rounded,
          label: locale == 'ar' ? 'كهرباء' : 'Electrical',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'electrical')),
          ),
        ),
        _CategoryItem(
          icon: Icons.format_paint_rounded,
          label: locale == 'ar' ? 'دهان' : 'Painting',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'painting')),
          ),
        ),
        _CategoryItem(
          icon: Icons.ac_unit_rounded,
          label: locale == 'ar' ? 'تكييف' : 'HVAC',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'ac-maintenance')),
          ),
        ),
        _CategoryItem(
          icon: Icons.handyman_rounded,
          label: locale == 'ar' ? 'نجارة' : 'Carpentry',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'carpentry')),
          ),
        ),
        _CategoryItem(
          icon: Icons.local_shipping_rounded,
          label: locale == 'ar' ? 'نقل' : 'Moving',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const ServicesMarketplaceScreen()),
          ),
        ),
        _CategoryItem(
          icon: Icons.apps_rounded,
          label: locale == 'ar' ? 'المزيد' : 'More',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const ServicesMarketplaceScreen()),
          ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatefulWidget {
  const _CategoryItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ServioMotion.fast);
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    servio.accent.withValues(alpha: 0.13),
                    servio.backgroundSoft,
                  ],
                ),
                borderRadius: BorderRadius.circular(ServioRadius.lg),
                border: Border.all(
                  color: servio.border.withValues(alpha: 0.7),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: servio.accent.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: servio.accent, size: 27),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured professionals
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedProfessionals extends StatelessWidget {
  const _FeaturedProfessionals({required this.featuredTechs});

  final List<dynamic> featuredTechs;

  @override
  Widget build(BuildContext context) {
    if (featuredTechs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featuredTechs.length,
        clipBehavior: Clip.none,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (BuildContext context, int index) {
          return _ProfessionalCard(tech: featuredTechs[index]);
        },
      ),
    );
  }
}

class _ProfessionalCard extends StatefulWidget {
  const _ProfessionalCard({required this.tech});

  final dynamic tech;

  @override
  State<_ProfessionalCard> createState() => _ProfessionalCardState();
}

class _ProfessionalCardState extends State<_ProfessionalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ServioMotion.fast);
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final tech = widget.tech;
    final name = tech.name as String;
    final specialty =
        tech.skills.isNotEmpty ? tech.skills.first as String : 'Specialist';
    final selectedCategory = normalizeServiceCategory(specialty);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TechnicianProfileScreen(
              technicianId: tech.id,
              selectedServiceCategory:
                  selectedCategory.isEmpty ? null : selectedCategory,
              selectedServiceName: selectedCategory.isEmpty
                  ? (specialty == 'Specialist' ? null : specialty)
                  : serviceCategoryLabel(selectedCategory),
            ),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 240,
          child: ServioCard(
            radius: ServioRadius.xl,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: ServioGradients.warm,
                        shape: BoxShape.circle,
                        border: Border.all(color: servio.border, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          name
                              .split(' ')
                              .take(2)
                              .map((String e) => e[0])
                              .join(),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: ServioColors.deepBrown),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ServioColors.tint(servio.success),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.verified_rounded,
                              size: 13, color: servio.success),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: servio.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  specialty,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: servio.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded,
                        size: 17, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(tech.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelLarge),
                    const SizedBox(width: 6),
                    Text(
                      '(${tech.reviewCount})',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI hero banner — with press scale animation
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBannerCard extends StatefulWidget {
  const _HeroBannerCard({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.icon,
    required this.onTap,
    this.badgeLabel,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  State<_HeroBannerCard> createState() => _HeroBannerCardState();
}

class _HeroBannerCardState extends State<_HeroBannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ServioMotion.fast);
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient:
                isDark ? ServioGradients.brandDark : ServioGradients.brand,
            borderRadius: BorderRadius.circular(ServioRadius.xl),
            boxShadow:
                isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  widget.icon,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.badgeLabel != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: servio.accent,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        widget.badgeLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: isDark ? ServioColors.navyDark : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: (isDark ? ServioColors.navyDark : Colors.white)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Text(
                        widget.ctaLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isDark
                              ? ServioColors.navyDark.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: isDark
                            ? ServioColors.navyDark.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
