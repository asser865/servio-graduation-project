import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/reviews_api.dart';
import '../../core/api/users_api.dart';
import '../../core/models/backend_worker_model.dart';
import '../../core/models/service_category.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../core/state/workers_state.dart';
import '../booking/booking_flow_data.dart';
import '../booking/booking_step_one_screen.dart';
import '../messages/chat_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _kHeroExpandedHeight = 320.0;
const _kNavy = Color(0xFF1A1D23);
const _kBrown = Color(0xFF3E2723);
const _kTaupe = Color(0xFF9A8C73);
const _kSurfaceWarm = Color(0xFFF3EDE7);
const _kBgLight = Color(0xFFFBF9F6);
const _kTextMuted = Color(0xFF6B6560);

// ── Screen ─────────────────────────────────────────────────────────────────────

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({
    this.technicianId,
    this.selectedServiceId,
    this.selectedServiceName,
    this.selectedServiceCategory,
    super.key,
  });

  final String? technicianId;
  final String? selectedServiceId;
  final String? selectedServiceName;
  final String? selectedServiceCategory;

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen>
    with TickerProviderStateMixin {
  // ── Animations ──
  late final AnimationController _entranceCtrl;
  late final AnimationController _statsCtrl;
  late final AnimationController _badgeCtrl;

  late final Animation<double> _section0;
  late final Animation<double> _section1;
  late final Animation<double> _section2;
  late final Animation<double> _section3;

  // ── Scroll ──
  final ScrollController _scrollCtrl = ScrollController();
  bool _headerOpaque = false;

  // ── Data ──
  BackendWorker? _worker;
  List<ReviewResult> _reviews = <ReviewResult>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

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

    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  Animation<double> _curved(double start, double end) => CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  void _onScroll() {
    final opaque =
        _scrollCtrl.offset > (_kHeroExpandedHeight - kToolbarHeight - 16);
    if (opaque != _headerOpaque) setState(() => _headerOpaque = opaque);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _statsCtrl.dispose();
    _badgeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final technicianId = widget.technicianId?.trim();
    if (technicianId == null || technicianId.isEmpty) {
      setState(() {
        _error = 'Technician profile not found.';
        _loading = false;
      });
      return;
    }
    final workersProvider = context.read<WorkersProvider>();
    final client = context.read<ApiClient>();
    final cached = workersProvider.findById(technicianId);
    if (cached != null) {
      setState(() {
        _worker = cached;
        _loading = false;
      });
      _entranceCtrl.forward();
      _statsCtrl.forward();
    }
    try {
      final worker = await UsersApi(client).getWorkerById(technicianId);
      if (mounted) {
        setState(() {
          _worker = worker;
          _loading = false;
          _error = null;
        });
        if (!_entranceCtrl.isCompleted) {
          _entranceCtrl.forward();
          _statsCtrl.forward();
        }
      }
    } catch (e) {
      if (mounted && _worker == null) {
        setState(() =>
            _error = 'Unable to load technician profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted || _worker == null) return;
    try {
      final reviews =
          await ReviewsApi(client).getWorkerReviews(technicianId);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading && _worker == null) {
      return const Scaffold(
        backgroundColor: _kBgLight,
        body: Center(
          child: CircularProgressIndicator(color: _kTaupe),
        ),
      );
    }

    if (_error != null && _worker == null) {
      return _ErrorScaffold(
        error: _error!,
        canRetry: widget.technicianId?.trim().isNotEmpty == true,
        onRetry: _load,
      );
    }

    final worker = _worker!;
    final locale = context.watch<LocaleProvider>().languageCode;
    final workerName = worker.displayName;
    final serviceLabels = worker.serviceLabels;
    final primaryBackendService =
        worker.services.isNotEmpty ? worker.services.first : null;
    final primaryService =
        serviceLabels.isNotEmpty ? serviceLabels.first : '';
    final selectedBackendService = _selectedWorkerService(
      worker,
      serviceId: widget.selectedServiceId,
      serviceName: widget.selectedServiceName,
      category: widget.selectedServiceCategory,
    );
    final selectedServiceName = _firstNonEmpty(<String?>[
      widget.selectedServiceName,
      selectedBackendService?.displayName,
      primaryService,
      _copy(locale, en: 'Service visit', ar: 'زيارة خدمة'),
    ]);
    final selectedServiceId = _firstNonEmpty(<String?>[
      selectedBackendService?.id,
      widget.selectedServiceId,
      primaryBackendService?.id,
    ]);
    final selectedServiceCategory = _firstNonEmpty(<String?>[
      selectedBackendService?.category,
      widget.selectedServiceCategory,
      primaryBackendService?.category,
      worker.categories.isNotEmpty ? worker.categories.first : null,
      worker.skills.isNotEmpty ? worker.skills.first : null,
    ]);
    final bookingPriceService =
        selectedBackendService ?? primaryBackendService;
    final locationLabel = worker.locationLabel.isNotEmpty
        ? worker.locationLabel
        : _copy(locale, en: 'Cairo', ar: 'القاهرة');
    final ratingLabel =
        worker.rating > 0 ? worker.rating.toStringAsFixed(1) : 'N/A';
    final bookingBaseAmount =
        _bookingBaseAmount(bookingPriceService, worker.hourlyRate);
    final bookingPriceLabel = _bookingPriceLabel(
      bookingPriceService,
      worker.hourlyRate,
      locale,
    );

    return Scaffold(
      backgroundColor: _kBgLight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              // ── Collapsible hero ─────────────────────────────────────────
              SliverAppBar(
                expandedHeight: _kHeroExpandedHeight,
                pinned: true,
                stretch: true,
                backgroundColor: _headerOpaque
                    ? _kNavy.withValues(alpha: 0.96)
                    : Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: false,
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _headerOpaque ? 1.0 : 0.0,
                  child: Text(
                    workerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _GlassButton(
                    icon: Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  stretchModes: const <StretchMode>[
                    StretchMode.zoomBackground,
                  ],
                  background: _HeroBackground(
                    worker: worker,
                    badgeCtrl: _badgeCtrl,
                    ratingLabel: ratingLabel,
                    locale: locale,
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    // Stats dashboard
                    _FadeSlide(
                      animation: _section0,
                      child: _StatsDashboard(
                        statsCtrl: _statsCtrl,
                        hourlyRate: worker.hourlyRate.toDouble(),
                        rating: worker.rating,
                        reviewCount: worker.reviewCount.toDouble(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // About
                    _FadeSlide(
                      animation: _section1,
                      child: _AccordionSection(
                        icon: Icons.person_search_rounded,
                        title: _copy(locale,
                            en: 'About technician', ar: 'عن الفني'),
                        subtitle: worker.yearsExperience > 0
                            ? _copy(locale,
                                en: '${worker.yearsExperience} yrs experience',
                                ar: '${worker.yearsExperience} سنة خبرة')
                            : null,
                        initiallyExpanded: true,
                        child: Text(
                          worker.bio.trim().isNotEmpty
                              ? worker.bio.trim()
                              : _copy(locale,
                                  en: 'No bio available.',
                                  ar: 'لا توجد نبذة متاحة.'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            height: 1.65,
                            color: Color(0xFF45474B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Services
                    _FadeSlide(
                      animation: _section1,
                      child: _AccordionSection(
                        icon: Icons.home_repair_service_rounded,
                        title: _copy(locale,
                            en: 'Services offered',
                            ar: 'الخدمات المقدمة'),
                        subtitle: serviceLabels.isEmpty
                            ? _copy(locale,
                                en: 'No services listed',
                                ar: 'لا توجد خدمات')
                            : _copy(locale,
                                en: '${serviceLabels.length} service${serviceLabels.length == 1 ? '' : 's'}',
                                ar: '${serviceLabels.length} خدمة'),
                        child: serviceLabels.isEmpty
                            ? Text(
                                _copy(locale,
                                    en: 'No services listed.',
                                    ar: 'لا توجد خدمات مدرجة.'),
                                style: const TextStyle(
                                  color: _kTextMuted,
                                  fontSize: 14,
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: serviceLabels
                                    .map((l) => _SpecChip(label: l))
                                    .toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Availability
                    _FadeSlide(
                      animation: _section2,
                      child: _AccordionSection(
                        icon: Icons.event_available_rounded,
                        title: _copy(locale,
                            en: 'Availability', ar: 'التوفر'),
                        subtitle:
                            _availabilityLabel(worker.availabilityType, locale),
                        child: _AvailabilityContent(
                          availabilityType: worker.availabilityType,
                          availability: worker.availability,
                          locale: locale,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Reviews
                    _FadeSlide(
                      animation: _section2,
                      child: _AccordionSection(
                        icon: Icons.star_rounded,
                        title:
                            _copy(locale, en: 'Reviews', ar: 'التقييمات'),
                        subtitle: worker.reviewCount > 0
                            ? _copy(locale,
                                en: '$ratingLabel from ${worker.reviewCount} reviews',
                                ar: '$ratingLabel من ${worker.reviewCount} تقييم')
                            : _copy(locale,
                                en: 'No reviews yet',
                                ar: 'لا توجد تقييمات'),
                        child: _ReviewsContent(
                          reviews: _reviews,
                          workerRating: worker.rating,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Coverage
                    _FadeSlide(
                      animation: _section3,
                      child: _AccordionSection(
                        icon: Icons.map_rounded,
                        title: _copy(locale,
                            en: 'Service coverage', ar: 'نطاق الخدمة'),
                        subtitle: locationLabel,
                        child: _CoverageContent(
                          area: locationLabel,
                          locale: locale,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),

          // ── Bottom CTA ───────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _kBgLight.withValues(alpha: 0.94),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _kNavy.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BookingStepOneScreen(
                                    data: BookingFlowData(
                                      technicianName: workerName,
                                      technicianId: worker.id,
                                      serviceId: selectedServiceId,
                                      category: selectedServiceCategory,
                                      serviceName: selectedServiceName,
                                      specialty: selectedServiceName,
                                      priceLabel: bookingPriceLabel,
                                      hourlyRate: bookingPriceLabel,
                                      amount: _moneyLabel(bookingBaseAmount),
                                      technicianAvailability:
                                          worker.availability,
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kNavy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _copy(locale,
                                  en: 'Book technician', ar: 'احجز الفني'),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: _copy(locale, en: 'Message', ar: 'مراسلة'),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatScreen(
                                    contactName: workerName,
                                    workerId: worker.id,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              fixedSize: const Size.square(52),
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: _kTaupe.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: _kNavy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error scaffold ────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.error,
    required this.canRetry,
    required this.onRetry,
  });

  final String error;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        title: const Text(
          'Technician Profile',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        backgroundColor: _kBgLight,
        elevation: 0,
        foregroundColor: _kNavy,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _kSurfaceWarm,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_off_outlined,
                    size: 36, color: _kTaupe),
              ),
              const SizedBox(height: 20),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: _kNavy,
                ),
              ),
              if (canRetry) ...<Widget>[
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero background ───────────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({
    required this.worker,
    required this.badgeCtrl,
    required this.ratingLabel,
    required this.locale,
  });

  final BackendWorker worker;
  final AnimationController badgeCtrl;
  final String ratingLabel;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final specialty = worker.categories.isNotEmpty
        ? _readable(worker.categories.first)
        : worker.skills.isNotEmpty
            ? _readable(worker.skills.first)
            : 'Master Artisan';

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_kNavy, _kBrown],
            ),
          ),
        ),
        CustomPaint(painter: _HeroDotsPainter()),
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
                        colors: <Color>[_kTaupe, Color(0xFF5C4A35)],
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
                    clipBehavior: Clip.antiAlias,
                    child: worker.profileImage.isEmpty
                        ? Center(
                            child: Text(
                              worker.initials,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Image.network(
                            worker.profileImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                worker.initials,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (worker.isVerified)
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
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.4 * badgeCtrl.value),
                                blurRadius: 12,
                                spreadRadius: 4 * badgeCtrl.value,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.verified_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  worker.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Specialty badge
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
}

// ── Hero dots texture ─────────────────────────────────────────────────────────

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

// ── Glass back button ─────────────────────────────────────────────────────────

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
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Stats dashboard ───────────────────────────────────────────────────────────

class _StatsDashboard extends StatelessWidget {
  const _StatsDashboard({
    required this.statsCtrl,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
  });

  final AnimationController statsCtrl;
  final double hourlyRate;
  final double rating;
  final double reviewCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              label: 'Rate',
              format: (v) => v > 0 ? '${v.toInt()} EGP' : 'N/A',
            ),
            _VerticalDivider(),
            _StatCell(
              ctrl: statsCtrl,
              value: rating,
              label: 'Rating',
              format: (v) => v > 0 ? v.toStringAsFixed(1) : 'N/A',
              suffix: Icons.star_rounded,
            ),
            _VerticalDivider(),
            _StatCell(
              ctrl: statsCtrl,
              value: reviewCount,
              label: 'Reviews',
              format: (v) => v.toInt().toString(),
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
    this.suffix,
  });

  final AnimationController ctrl;
  final double value;
  final String label;
  final String Function(double) format;
  final IconData? suffix;

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kTextMuted,
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
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                        height: 1,
                      ),
                    ),
                    if (suffix != null) ...<Widget>[
                      const SizedBox(width: 3),
                      Icon(suffix, size: 16, color: Color(0xFFF59E0B)),
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
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        color: _kTaupe.withValues(alpha: 0.1),
      );
}

// ── Section card (always visible) ────────────────────────────────────────────

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  // ignored — all sections always expanded
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.05)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEEEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: _kNavy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _kNavy,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(
                height: 1,
                color: _kTaupe.withValues(alpha: 0.12),
              ),
            ),
            // Content
            child,
          ],
        ),
      ),
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

// ── Spec chip ─────────────────────────────────────────────────────────────────

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kTaupe.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kNavy,
        ),
      ),
    );
  }
}

// ── Availability content ──────────────────────────────────────────────────────

class _AvailabilityContent extends StatelessWidget {
  const _AvailabilityContent({
    required this.availabilityType,
    required this.availability,
    required this.locale,
  });

  final String availabilityType;
  final List<AvailabilitySlot> availability;
  final String locale;

  static const _dayNames = <String>[
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final availableDays = availability
        .where(_availabilityHasWorkingHours)
        .map((s) => _normalizeAvailabilityDay(s.day))
        .where((d) => d.isNotEmpty)
        .toSet();
    final hasWeeklyData = availableDays.isNotEmpty;
    final weekdays =
        availabilityType == 'weekdays' || availabilityType == 'both';
    final weekends =
        availabilityType == 'weekends' || availabilityType == 'both';

    bool isAvailable(String day) {
      if (hasWeeklyData) return availableDays.contains(day);
      return switch (day) {
        'saturday' || 'sunday' => weekends,
        _ => weekdays,
      };
    }

    final label = hasWeeklyData
        ? _copy(locale,
            en: 'Available ${availableDays.length} days a week',
            ar: 'Available ${availableDays.length} days a week')
        : _availabilityLabel(availabilityType, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dayNames.map((day) {
            final short = switch (day) {
              'monday' => _copy(locale, en: 'Mon', ar: 'إث'),
              'tuesday' => _copy(locale, en: 'Tue', ar: 'ثل'),
              'wednesday' => _copy(locale, en: 'Wed', ar: 'أر'),
              'thursday' => _copy(locale, en: 'Thu', ar: 'خم'),
              'friday' => _copy(locale, en: 'Fri', ar: 'جم'),
              'saturday' => _copy(locale, en: 'Sat', ar: 'سب'),
              _ => _copy(locale, en: 'Sun', ar: 'أح'),
            };
            final active = isAvailable(day);
            return Container(
              constraints: const BoxConstraints(minWidth: 46),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: active ? _kNavy : _kSurfaceWarm,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: active
                      ? _kNavy
                      : _kTaupe.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                short,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : _kTextMuted,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Reviews content ───────────────────────────────────────────────────────────

class _ReviewsContent extends StatelessWidget {
  const _ReviewsContent({
    required this.reviews,
    required this.workerRating,
  });

  final List<ReviewResult> reviews;
  final double workerRating;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Text(
        'No reviews yet.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: _kTextMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Rating summary
        Row(
          children: <Widget>[
            Text(
              avg.toStringAsFixed(1),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: _kNavy,
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
                  '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.take(5).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReviewCard(review: r),
            )),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewResult review;

  @override
  Widget build(BuildContext context) {
    final initials = review.reviewerName.isNotEmpty
        ? review.reviewerName[0].toUpperCase()
        : 'A';
    final date =
        '${review.createdAt.day.toString().padLeft(2, '0')}/'
        '${review.createdAt.month.toString().padLeft(2, '0')}/'
        '${review.createdAt.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurfaceWarm,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
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
                  color: _kTaupe.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kNavy,
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
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kNavy,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: _kTaupe,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List<Widget>.generate(5, (i) {
                  final filled = i < review.rating.round();
                  return Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.55,
                fontStyle: FontStyle.italic,
                color: Color(0xFF45474B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Coverage content ──────────────────────────────────────────────────────────

class _CoverageContent extends StatelessWidget {
  const _CoverageContent({required this.area, required this.locale});

  final String area;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final areas = area
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.share_location_rounded,
                color: _kTaupe, size: 18),
            const SizedBox(width: 8),
            Text(
              _copy(locale, en: 'Operating Areas', ar: 'مناطق العمل'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kTaupe,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: areas
              .map(
                (a) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kTaupe.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _kTaupe.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.location_city_rounded,
                          size: 13, color: _kNavy),
                      const SizedBox(width: 5),
                      Text(
                        a,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BackendWorkerService? _selectedWorkerService(
  BackendWorker worker, {
  String? serviceId,
  String? serviceName,
  String? category,
}) {
  final selectedId = serviceId?.trim() ?? '';
  if (selectedId.isNotEmpty) {
    for (final service in worker.services) {
      if (service.id == selectedId) return service;
    }
  }

  final selectedCategory = normalizeServiceCategory(category);
  if (selectedCategory.isNotEmpty) {
    for (final service in worker.services) {
      if (normalizeServiceCategory(service.category) == selectedCategory) {
        return service;
      }
    }
  }

  final selectedName = serviceName?.trim().toLowerCase() ?? '';
  if (selectedName.isNotEmpty) {
    for (final service in worker.services) {
      if (service.displayName.toLowerCase() == selectedName) return service;
    }
  }

  return null;
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

double _bookingBaseAmount(BackendWorkerService? service, int hourlyRate) {
  final servicePrice = service?.basePrice ?? 0;
  if (servicePrice > 0) return servicePrice;
  if (hourlyRate > 0) return hourlyRate.toDouble();
  return 0;
}

String _moneyLabel(double amount) => '${amount.round()} EGP';

String _bookingPriceLabel(
  BackendWorkerService? service,
  int hourlyRate,
  String locale,
) {
  final servicePrice = service?.basePrice ?? 0;
  if (servicePrice > 0) {
    final rounded = servicePrice.round();
    return switch (service?.priceUnit) {
      'per_hour' => _copy(locale, en: '$rounded EGP/hr', ar: '$rounded EGP/hr'),
      'per_sqm' => _copy(locale, en: '$rounded EGP/m2', ar: '$rounded EGP/m2'),
      _ => _copy(locale, en: '$rounded EGP', ar: '$rounded EGP'),
    };
  }
  if (hourlyRate > 0) {
    return _copy(locale, en: '$hourlyRate EGP/hr', ar: '$hourlyRate EGP/hr');
  }
  return _copy(locale, en: 'Rate on request', ar: 'Rate on request');
}

String _normalizeAvailabilityDay(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

bool _availabilityHasWorkingHours(AvailabilitySlot slot) {
  final from = _availabilityHourValue(slot.from);
  final to = _availabilityHourValue(slot.to);
  return from != null && to != null && from < to;
}

int? _availabilityHourValue(String value) {
  final match = RegExp(r'^\s*(\d{1,2})').firstMatch(value);
  final hour = int.tryParse(match?.group(1) ?? '');
  if (hour == null || hour < 0 || hour > 24) return null;
  return hour;
}

String _availabilityLabel(String availabilityType, String locale) {
  return switch (availabilityType) {
    'weekdays' =>
      _copy(locale, en: 'Available weekdays', ar: 'متاح أيام الأسبوع'),
    'weekends' => _copy(locale,
        en: 'Available weekends', ar: 'متاح في عطلات نهاية الأسبوع'),
    'both' => _copy(locale, en: 'Available all week', ar: 'متاح طوال الأسبوع'),
    _ => _copy(locale, en: 'Flexible schedule', ar: 'جدول مرن'),
  };
}

String _copy(String locale, {required String en, required String ar}) =>
    locale == 'ar' ? ar : en;

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
