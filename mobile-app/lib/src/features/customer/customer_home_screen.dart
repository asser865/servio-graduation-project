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
import 'ai_room_finisher_screen.dart';
import 'ai_smart_match_screen.dart';
import 'customer_profile_screen.dart';
import 'my_bookings_screen.dart';
import 'service_detail_screen.dart';
import '../shared/search_results_screen.dart';
import 'technician_listing_screen.dart';
import 'technician_profile_screen.dart';
import '../shared/notifications_screen.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late ScrollController _scrollController;
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: ServioMotion.spring),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entranceController.forward();
      context.read<BookingsProvider>().refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<BookingsProvider>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    final upcomingBookings = context.watch<BookingsProvider>().upcoming;
    final pastBookings = context.watch<BookingsProvider>().past;
    final featuredTechs =
        context.watch<WorkersProvider>().workers.take(4).toList();
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    final now = DateTime.now();
    final hour = now.hour;
    final timeWord = locale == 'ar'
        ? (hour < 12 ? 'صباح' : hour < 17 ? 'ظهر' : 'مساء')
        : (hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening');
    final hasUpcoming = upcomingBookings.isNotEmpty;

    // Cycle through 4 greeting styles daily so the screen feels fresh
    final List<(String, String)> greetingVariants = <(String, String)>[
      // (small muted line, big headline)
      (
        locale == 'ar' ? 'صباح الخير،' : 'Good $timeWord,',
        locale == 'ar' ? 'مرحباً، $firstName!' : 'Hello, $firstName!',
      ),
      (
        '',
        locale == 'ar'
            ? 'صباح الخير، $firstName!'
            : 'Good $timeWord, $firstName!',
      ),
      (
        '',
        locale == 'ar'
            ? (hasUpcoming ? 'أهلاً بعودتك، $firstName!' : 'أهلاً، $firstName!')
            : (hasUpcoming ? 'Welcome back, $firstName!' : 'Welcome, $firstName!'),
      ),
      (
        locale == 'ar' ? 'يسعدنا رؤيتك،' : 'Good to see you,',
        '$firstName!',
      ),
    ];
    final (greetingTop, greetingHead) =
        greetingVariants[now.day % greetingVariants.length];

    // Merge: show up to 2 upcoming then fill with past (cap 4 total)
    final activityBookings = [
      ...upcomingBookings.take(2),
      if (upcomingBookings.length < 2) ...pastBookings.take(2 - upcomingBookings.length),
    ].take(4).toList();

    return RefreshIndicator(
      color: servio.accent,
      onRefresh: () async {
        await Future.wait(<Future<void>>[
          context.read<BookingsProvider>().refresh(),
          context.read<NotificationsProvider>().refresh(),
        ]);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          // ── Pinned app bar ─────────────────────────────────────
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: isDark
                ? ServioColors.backgroundDark
                : ServioColors.backgroundSoftLight,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            toolbarHeight: 60,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'SERVIO',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 3.0,
                    color: isDark
                        ? ServioColors.textPrimaryDark
                        : ServioColors.navyDark,
                    height: 1,
                  ),
                ),
                const Spacer(),
                // Notifications bell
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : ServioColors.navyDark)
                          .withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ServioColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 21,
                          color: isDark
                              ? ServioColors.textPrimaryDark
                              : ServioColors.navyDark,
                        ),
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
                // Profile avatar
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomerProfileScreen(),
                    ),
                  ),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? ServioColors.backgroundSoftDark
                          : ServioColors.backgroundSoftLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ServioColors.accent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? ServioColors.textPrimaryDark
                              : ServioColors.navyDark,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: ServioColors.accent.withValues(alpha: 0.15),
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Greeting ───────────────────────────────────
                    _GreetingSection(
                      topLine: greetingTop,
                      headline: greetingHead,
                      isDark: isDark,
                      locale: locale,
                    ),

                    const SizedBox(height: 32),

                    // ── Intelligent Tools ──────────────────────────
                    ServioAnimatedEntry(
                      delay: const Duration(milliseconds: 80),
                      child: _IntelligentToolsSection(
                        isDark: isDark,
                        locale: locale,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Popular Services ───────────────────────────
                    ServioAnimatedEntry(
                      delay: const Duration(milliseconds: 160),
                      child: _PopularServicesSection(
                        isDark: isDark,
                        locale: locale,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Recent Activity ────────────────────────────
                    ServioAnimatedEntry(
                      delay: const Duration(milliseconds: 240),
                      child: _RecentActivitySection(
                        bookings: activityBookings,
                        isDark: isDark,
                        locale: locale,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Recommended Professionals ──────────────────
                    if (featuredTechs.isNotEmpty) ...<Widget>[
                      ServioAnimatedEntry(
                        delay: const Duration(milliseconds: 320),
                        child: _RecommendedProsSection(
                          featuredTechs: featuredTechs,
                          isDark: isDark,
                          locale: locale,
                        ),
                      ),
                    ],

                    SizedBox(height: 40 + bottomInset),
                  ],
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
// Greeting
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({
    required this.topLine,
    required this.headline,
    required this.isDark,
    required this.locale,
  });

  final String topLine;
  final String headline;
  final bool isDark;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
    final textMuted = isDark
        ? ServioColors.textSecondaryDark
        : ServioColors.textSecondaryLight;

    final subtitle = locale == 'ar'
        ? 'كيف يمكننا تحسين منزلك اليوم؟'
        : 'How can we elevate your home sanctuary today?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ServioSpacing.screenPadding,
        24,
        ServioSpacing.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (topLine.isNotEmpty) ...<Widget>[
            Text(
              topLine,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textMuted,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            headline,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intelligent Tools — horizontal scroll
// ─────────────────────────────────────────────────────────────────────────────

class _IntelligentToolsSection extends StatelessWidget {
  const _IntelligentToolsSection({
    required this.isDark,
    required this.locale,
  });

  final bool isDark;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                locale == 'ar' ? 'أدوات ذكية' : 'Intelligent Tools',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Text(
                    locale == 'ar' ? 'بالذكاء الاصطناعي' : 'Powered by AI',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ServioColors.accent,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: ServioColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: ServioSpacing.screenPadding,
            ),
            children: <Widget>[
              _AIToolCard(
                icon: Icons.psychology_rounded,
                title: locale == 'ar' ? 'المطابقة الذكية' : 'Smart Match',
                description: locale == 'ar'
                    ? 'صف مشكلتك وسنجد لك الحرفي المناسب.'
                    : 'Describe your issue naturally. We\'ll find the perfect artisan.',
                isDark: isDark,
                variant: _AIToolVariant.warm,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiSmartMatchScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _AIToolCard(
                icon: Icons.chair_rounded,
                title: locale == 'ar' ? 'مشطّب الغرف' : 'Room Finisher',
                description: locale == 'ar'
                    ? 'تخيّل تغييرات المساحة وتصميمات النجارة.'
                    : 'Visualize layout changes and custom carpentry.',
                isDark: isDark,
                variant: _AIToolVariant.dark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiRoomFinisherScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AIToolVariant { warm, light, dark }

class _AIToolCard extends StatefulWidget {
  const _AIToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
    required this.variant,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final _AIToolVariant variant;
  final VoidCallback onTap;

  @override
  State<_AIToolCard> createState() => _AIToolCardState();
}

class _AIToolCardState extends State<_AIToolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: ServioMotion.fast);
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
    final isDark = widget.isDark;

    Color cardBg;
    Color titleColor;
    Color descColor;
    Color iconBg;
    Color iconColor;

    switch (widget.variant) {
      case _AIToolVariant.warm:
        cardBg = isDark ? ServioColors.surfaceDark : ServioColors.backgroundSoftLight;
        titleColor = isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
        descColor = isDark ? ServioColors.textSecondaryDark : ServioColors.textSecondaryLight;
        iconBg = isDark ? ServioColors.navySoft : Colors.white;
        iconColor = isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
      case _AIToolVariant.light:
        cardBg = isDark ? ServioColors.surfaceAltDark : ServioColors.surfaceLight;
        titleColor = isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
        descColor = isDark ? ServioColors.textSecondaryDark : ServioColors.textSecondaryLight;
        iconBg = isDark ? ServioColors.backgroundSoftDark : ServioColors.backgroundSoftLight;
        iconColor = isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;
      case _AIToolVariant.dark:
        cardBg = isDark ? ServioColors.navySoft : ServioColors.navyDark;
        titleColor = ServioColors.textPrimaryDark;
        descColor = ServioColors.textSecondaryDark;
        iconBg = Colors.white.withValues(alpha: 0.12);
        iconColor = ServioColors.textPrimaryDark;
    }

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
          width: 220,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: widget.variant != _AIToolVariant.dark
                ? Border.all(
                    color: ServioColors.accent.withValues(alpha: 0.15),
                  )
                : null,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.variant == _AIToolVariant.dark
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Decorative corner
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        ServioColors.accent.withValues(
                          alpha: widget.variant == _AIToolVariant.dark
                              ? 0.2
                              : 0.1,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(widget.icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: descColor,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────────────────────────────────────
// Popular Services — bento grid with images
// ─────────────────────────────────────────────────────────────────────────────

class _PopularServicesSection extends StatelessWidget {
  const _PopularServicesSection({
    required this.isDark,
    required this.locale,
  });

  final bool isDark;
  final String locale;

  // Stitch-generated service images (AI public images from Google CDN)
  static const String _plumbingImg =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCAXnVTJSgyqKCKwnAyCpwoUocw0KMCqRMDWq-KvvQ2WH6tFzSBaLW6g6o9tGxDjEpxuB5sQeHsmjg_oA1k9MmlaJ4fwFqixjFjU0m4ttjNTCO-Y4kTTd6B9wO8vW9EGpWGxNgi-qQbu-c6J2dshe3-z1ojsQQeZl7a9mtFoUJ9gg7Dl_QMstW5sB056Bn5hryzH5fZWZwunNyqM3-w-zqSf4r6vKNDy-roWQ9ddrfTUuDnah_Iw7Xkjsznbjv7vqDNW6QEv1tacKOp';
  static const String _electricalImg =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC7XGTH3WO7yqXSfefF2gWDNbwxRiUGjF1NwxfHyrj9eeo7fCJeq1sC5kmYkP04jRCYMy0KzpLNwv8fO9tdtS8kQau2Mg_kJwSORz7xwnrdPby0sPGy7Ki72Buk3CDECjW_7ohhhSTPkt_MgyBPmbAw-1ClX4--DYfxFgwz9YJ3G_FN2tWdKD9niLDNOB4HmQayXhgSTa_Y2ne51W29IrPNEMRajaZNeHJiQNExq06qHKY_S3IGK5rbmbROrUB7kMYeZy6J8Un8T0Ma';
  static const String _cleaningImg =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDTBg2qZVzsTPmw-tcMbDtHSp_WfBAS58zb8guCX10_60TuEebvmL-kCVDLkFe1muL9VSZQbiQium_XROa2yq9JuqkC77bLcZX9yHo7RAtAG3RNGjIgRHZ4K6R6TUn_Mx7qcTr1Ynw9W46RBKaGupubg90HizLCnHcCBA-ptkFV8tUdIZRQ-kjMIzvZ2BSs6mEqAzvDBYB9bmrPsFgbGKxMtQ05nwxHt2KjiA_4zIOo4Fw0bf0pZg3QyiIkU4T5BCH2ZRRz75CLs_Pm';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ServioSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                locale == 'ar' ? 'الخدمات الشائعة' : 'Popular Services',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SearchResultsScreen(query: ''),
                  ),
                ),
                child: Text(
                  locale == 'ar' ? 'عرض الكل' : 'See all',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ServioColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large card — Plumbing
          _ServiceImageCard(
            imageUrl: _plumbingImg,
            label: locale == 'ar' ? 'السباكة' : 'Plumbing',
            badge: locale == 'ar' ? 'طلب عالٍ' : 'High Demand',
            height: 180,
            fullWidth: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ServiceDetailScreen(serviceId: 'plumbing'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Two small cards
          Row(
            children: <Widget>[
              Expanded(
                child: _ServiceImageCard(
                  imageUrl: _electricalImg,
                  label: locale == 'ar' ? 'الكهرباء' : 'Electrical',
                  height: 150,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ServiceDetailScreen(serviceId: 'electrical'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ServiceImageCard(
                  imageUrl: _cleaningImg,
                  label: locale == 'ar' ? 'تنظيف عميق' : 'Deep Clean',
                  height: 150,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ServiceDetailScreen(serviceId: 'cleaning'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceImageCard extends StatefulWidget {
  const _ServiceImageCard({
    required this.imageUrl,
    required this.label,
    required this.height,
    required this.onTap,
    this.badge,
    this.fullWidth = false,
  });

  final String imageUrl;
  final String label;
  final String? badge;
  final double height;
  final bool fullWidth;
  final VoidCallback onTap;

  @override
  State<_ServiceImageCard> createState() => _ServiceImageCardState();
}

class _ServiceImageCardState extends State<_ServiceImageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: ServioMotion.fast);
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

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            widget.fullWidth ? 20 : 16,
          ),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Network image with placeholder
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, Widget child,
                      ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            ServioColors.accent.withValues(alpha: 0.3),
                            ServioColors.navyDark.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          ServioColors.accent.withValues(alpha: 0.4),
                          ServioColors.navyDark,
                        ],
                      ),
                    ),
                  ),
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        ServioColors.navyDark.withValues(alpha: 0.55),
                        ServioColors.navyDark.withValues(alpha: 0.88),
                      ],
                      stops: const <double>[0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Label + badge
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.all(widget.fullWidth ? 20 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (widget.badge != null) ...<Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.badge!.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                widget.label,
                                style: (widget.fullWidth
                                        ? theme.textTheme.titleMedium
                                        : theme.textTheme.labelLarge)
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.fullWidth ? 18 : 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.fullWidth) ...<Widget>[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
// Recent Activity
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.bookings,
    required this.isDark,
    required this.locale,
  });

  final List<BookingModel> bookings;
  final bool isDark;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary =
        isDark ? ServioColors.textPrimaryDark : ServioColors.navyDark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ServioSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                locale == 'ar' ? 'النشاط الأخير' : 'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (bookings.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyBookingsScreen(),
                    ),
                  ),
                  child: Text(
                    locale == 'ar' ? 'عرض الكل' : 'See all',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ServioColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (bookings.isEmpty)
            _EmptyActivityState(isDark: isDark, locale: locale)
          else
            ...bookings.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActivityItem(
                  booking: b,
                  isDark: isDark,
                  locale: locale,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState({required this.isDark, required this.locale});

  final bool isDark;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: isDark
            ? ServioColors.surfaceDark
            : ServioColors.backgroundSoftLight,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(
          color: ServioColors.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            size: 40,
            color: ServioColors.accent.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            locale == 'ar' ? 'كل شيء على ما يرام!' : 'All caught up!',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isDark
                  ? ServioColors.textSecondaryDark
                  : ServioColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            locale == 'ar'
                ? 'لا توجد حجوزات قادمة.'
                : 'No upcoming bookings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: (isDark
                      ? ServioColors.textSecondaryDark
                      : ServioColors.textSecondaryLight)
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.booking,
    required this.isDark,
    required this.locale,
  });

  final BookingModel booking;
  final bool isDark;
  final String locale;

  IconData _iconForBooking(BookingModel b) {
    final cat = b.serviceCategory.toLowerCase();
    if (cat.contains('plumb') || cat.contains('water')) {
      return Icons.water_drop_rounded;
    } else if (cat.contains('electric')) {
      return Icons.electrical_services_rounded;
    } else if (cat.contains('clean')) {
      return Icons.cleaning_services_rounded;
    } else if (cat.contains('ac') || cat.contains('hvac') || cat.contains('cool')) {
      return Icons.ac_unit_rounded;
    } else if (cat.contains('paint')) {
      return Icons.format_paint_rounded;
    } else if (cat.contains('carp') || cat.contains('wood')) {
      return Icons.handyman_rounded;
    }
    return Icons.build_circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = booking.status.isActive;

    final surfaceColor = isDark ? ServioColors.surfaceDark : Colors.white;
    final cardOpacity = isActive ? 1.0 : 0.75;

    final statusLabel = _homeStatusLabel(booking.status);
    final chipType = _homeChipType(booking.status);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingDetailsScreen(
            data: _flowDataFromBooking(booking),
          ),
        ),
      ),
      child: Opacity(
        opacity: cardOpacity,
        child: Container(
          padding: const EdgeInsets.all(ServioSpacing.cardPadding),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ServioColors.accent.withValues(alpha: isActive ? 0.12 : 0.06),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Service icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isActive
                      ? ServioColors.backgroundSoftLight
                      : (isDark
                          ? ServioColors.backgroundSoftDark
                          : ServioColors.surfaceAltLight),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.0 : 1.0),
                  ),
                ),
                child: Icon(
                  _iconForBooking(booking),
                  size: 22,
                  color: isActive
                      ? ServioColors.accent
                      : (isDark
                          ? ServioColors.textSecondaryDark
                          : ServioColors.textSecondaryLight),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.serviceName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark
                            ? ServioColors.textPrimaryDark
                            : ServioColors.navyDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      booking.technicianName.isNotEmpty
                          ? '${booking.date} • ${booking.technicianName}'
                          : booking.date,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? ServioColors.textSecondaryDark
                            : ServioColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status chip
              _AnimatedBookingStatusChip(
                status: booking.status,
                label: statusLabel,
                type: chipType,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    paymentMethodCode:
        booking.paymentMethod.toLowerCase().contains('card') ? 'card' : 'cash',
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

// ─────────────────────────────────────────────────────────────────────────────
// Recommended Professionals
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendedProsSection extends StatelessWidget {
  const _RecommendedProsSection({
    required this.featuredTechs,
    required this.isDark,
    required this.locale,
  });

  final List<dynamic> featuredTechs;
  final bool isDark;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding,
          ),
          child: ServioSectionHeading(
            title: locale == 'ar' ? 'موصى بهم لك' : 'Recommended For You',
            actionLabel: locale == 'ar' ? 'عرض الكل' : 'See All',
            onActionTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TechnicianListingScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: ServioSpacing.screenPadding,
            ),
            itemCount: featuredTechs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (BuildContext context, int index) {
              return _ProfessionalCard(tech: featuredTechs[index]);
            },
          ),
        ),
      ],
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
    _controller =
        AnimationController(vsync: this, duration: ServioMotion.fast);
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
          width: 200,
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
                      width: 52,
                      height: 52,
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
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: ServioColors.tint(servio.success),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.verified_rounded,
                              size: 12, color: servio.success),
                          const SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: servio.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  specialty,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded,
                        size: 15, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(tech.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelMedium),
                    const SizedBox(width: 5),
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
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

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

class _AnimatedBookingStatusChipState
    extends State<_AnimatedBookingStatusChip>
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

// ─────────────────────────────────────────────────────────────────────────────
// Status helpers
// ─────────────────────────────────────────────────────────────────────────────

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
    BookingStatus.pendingAdminReview => 'Under Review',
    BookingStatus.cancelledNoShow => 'Cancelled (No-Show)',
    BookingStatus.customerNoShow => 'Customer No-Show',
    BookingStatus.workerNoShow => 'Worker No-Show',
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
    BookingStatus.pendingAdminReview => ServioStatusChipType.warning,
    BookingStatus.cancelledNoShow => ServioStatusChipType.danger,
    BookingStatus.customerNoShow => ServioStatusChipType.danger,
    BookingStatus.workerNoShow => ServioStatusChipType.danger,
  };
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
      BookingStatus.pendingAdminReview => 'pending_admin_review',
      BookingStatus.cancelledNoShow => 'cancelled_no_show',
      BookingStatus.customerNoShow => 'customer_no_show',
      BookingStatus.workerNoShow => 'worker_no_show',
    };
