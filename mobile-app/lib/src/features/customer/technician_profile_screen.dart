import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/demo_technicians.dart';
import '../../core/models/technician_model.dart';
import '../../core/state/app_state.dart';
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
  final Set<int> _expandedSections = <int>{0, 1, 2, 3, 4, 6};

  TechnicianModel get _technician {
    if (widget.technicianId == null) return kDemoTechnicians.first;
    return kDemoTechnicians.firstWhere(
      (TechnicianModel t) => t.id == widget.technicianId,
      orElse: () => kDemoTechnicians.first,
    );
  }

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().languageCode;
    final tech = _technician;
    final techName = tech.name.of(locale);
    final techTitle = tech.title.of(locale);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                stretch: true,
                elevation: 0,
                backgroundColor: ServioColors.navyDark,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.white,
                title: const SizedBox.shrink(),
                leadingWidth: 72,
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
                    technician: tech,
                    locale: locale,
                    name: techName,
                    title: techTitle,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 148),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      _ProfileSnapshotCard(
                        technician: tech,
                        locale: locale,
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.person_search_rounded,
                        title: _copy(
                          locale,
                          en: 'About technician',
                          ar: 'عن الفني',
                        ),
                        subtitle: techTitle,
                        expanded: _expandedSections.contains(0),
                        onTap: () => _toggleSection(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              tech.bio.of(locale),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: servio.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _MiniChip(
                                  label: _copy(
                                    locale,
                                    en: 'Arabic',
                                    ar: 'عربي',
                                  ),
                                  icon: Icons.translate_rounded,
                                ),
                                _MiniChip(
                                  label: _copy(
                                    locale,
                                    en: 'English',
                                    ar: 'إنجليزي',
                                  ),
                                  icon: Icons.language_rounded,
                                ),
                                if (tech.verified)
                                  _MiniChip(
                                    label: _copy(
                                      locale,
                                      en: 'Verified',
                                      ar: 'موثّق',
                                    ),
                                    icon: Icons.verified_user_rounded,
                                    tone: _ChipTone.success,
                                  ),
                                _MiniChip(
                                  label: _copy(
                                    locale,
                                    en: '${tech.yearsExp} yrs experience',
                                    ar: '${tech.yearsExp} سنة خبرة',
                                  ),
                                  icon: Icons.workspace_premium_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.home_repair_service_rounded,
                        title: _copy(
                          locale,
                          en: 'Services offered',
                          ar: 'الخدمات المقدمة',
                        ),
                        subtitle: _copy(
                          locale,
                          en: '${tech.services.length} selectable services',
                          ar: '${tech.services.length} خدمات متاحة',
                        ),
                        expanded: _expandedSections.contains(1),
                        onTap: () => _toggleSection(1),
                        child: Column(
                          children: <Widget>[
                            for (var index = 0;
                                index < tech.services.length;
                                index++) ...<Widget>[
                              _ServiceOfferCard(
                                service: tech.services[index],
                                locale: locale,
                              ),
                              if (index != tech.services.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.event_available_rounded,
                        title: _copy(locale, en: 'Availability', ar: 'التوفر'),
                        subtitle: tech.availability.of(locale),
                        expanded: _expandedSections.contains(2),
                        onTap: () => _toggleSection(2),
                        child: _AvailabilityPanel(
                          technician: tech,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.insights_rounded,
                        title: _copy(
                          locale,
                          en: 'Experience',
                          ar: 'الخبرة والإنجازات',
                        ),
                        subtitle: _copy(
                          locale,
                          en: '${tech.jobSuccess}% job success',
                          ar: '${tech.jobSuccess}% نجاح الأعمال',
                        ),
                        expanded: _expandedSections.contains(3),
                        onTap: () => _toggleSection(3),
                        child: _ExperienceGrid(
                          technician: tech,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.rate_review_rounded,
                        title: _copy(
                          locale,
                          en: 'Reviews preview',
                          ar: 'لمحة عن التقييمات',
                        ),
                        subtitle: _copy(
                          locale,
                          en: '${tech.rating.toStringAsFixed(1)} from ${tech.reviewCount} reviews',
                          ar: '${tech.rating.toStringAsFixed(1)} من ${tech.reviewCount} تقييم',
                        ),
                        expanded: _expandedSections.contains(4),
                        onTap: () => _toggleSection(4),
                        child: _ReviewsPreview(
                          technician: tech,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.photo_library_rounded,
                        title: _copy(
                          locale,
                          en: 'Portfolio',
                          ar: 'معرض الأعمال',
                        ),
                        subtitle: _copy(
                          locale,
                          en: 'Recent service snapshots',
                          ar: 'نماذج من الخدمات',
                        ),
                        expanded: _expandedSections.contains(5),
                        onTap: () => _toggleSection(5),
                        child: _PortfolioStrip(
                          technician: tech,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.map_rounded,
                        title: _copy(
                          locale,
                          en: 'Service coverage',
                          ar: 'نطاق الخدمة',
                        ),
                        subtitle: tech.area.of(locale),
                        expanded: _expandedSections.contains(6),
                        onTap: () => _toggleSection(6),
                        child: _CoverageCard(
                          area: tech.area.of(locale),
                          distance: tech.distance,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccordionSection(
                        icon: Icons.fact_check_rounded,
                        title: _copy(
                          locale,
                          en: 'Verified credentials',
                          ar: 'الاعتمادات',
                        ),
                        subtitle: _copy(
                          locale,
                          en: tech.verified ? 'Profile checked' : 'In review',
                          ar: tech.verified
                              ? 'تم التحقق من الملف'
                              : 'قيد المراجعة',
                        ),
                        expanded: _expandedSections.contains(7),
                        onTap: () => _toggleSection(7),
                        child: Column(
                          children: <Widget>[
                            _CredentialRow(
                              label: _copy(
                                locale,
                                en: 'Professional license',
                                ar: 'الرخصة المهنية',
                              ),
                              status: _copy(
                                locale,
                                en: 'Verified',
                                ar: 'موثّق',
                              ),
                              pending: false,
                            ),
                            const SizedBox(height: 10),
                            _CredentialRow(
                              label: _copy(
                                locale,
                                en: 'Insurance',
                                ar: 'التأمين',
                              ),
                              status: _copy(
                                locale,
                                en: 'Verified',
                                ar: 'موثّق',
                              ),
                              pending: false,
                            ),
                            const SizedBox(height: 10),
                            _CredentialRow(
                              label: _copy(
                                locale,
                                en: 'Background check',
                                ar: 'فحص الخلفية',
                              ),
                              status: _copy(
                                locale,
                                en: 'Pending',
                                ar: 'قيد المراجعة',
                              ),
                              pending: true,
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
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: servio.success,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: servio.success.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tech.availability.of(locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: servio.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _copy(
                            locale,
                            en: '${tech.pricePerHour} EGP/hr',
                            ar: '${tech.pricePerHour} جنيه/ساعة',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: servio.accent,
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
                            label: _copy(
                              locale,
                              en: 'Book technician',
                              ar: 'احجز الفني',
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BookingStepOneScreen(
                                    data: BookingFlowData(
                                      technicianName: techName,
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
                                  builder: (_) =>
                                      ChatScreen(contactName: techName),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.technician,
    required this.locale,
    required this.name,
    required this.title,
  });

  final TechnicianModel technician;
  final String locale;
  final String name;
  final String title;

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
              _specialtyIcon(technician.specialty),
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
              padding: const EdgeInsets.fromLTRB(20, 76, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _ProfileAvatar(
                        initials: technician.avatarInitials,
                        verified: technician.verified,
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
                            const SizedBox(height: 8),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        _HeroPill(
                          icon: Icons.event_available_rounded,
                          label: technician.availability.of(locale),
                        ),
                        const SizedBox(width: 8),
                        _HeroPill(
                          icon: Icons.place_rounded,
                          label: technician.area.of(locale),
                        ),
                        if (technician.verified) const SizedBox(width: 8),
                        if (technician.verified)
                          _HeroPill(
                            icon: Icons.verified_user_rounded,
                            label: _copy(locale, en: 'Verified', ar: 'موثّق'),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 74,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _HeroMetric(
                          icon: Icons.star_rounded,
                          value: technician.rating.toStringAsFixed(1),
                          label: _copy(locale, en: 'Rating', ar: 'التقييم'),
                        ),
                        const SizedBox(width: 8),
                        _HeroMetric(
                          icon: Icons.reviews_rounded,
                          value: '${technician.reviewCount}',
                          label: _copy(locale, en: 'Reviews', ar: 'تقييم'),
                        ),
                        const SizedBox(width: 8),
                        _HeroMetric(
                          icon: Icons.verified_rounded,
                          value: '${technician.jobSuccess}%',
                          label: _copy(locale, en: 'Success', ar: 'نجاح'),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials, required this.verified});

  final String initials;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          child: Center(
            child: Text(
              initials,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: ServioColors.deepBrown,
                fontWeight: FontWeight.w700,
              ),
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
              child: const Icon(
                Icons.check_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSnapshotCard extends StatelessWidget {
  const _ProfileSnapshotCard({
    required this.technician,
    required this.locale,
  });

  final TechnicianModel technician;
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
                  icon: Icons.schedule_rounded,
                  label: _copy(locale, en: 'Response', ar: 'الاستجابة'),
                  value: technician.responseTime,
                ),
              ),
              _VerticalDivider(color: servio.border),
              Expanded(
                child: _SnapshotItem(
                  icon: Icons.place_outlined,
                  label: _copy(locale, en: 'Distance', ar: 'المسافة'),
                  value: technician.distance,
                ),
              ),
              _VerticalDivider(color: servio.border),
              Expanded(
                child: _SnapshotItem(
                  icon: Icons.payments_outlined,
                  label: _copy(locale, en: 'Rate', ar: 'السعر'),
                  value: _copy(
                    locale,
                    en: '${technician.pricePerHour} EGP',
                    ar: '${technician.pricePerHour} جنيه',
                  ),
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
                  technician.verified
                      ? Icons.verified_user_rounded
                      : Icons.pending_actions_rounded,
                  color: technician.verified ? servio.success : servio.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    technician.verified
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
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: servio.textSecondary,
          ),
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: servio.textSecondary,
                            ),
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

enum _ChipTone { neutral, success, warning }

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    this.icon,
    this.tone = _ChipTone.neutral,
  });

  final String label;
  final IconData? icon;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final color = switch (tone) {
      _ChipTone.success => servio.success,
      _ChipTone.warning => servio.warning,
      _ChipTone.neutral => servio.accent,
    };

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(icon == null ? 12 : 10, 7, 12, 7),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
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

class _ServiceOfferCard extends StatelessWidget {
  const _ServiceOfferCard({
    required this.service,
    required this.locale,
  });

  final TechnicianService service;
  final String locale;

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
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Icon(
              Icons.build_circle_outlined,
              color: servio.accent,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  service.name.of(locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${service.price.of(locale)} · ${service.duration.of(locale)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
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

class _AvailabilityPanel extends StatelessWidget {
  const _AvailabilityPanel({
    required this.technician,
    required this.locale,
  });

  final TechnicianModel technician;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ServioColors.tint(servio.success),
            borderRadius: BorderRadius.circular(ServioRadius.md),
            border: Border.all(
              color: servio.success.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: servio.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      technician.availability.of(locale),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: servio.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _copy(
                        locale,
                        en: 'Usually responds in ${technician.responseTime}.',
                        ar: 'عادةً يرد خلال ${technician.responseTime}.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                  ],
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
              available: true,
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Tue', ar: 'ثل'),
              available: true,
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Wed', ar: 'أر'),
              available: true,
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Thu', ar: 'خم'),
              available: false,
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Fri', ar: 'جم'),
              available: true,
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Sat', ar: 'سب'),
              available: false,
            ),
            _AvailabilityPill(
              day: _copy(locale, en: 'Sun', ar: 'أح'),
              available: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _ExperienceGrid extends StatelessWidget {
  const _ExperienceGrid({
    required this.technician,
    required this.locale,
  });

  final TechnicianModel technician;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final isCompact = constraints.maxWidth < 320;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isCompact ? 1 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isCompact ? 3.6 : 2.15,
          children: <Widget>[
            _ExperienceTile(
              icon: Icons.workspace_premium_rounded,
              value: '${technician.yearsExp}+',
              label: _copy(locale, en: 'Years experience', ar: 'سنوات خبرة'),
            ),
            _ExperienceTile(
              icon: Icons.task_alt_rounded,
              value: '${technician.jobSuccess}%',
              label: _copy(locale, en: 'Job success', ar: 'نجاح الأعمال'),
            ),
            _ExperienceTile(
              icon: Icons.reviews_rounded,
              value: '${technician.reviewCount}',
              label:
                  _copy(locale, en: 'Customer reviews', ar: 'تقييمات العملاء'),
            ),
            _ExperienceTile(
              icon: Icons.home_repair_service_rounded,
              value: '${technician.services.length}',
              label: _copy(locale, en: 'Service types', ar: 'أنواع خدمات'),
            ),
          ],
        );
      },
    );
  }
}

class _ExperienceTile extends StatelessWidget {
  const _ExperienceTile({
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
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: servio.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: servio.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: servio.textSecondary,
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

class _ReviewsPreview extends StatelessWidget {
  const _ReviewsPreview({
    required this.technician,
    required this.locale,
  });

  final TechnicianModel technician;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 12, 7),
              decoration: BoxDecoration(
                color: ServioColors.tint(servio.warning),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.star_rounded, color: servio.warning, size: 17),
                  const SizedBox(width: 5),
                  Text(
                    technician.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: servio.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _copy(
                  locale,
                  en: 'Based on ${technician.reviewCount} customer reviews',
                  ar: 'بناءً على ${technician.reviewCount} تقييم من العملاء',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: servio.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MiniReviewCard(
          name: _copy(locale, en: 'Nour Hany', ar: 'نور هاني'),
          body: _copy(
            locale,
            en: 'Professional and very clear on pricing.',
            ar: 'محترف وواضح جداً في التسعير.',
          ),
        ),
        const SizedBox(height: 10),
        _MiniReviewCard(
          name: _copy(locale, en: 'Karim Adel', ar: 'كريم عادل'),
          body: _copy(
            locale,
            en: 'Fast response and neat work.',
            ar: 'استجابة سريعة وعمل أنيق.',
          ),
        ),
      ],
    );
  }
}

class _MiniReviewCard extends StatelessWidget {
  const _MiniReviewCard({required this.name, required this.body});

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.format_quote_rounded,
              color: servio.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: theme.textTheme.labelLarge),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                    height: 1.35,
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

class _PortfolioStrip extends StatelessWidget {
  const _PortfolioStrip({
    required this.technician,
    required this.locale,
  });

  final TechnicianModel technician;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: technician.services.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final service = technician.services[index];
          return _PortfolioCard(
            index: index,
            title: service.name.of(locale),
            subtitle: service.duration.of(locale),
          );
        },
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: index.isEven ? ServioGradients.brand : ServioGradients.warm,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: index.isEven ? 0.14 : 0.44),
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: index.isEven ? Colors.white : ServioColors.deepBrown,
            ),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: index.isEven ? Colors.white : ServioColors.deepBrown,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: index.isEven
                  ? Colors.white.withValues(alpha: 0.72)
                  : ServioColors.deepBrown.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.area,
    required this.distance,
    required this.locale,
  });

  final String area;
  final String distance;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ServioGradients.warm,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
      ),
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            end: -6,
            bottom: -10,
            child: Icon(
              Icons.map_rounded,
              size: 86,
              color: ServioColors.deepBrown.withValues(alpha: 0.09),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.location_on_rounded, color: ServioColors.deepBrown),
              const Spacer(),
              Text(
                area,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: ServioColors.deepBrown,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _copy(locale, en: '$distance from you', ar: '$distance منك'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ServioColors.deepBrown.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.status,
    required this.pending,
  });

  final String label;
  final String status;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final color = pending ? servio.warning : servio.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            pending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _MiniChip(
            label: status,
            tone: pending ? _ChipTone.warning : _ChipTone.success,
          ),
        ],
      ),
    );
  }
}

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

IconData _specialtyIcon(String specialty) {
  return switch (specialty) {
    'plumbing' => Icons.plumbing_rounded,
    'electrical' => Icons.electrical_services_rounded,
    'ac-maintenance' => Icons.ac_unit_rounded,
    'painting' => Icons.format_paint_rounded,
    'carpentry' => Icons.carpenter_rounded,
    _ => Icons.handyman_rounded,
  };
}

String _copy(String locale, {required String en, required String ar}) {
  return locale == 'ar' ? ar : en;
}
