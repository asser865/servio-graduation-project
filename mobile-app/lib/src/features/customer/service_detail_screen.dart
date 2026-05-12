import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/services_api.dart';
import '../../core/data/demo_services.dart';
import '../../core/models/backend_service_model.dart';
import '../../core/models/service_category.dart';
import '../../core/models/service_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/services_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'technician_listing_screen.dart';

IconData _iconForKey(String key) => switch (key) {
      'bolt' => Icons.bolt_rounded,
      'temp' => Icons.ac_unit_rounded,
      'wrench' => Icons.handyman_rounded,
      'paint' => Icons.format_paint_rounded,
      _ => Icons.water_drop_rounded,
    };

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({this.serviceId, super.key});

  /// Pass a service id (e.g. 'plumbing') to show that service's data.
  /// Defaults to the first available service.
  final String? serviceId;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  int _selectedTab = 0;
  BackendService? _backendService;

  static const List<String> _tabs = <String>['Overview', 'About', 'Reviews'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBackendService());
  }

  ServiceModel get _service {
    if (widget.serviceId == null) return kDemoServices.first;
    return kDemoServices.firstWhere(
      (ServiceModel s) => s.id == widget.serviceId,
      orElse: () => kDemoServices.first,
    );
  }

  Future<void> _loadBackendService() async {
    final serviceId = widget.serviceId?.trim();
    if (serviceId == null || serviceId.isEmpty) return;

    final servicesProvider = context.read<ServicesProvider>();
    final cached = servicesProvider.findById(serviceId) ??
        servicesProvider.findFirstByCategory(serviceId);
    if (cached != null) {
      if (mounted) setState(() => _backendService = cached);
      return;
    }

    try {
      final api = ServicesApi(context.read<ApiClient>());
      BackendService? service;
      if (_looksLikeMongoId(serviceId)) {
        service = await api.getServiceById(serviceId);
      } else {
        final category = normalizeServiceCategory(serviceId);
        if (category.isEmpty) return;
        final services = await api.getServices(category: category);
        if (services.isNotEmpty) service = services.first;
      }
      if (service == null) return;
      if (mounted) setState(() => _backendService = service);
    } catch (_) {
      // Keep the existing demo fallback if the backend record cannot load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final service = _service;
    final backendService = _backendService;
    final rawServiceCategory = backendService?.category;
    final canonicalCategory =
        normalizeServiceCategory(rawServiceCategory ?? widget.serviceId);
    final serviceTitle = backendService?.name ?? service.title.of(locale);
    final serviceCategory = (canonicalCategory.isEmpty
            ? 'HOME MAINTENANCE'
            : serviceCategoryLabel(canonicalCategory))
        .toUpperCase();
    final serviceDescription =
        backendService?.description ?? service.lead.of(locale);
    final servicePriceLabel = backendService == null
        ? service.priceBadge.of(locale)
        : 'EGP ${backendService.basePrice.toStringAsFixed(0)}';
    final canonicalServiceId = backendService?.id ??
        (_looksLikeMongoId(widget.serviceId) ? widget.serviceId!.trim() : null);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Stack(
                  children: <Widget>[
                    Container(
                      height: 280,
                      decoration: const BoxDecoration(
                        gradient: ServioGradients.brand,
                      ),
                      child: Stack(
                        children: <Widget>[
                          Positioned(
                            right: 24,
                            top: 90,
                            child: Icon(
                              _iconForKey(service.icon),
                              size: 120,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 110,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    Colors.transparent,
                                    ServioColors.navyDark
                                        .withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: <Widget>[
                            _FloatingActionIcon(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            _FloatingActionIcon(
                              icon: Icons.share_outlined,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.sm),
                        ),
                        child: Text(
                          serviceCategory,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: servio.accent),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(serviceTitle, style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: ServioGradients.accent,
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.full),
                            ),
                            child: Text(
                              'AI PRICE ESTIMATE',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ServioStatusChip(label: servicePriceLabel),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Row(
                          children:
                              List<Widget>.generate(_tabs.length, (int index) {
                            final active = index == _selectedTab;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedTab = index),
                                child: AnimatedContainer(
                                  duration: ServioMotion.micro,
                                  curve: ServioMotion.curve,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Theme.of(context).colorScheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                        ServioRadius.full),
                                  ),
                                  child: Text(
                                    _tabs[index],
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: active
                                          ? servio.accent
                                          : servio.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: ServioMotion.micro,
                        child: _buildTabContent(
                          context,
                          service,
                          locale,
                          serviceDescription,
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: ServioShadows.elevated,
                ),
                child: ServioPrimaryButton(
                  label: locale == 'ar' ? 'ابحث عن فني' : 'Find a Technician',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TechnicianListingScreen(
                          serviceId: canonicalServiceId,
                          category: canonicalCategory,
                          title: serviceTitle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    ServiceModel service,
    String locale,
    String serviceDescription,
  ) {
    final theme = Theme.of(context);
    final servio = context.servio;

    switch (_selectedTab) {
      case 0:
        return Column(
          key: const ValueKey<int>(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              serviceDescription,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              locale == 'ar' ? 'ما يشمله الخدمة' : "What's included",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...service.included.map(
              (ServiceIncluded item) => _ChecklistItem(
                label: item.title.of(locale),
                subtitle: item.desc.of(locale),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey<int>(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(locale == 'ar' ? 'تسعير الخدمة' : 'Service Pricing',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...service.pricing.map(
              (ServicePricingTier tier) =>
                  _PricingCard(tier: tier, locale: locale),
            ),
            const SizedBox(height: 20),
            Text(locale == 'ar' ? 'الأسئلة الشائعة' : 'FAQs',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...service.faqs.map(
              (ServiceFaq faq) => _FaqItem(faq: faq, locale: locale),
            ),
            const SizedBox(height: 16),
            Text(service.ctaTitle.of(locale),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              service.ctaSub.of(locale),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey<int>(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              locale == 'ar' ? 'آراء العملاء' : 'Customer Reviews',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ReviewBar(
                label: locale == 'ar' ? '5 نجوم' : '5 stars', value: 0.72),
            const SizedBox(height: 8),
            _ReviewBar(
                label: locale == 'ar' ? '4 نجوم' : '4 stars', value: 0.18),
            const SizedBox(height: 8),
            _ReviewBar(
                label: locale == 'ar' ? '3 نجوم' : '3 stars', value: 0.06),
            const SizedBox(height: 20),
            ...service.reviews.map(
              (ServiceReview r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(
                  name: r.name.of(locale),
                  body: r.quote.of(locale),
                  stars: r.stars,
                ),
              ),
            ),
          ],
        );
    }
  }
}

bool _looksLikeMongoId(String? value) =>
    value != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value);

class _FloatingActionIcon extends StatelessWidget {
  const _FloatingActionIcon({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(ServioRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(ServioRadius.full),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ServioRadius.full),
            boxShadow: ServioShadows.rest,
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded,
                color: servio.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.tier, required this.locale});

  final ServicePricingTier tier;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            tier.featured ? servio.backgroundSoft : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(
          color: tier.featured ? servio.accent : servio.border,
          width: tier.featured ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text(tier.tier.of(locale),
                      style: theme.textTheme.titleMedium)),
              if (tier.featured)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: ServioGradients.brand,
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Text(
                    locale == 'ar' ? 'الأكثر شيوعاً' : 'Most Popular',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tier.price.of(locale),
            style: theme.textTheme.titleMedium?.copyWith(color: servio.accent),
          ),
          const SizedBox(height: 6),
          Text(
            tier.jobs.of(locale),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.faq, required this.locale});

  final ServiceFaq faq;
  final String locale;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: servio.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(widget.faq.question.of(widget.locale),
                        style: theme.textTheme.labelLarge),
                  ),
                  Icon(_expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                ],
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  widget.faq.answer.of(widget.locale),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Row(
      children: <Widget>[
        SizedBox(width: 64, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ServioRadius.full),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: servio.backgroundSoft,
              valueColor: AlwaysStoppedAnimation<Color>(servio.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.body,
    this.stars = 5,
  });

  final String name;
  final String body;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: servio.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Row(
            children: List<Widget>.generate(
              stars,
              (_) => Icon(Icons.star_rounded, color: servio.accent, size: 16),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}
