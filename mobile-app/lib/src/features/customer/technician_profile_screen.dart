import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/reviews_api.dart';
import '../../core/api/users_api.dart';
import '../../core/models/backend_worker_model.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../booking/booking_flow_data.dart';
import '../booking/booking_step_one_screen.dart';
import '../messages/chat_screen.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({this.technicianId, super.key});

  final String? technicianId;

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  final Set<int> _expandedSections = <int>{0, 1, 2, 3, 4};

  BackendWorker? _worker;
  List<ReviewResult> _reviews = <ReviewResult>[];
  bool _loading = true;
  String? _error;

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        _expandedSections.remove(index);
      } else {
        _expandedSections.add(index);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
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
    try {
      final cached = workersProvider.findById(technicianId);
      if (cached != null) {
        setState(() => _worker = cached);
      } else {
        final worker = await UsersApi(client).getWorkerById(technicianId);
        if (mounted) setState(() => _worker = worker);
      }
      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = 'Unable to load technician profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted || _worker == null) return;
    try {
      final reviews = await ReviewsApi(client).getWorkerReviews(technicianId);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {
      // Reviews are secondary; the profile should remain usable if they fail.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().languageCode;

    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_error != null || _worker == null) {
      final canRetry = widget.technicianId?.trim().isNotEmpty == true;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Technician Profile'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.person_off_outlined,
                    size: 44,
                    color: servio.textSecondary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _error ?? 'Technician profile not found.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canRetry
                        ? 'Unable to load technician profile. Please try again.'
                        : 'Open a technician from the listing to view their profile.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: servio.textSecondary,
                    ),
                  ),
                  if (canRetry) ...<Widget>[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final worker = _worker!;
    final workerName = worker.displayName;
    final serviceLabels = worker.serviceLabels;
    final primaryBackendService =
        worker.services.isNotEmpty ? worker.services.first : null;
    final primaryService = serviceLabels.isNotEmpty ? serviceLabels.first : '';
    final availabilityLabel =
        _availabilityLabel(worker.availabilityType, locale);
    final locationLabel = worker.locationLabel.isNotEmpty
        ? worker.locationLabel
        : _copy(locale, en: 'Cairo', ar: 'القاهرة');
    final ratingLabel =
        worker.rating > 0 ? worker.rating.toStringAsFixed(1) : 'N/A';
    final serviceCount = serviceLabels.length;
    final servicesCountLabel = serviceCount == 0
        ? _copy(locale, en: 'No services listed', ar: 'لا توجد خدمات')
        : serviceCount == 1
            ? _copy(locale, en: '1 service', ar: 'خدمة واحدة')
            : _copy(locale,
                en: '$serviceCount services', ar: '$serviceCount خدمة');
    final aboutText = worker.bio.trim().isNotEmpty
        ? worker.bio.trim()
        : _copy(locale, en: 'No bio available.', ar: 'لا توجد نبذة متاحة.');
    final rateLabel = worker.hourlyRate > 0
        ? _copy(
            locale,
            en: '${worker.hourlyRate} EGP/hr',
            ar: '${worker.hourlyRate} جنيه/ساعة',
          )
        : _copy(locale, en: 'Rate on request', ar: 'السعر عند الطلب');

    return Scaffold(
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 290,
                pinned: true,
                stretch: true,
                elevation: 0,
                backgroundColor: ServioColors.navyDark,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.white,
                title: Text(
                  workerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                leadingWidth: 56,
                leading: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _RoundIconButton(
                    icon: Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _ProfileHero(
                    name: workerName,
                    initials: worker.initials,
                    profileImage: worker.profileImage,
                    isVerified: worker.isVerified,
                    ratingLabel: ratingLabel,
                    reviewCount: worker.reviewCount,
                    serviceLabels: serviceLabels,
                    availabilityLabel: availabilityLabel,
                    locationLabel: locationLabel,
                    locale: locale,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 176),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      _ProfileSnapshotCard(
                        hourlyRate: worker.hourlyRate,
                        yearsExperience: worker.yearsExperience,
                        isVerified: worker.isVerified,
                        locale: locale,
                      ),
                      const SizedBox(height: 24),
                      _AccordionSection(
                        icon: Icons.person_search_rounded,
                        title: _copy(locale,
                            en: 'About technician', ar: 'عن الفني'),
                        subtitle: worker.yearsExperience > 0
                            ? _copy(
                                locale,
                                en: '${worker.yearsExperience} years experience',
                                ar: '${worker.yearsExperience} سنة خبرة',
                              )
                            : null,
                        expanded: _expandedSections.contains(0),
                        onTap: () => _toggleSection(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              aboutText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: servio.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.home_repair_service_rounded,
                        title: _copy(locale,
                            en: 'Services offered', ar: 'الخدمات المقدمة'),
                        subtitle: servicesCountLabel,
                        expanded: _expandedSections.contains(1),
                        onTap: () => _toggleSection(1),
                        child: serviceLabels.isEmpty
                            ? Text(
                                _copy(
                                  locale,
                                  en: 'No services listed.',
                                  ar: 'لا توجد خدمات مدرجة.',
                                ),
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: servio.textSecondary),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: serviceLabels
                                    .map((String label) =>
                                        _MiniChip(label: label))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.event_available_rounded,
                        title: _copy(locale, en: 'Availability', ar: 'التوفر'),
                        subtitle: availabilityLabel,
                        expanded: _expandedSections.contains(2),
                        onTap: () => _toggleSection(2),
                        child: _AvailabilityPanel(
                          availabilityType: worker.availabilityType,
                          availability: worker.availability,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.insights_rounded,
                        title: _copy(locale, en: 'Reviews', ar: 'التقييمات'),
                        subtitle: worker.reviewCount > 0
                            ? _copy(
                                locale,
                                en: '$ratingLabel from ${worker.reviewCount} reviews',
                                ar: '$ratingLabel من ${worker.reviewCount} تقييم',
                              )
                            : _copy(
                                locale,
                                en: 'Rating not available',
                                ar: 'التقييم غير متاح',
                              ),
                        expanded: _expandedSections.contains(3),
                        onTap: () => _toggleSection(3),
                        child: _reviews.isEmpty
                            ? Text(
                                _copy(locale,
                                    en: 'No reviews yet.',
                                    ar: 'لا توجد تقييمات بعد.'),
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: servio.textSecondary),
                              )
                            : Column(
                                children: _reviews
                                    .take(3)
                                    .map(
                                      (ReviewResult r) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _MiniReviewCard(
                                          name: r.reviewerName,
                                          body: r.comment,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.map_rounded,
                        title: _copy(locale,
                            en: 'Service coverage', ar: 'نطاق الخدمة'),
                        subtitle: _copy(locale,
                            en: 'View areas on map',
                            ar: 'عرض المناطق على الخريطة'),
                        expanded: _expandedSections.contains(4),
                        onTap: () => _toggleSection(4),
                        child: _CoverageCard(
                          area: locationLabel,
                          locale: locale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: servio.border.withValues(alpha: 0.7),
                    ),
                  ),
                  boxShadow: theme.brightness == Brightness.dark
                      ? ServioShadows.elevatedDark
                      : ServioShadows.elevated,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          rateLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: servio.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: ServioPrimaryButton(
                            label: _copy(locale,
                                en: 'Book technician', ar: 'احجز الفني'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BookingStepOneScreen(
                                    data: BookingFlowData(
                                      technicianName: workerName,
                                      technicianId: worker.id,
                                      serviceId:
                                          primaryBackendService?.id ?? '',
                                      category:
                                          (primaryBackendService?.category ??
                                                      '')
                                                  .isNotEmpty
                                              ? primaryBackendService!.category
                                              : (worker.categories.isNotEmpty
                                                  ? worker.categories.first
                                                  : (worker.skills.isNotEmpty
                                                      ? worker.skills.first
                                                      : '')),
                                      serviceName: primaryService.isNotEmpty
                                          ? primaryService
                                          : _copy(locale,
                                              en: 'Service visit',
                                              ar: 'زيارة خدمة'),
                                      specialty: primaryService,
                                      hourlyRate: rateLabel,
                                      technicianAvailability:
                                          worker.availability,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
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
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(ServioRadius.full),
                              ),
                            ),
                            label: Text(
                              _copy(locale, en: 'Message', ar: 'مراسلة'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}

// ── Profile Hero (SliverAppBar background) ────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.initials,
    required this.profileImage,
    required this.isVerified,
    required this.ratingLabel,
    required this.reviewCount,
    required this.serviceLabels,
    required this.availabilityLabel,
    required this.locationLabel,
    required this.locale,
  });

  final String name;
  final String initials;
  final String profileImage;
  final bool isVerified;
  final String ratingLabel;
  final int reviewCount;
  final List<String> serviceLabels;
  final String availabilityLabel;
  final String locationLabel;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ServioGradients.brand),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PositionedDirectional(
            end: -18,
            top: 88,
            child: Icon(
              _specialtyIcon(
                  serviceLabels.isNotEmpty ? serviceLabels.first : ''),
              size: 156,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          PositionedDirectional(
            start: -44,
            bottom: 24,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 28,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _ProfileAvatar(
                        initials: initials,
                        verified: isVerified,
                        profileImage: profileImage,
                        name: name,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (serviceLabels.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                serviceLabels.take(3).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                            if (locationLabel.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Icon(Icons.place_rounded,
                                      size: 14,
                                      color:
                                          Colors.white.withValues(alpha: 0.78)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      locationLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 86,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _HeroMetric(
                          icon: Icons.star_rounded,
                          value: ratingLabel,
                          label: _copy(locale, en: 'Rating', ar: 'التقييم'),
                        ),
                        const SizedBox(width: 8),
                        _HeroMetric(
                          icon: Icons.reviews_rounded,
                          value: '$reviewCount',
                          label: _copy(locale, en: 'Reviews', ar: 'تقييم'),
                        ),
                        const SizedBox(width: 8),
                        _HeroMetric(
                          icon: Icons.build_rounded,
                          value: '${serviceLabels.length}',
                          label: _copy(locale, en: 'Services', ar: 'خدمات'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Snapshot Card ─────────────────────────────────────────────────────

class _ProfileSnapshotCard extends StatelessWidget {
  const _ProfileSnapshotCard({
    required this.hourlyRate,
    required this.yearsExperience,
    required this.isVerified,
    required this.locale,
  });

  final int hourlyRate;
  final int yearsExperience;
  final bool isVerified;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      elevated: true,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SnapshotItem(
                  icon: Icons.payments_outlined,
                  label: _copy(locale, en: 'Rate', ar: 'السعر'),
                  value: hourlyRate > 0
                      ? _copy(locale,
                          en: '$hourlyRate EGP', ar: '$hourlyRate جنيه')
                      : _copy(locale, en: 'On request', ar: 'عند الطلب'),
                ),
              ),
              _VerticalDivider(color: servio.border),
              Expanded(
                child: _SnapshotItem(
                  icon: Icons.work_history_outlined,
                  label: _copy(locale, en: 'Experience', ar: 'الخبرة'),
                  value: yearsExperience > 0
                      ? _copy(locale,
                          en: '$yearsExperience yrs',
                          ar: '$yearsExperience سنوات')
                      : _copy(locale, en: 'New', ar: 'جديد'),
                ),
              ),
              _VerticalDivider(color: servio.border),
              Expanded(
                child: _SnapshotItem(
                  icon: isVerified
                      ? Icons.verified_user_rounded
                      : Icons.pending_actions_rounded,
                  label: _copy(locale, en: 'Status', ar: 'الحالة'),
                  value: isVerified
                      ? _copy(locale, en: 'Verified', ar: 'موثّق')
                      : _copy(locale, en: 'Pending', ar: 'قيد المراجعة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: servio.backgroundSoft,
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isVerified
                      ? Icons.verified_user_rounded
                      : Icons.pending_actions_rounded,
                  color: isVerified ? servio.success : servio.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isVerified
                        ? _copy(
                            locale,
                            en: 'Identity and core credentials are checked by SERVIO.',
                            ar: 'تم التحقق من الهوية والاعتمادات الأساسية بواسطة SERVIO.',
                          )
                        : _copy(
                            locale,
                            en: 'Credential review is currently in progress.',
                            ar: 'مراجعة الاعتمادات قيد التنفيذ حالياً.',
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: servio.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Tile (4-column row under snapshot card) ──────────────────────────────

// ── Snapshot sub-widgets ──────────────────────────────────────────────────────

class _SnapshotItem extends StatelessWidget {
  const _SnapshotItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      children: <Widget>[
        Icon(icon, color: servio.accent, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.labelSmall?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: color.withValues(alpha: 0.72),
    );
  }
}

// ── Accordion Section ─────────────────────────────────────────────────────────

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ServioColors.tint(servio.accent),
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                    ),
                    child: Icon(icon, color: servio.accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.titleMedium),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: ServioMotion.fast,
                    curve: ServioMotion.spring,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: servio.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: ServioMotion.micro,
            firstCurve: ServioMotion.standard,
            secondCurve: ServioMotion.spring,
            sizeCurve: ServioMotion.spring,
          ),
        ],
      ),
    );
  }
}

// ── Mini Chip ─────────────────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final color = servio.accent;
    final availableWidth = MediaQuery.sizeOf(context).width - 88;
    final maxLabelWidth = availableWidth < 120
        ? 120.0
        : availableWidth > 220
            ? 220.0
            : availableWidth;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 12, 7),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Availability Panel ────────────────────────────────────────────────────────

class _AvailabilityPanel extends StatelessWidget {
  const _AvailabilityPanel({
    required this.availabilityType,
    required this.availability,
    required this.locale,
  });

  final String availabilityType;
  final List<AvailabilitySlot> availability;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final availableDays = availability
        .where(_availabilityHasWorkingHours)
        .map((slot) => _normalizeAvailabilityDay(slot.day))
        .where((day) => day.isNotEmpty)
        .toSet();
    final hasWeeklyAvailability = availableDays.isNotEmpty;

    final label = hasWeeklyAvailability
        ? _copy(
            locale,
            en: 'Available ${availableDays.length} days a week',
            ar: 'Available ${availableDays.length} days a week',
          )
        : switch (availabilityType) {
            'weekdays' =>
              _copy(locale, en: 'Available weekdays', ar: 'متاح أيام الأسبوع'),
            'weekends' => _copy(locale,
                en: 'Available weekends', ar: 'متاح في عطلات نهاية الأسبوع'),
            'both' =>
              _copy(locale, en: 'Available all week', ar: 'متاح طوال الأسبوع'),
            _ => _copy(locale, en: 'Flexible schedule', ar: 'جدول مرن'),
          };

    final weekdays =
        availabilityType == 'weekdays' || availabilityType == 'both';
    final weekends =
        availabilityType == 'weekends' || availabilityType == 'both';

    bool isAvailable(String day) {
      if (hasWeeklyAvailability) return availableDays.contains(day);
      return switch (day) {
        'saturday' || 'sunday' => weekends,
        _ => weekdays,
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ServioColors.tint(servio.success),
            borderRadius: BorderRadius.circular(ServioRadius.md),
            border: Border.all(color: servio.success.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: servio.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: servio.success,
                    fontWeight: FontWeight.w800,
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
          children: <Widget>[
            _AvailabilityPill(
              day: _copy(locale, en: 'Mon', ar: 'إث'),
              available: isAvailable('monday'),
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Tue', ar: 'ثل'),
              available: isAvailable('tuesday'),
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Wed', ar: 'أر'),
              available: isAvailable('wednesday'),
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Thu', ar: 'خم'),
              available: isAvailable('thursday'),
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Fri', ar: 'جم'),
              available: isAvailable('friday'),
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Sat', ar: 'سب'),
              available: isAvailable('saturday'),
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Sun', ar: 'أح'),
              available: isAvailable('sunday'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Mini Review Card ──────────────────────────────────────────────────────────

class _MiniReviewCard extends StatelessWidget {
  const _MiniReviewCard({required this.name, required this.body});

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: ServioGradients.warm,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ServioColors.deepBrown,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coverage Card ─────────────────────────────────────────────────────────────

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.area, required this.locale});

  final String area;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final areas = area
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            end: -20,
            bottom: -20,
            child: Icon(
              Icons.map_outlined,
              size: 120,
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.share_location_rounded,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _copy(locale, en: 'Operating Areas', ar: 'مناطق العمل'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: areas
                    .map((String a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(ServioRadius.md),
                            border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.location_city_rounded,
                                  size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                a,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Availability Pill ─────────────────────────────────────────────────────────

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.day, required this.available});

  final String day;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: available ? servio.success : servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(
          color: available
              ? servio.success.withValues(alpha: 0.42)
              : servio.border.withValues(alpha: 0.62),
        ),
      ),
      child: Text(
        day,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: available ? Colors.white : servio.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Profile Avatar ────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.verified,
    required this.profileImage,
    required this.name,
  });

  final String initials;
  final bool verified;
  final String profileImage;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: ServioGradients.warm,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 3,
            ),
            boxShadow: ServioShadows.elevated,
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            image: true,
            label: '$name profile image',
            child: profileImage.isEmpty
                ? _AvatarInitials(initials: initials)
                : Image.network(
                    profileImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _AvatarInitials(initials: initials),
                  ),
          ),
        ),
        if (verified)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ServioColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 17, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ── Hero sub-widgets ──────────────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: ServioColors.deepBrown,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 16, color: ServioColors.neutralWarm),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Round Icon Button ─────────────────────────────────────────────────────────

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.92),
        foregroundColor: theme.colorScheme.onSurface,
        minimumSize: const Size.square(42),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _specialtyIcon(String specialty) {
  return switch (specialty.toLowerCase()) {
    'plumbing' => Icons.plumbing_rounded,
    'electrical' => Icons.electrical_services_rounded,
    'hvac' || 'ac-maintenance' => Icons.ac_unit_rounded,
    'painting' => Icons.format_paint_rounded,
    'carpentry' => Icons.carpenter_rounded,
    'cleaning' => Icons.cleaning_services_rounded,
    'flooring' => Icons.grid_on_rounded,
    _ => Icons.handyman_rounded,
  };
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

String _copy(String locale, {required String en, required String ar}) {
  return locale == 'ar' ? ar : en;
}
