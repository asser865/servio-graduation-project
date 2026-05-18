import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_service_model.dart';
import '../../core/models/service_category.dart';
import '../../core/state/services_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'ai_smart_match_screen.dart';
import 'service_detail_screen.dart';
import '../shared/search_results_screen.dart';

class ServicesMarketplaceScreen extends StatefulWidget {
  const ServicesMarketplaceScreen({super.key});

  @override
  State<ServicesMarketplaceScreen> createState() =>
      _ServicesMarketplaceScreenState();
}

enum _SortOrder { relevance, priceLow, priceHigh, nameAZ }

class _ServicesMarketplaceScreenState extends State<ServicesMarketplaceScreen> {
  int _selectedCategory = 0;
  _SortOrder _sortOrder = _SortOrder.relevance;
  final Set<String> _expandedCategories = <String>{};

  static const Map<_SortOrder, String> _sortLabels = <_SortOrder, String>{
    _SortOrder.relevance: 'Relevance',
    _SortOrder.priceLow: 'Price: Low → High',
    _SortOrder.priceHigh: 'Price: High → Low',
    _SortOrder.nameAZ: 'Name: A–Z',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchAll();
    });
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_expandedCategories.contains(key)) {
        _expandedCategories.remove(key);
      } else {
        _expandedCategories.add(key);
      }
    });
  }

  void _openServiceDetails(BackendService service) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceDetailScreen(serviceId: service.id),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final servio = sheetCtx.servio;
        final surface = theme.colorScheme.surface;

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheet) {
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: servio.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Sort by', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._SortOrder.values.map((order) {
                    final active = _sortOrder == order;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() => _sortOrder = order);
                        Navigator.of(ctx).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _sortLabels[order]!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: active
                                      ? servio.accent
                                      : theme.colorScheme.onSurface,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (active)
                              Icon(Icons.check_rounded,
                                  color: servio.accent, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<BackendService> _sorted(List<BackendService> list) {
    final copy = List<BackendService>.from(list);
    switch (_sortOrder) {
      case _SortOrder.priceLow:
        copy.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      case _SortOrder.priceHigh:
        copy.sort((a, b) => b.basePrice.compareTo(a.basePrice));
      case _SortOrder.nameAZ:
        copy.sort((a, b) => a.name.compareTo(b.name));
      case _SortOrder.relevance:
        break;
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final provider = context.watch<ServicesProvider>();
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);
    final allServices = provider.services;
    final categoryKeys = <String>[
      'all',
      ...{
        for (final service in allServices)
          if (normalizeServiceCategory(service.category).isNotEmpty)
            normalizeServiceCategory(service.category),
      },
    ];
    if (_selectedCategory >= categoryKeys.length) _selectedCategory = 0;
    final selectedCategory = categoryKeys[_selectedCategory];
    final filtered = _selectedCategory == 0
        ? allServices
        : allServices
            .where(
                (s) => normalizeServiceCategory(s.category) == selectedCategory)
            .toList();
    final services = _sorted(filtered);
    final hasActiveFilter = _sortOrder != _SortOrder.relevance;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SearchResultsScreen(query: 'plumbing'),
                            ),
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search services',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: servio.surfaceAlt,
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                            borderSide: BorderSide(color: servio.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                            borderSide:
                                BorderSide(color: servio.accent, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showFilterSheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: hasActiveFilter
                                  ? ServioColors.tint(servio.accent)
                                  : theme.colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.full),
                              boxShadow: ServioShadows.rest,
                              border: hasActiveFilter
                                  ? Border.all(color: servio.accent, width: 1.5)
                                  : null,
                            ),
                            child:
                                Icon(Icons.tune_rounded, color: servio.accent),
                          ),
                          if (hasActiveFilter)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: servio.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 62,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryKeys.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final active = index == _selectedCategory;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? servio.accent : servio.backgroundSoft,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Text(
                          index == 0
                              ? 'All'
                              : serviceCategoryLabel(categoryKeys[index]),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: active ? Colors.white : servio.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _SmartMatchCta(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AiSmartMatchScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null)
              SliverFillRemaining(
                child: Center(child: Text(provider.error!)),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  ServioSpacing.screenPadding,
                  16,
                  ServioSpacing.screenPadding,
                  24 + bottomInset,
                ),
                sliver: _GroupedServicesSliver(
                  services: services,
                  onServiceTap: _openServiceDetails,
                  expandedCategories: _expandedCategories,
                  onToggleCategory: _toggleCategory,
                  forceExpandSingle: _selectedCategory != 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const Map<String, IconData> _serviceCategoryIcons = <String, IconData>{
  'plumbing': Icons.water_drop_outlined,
  'electrical': Icons.electrical_services_rounded,
  'hvac': Icons.ac_unit_rounded,
  'carpentry': Icons.handyman_rounded,
  'appliance': Icons.kitchen_rounded,
  'handyman': Icons.build_rounded,
  'painting': Icons.format_paint_rounded,
  'flooring': Icons.grid_4x4_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'pest-control': Icons.pest_control_rounded,
  'roofing': Icons.roofing_rounded,
  'drywall': Icons.square_foot_rounded,
  'renovation': Icons.architecture_rounded,
  'landscaping': Icons.park_rounded,
  'installation': Icons.precision_manufacturing_rounded,
  'other': Icons.home_repair_service_rounded,
};

const List<String> _categoryDisplayOrder = <String>[
  'plumbing',
  'electrical',
  'hvac',
  'carpentry',
  'appliance',
  'handyman',
  'painting',
  'flooring',
  'cleaning',
  'pest-control',
  'roofing',
  'drywall',
  'renovation',
  'landscaping',
  'installation',
  'other',
];

IconData _iconForCategory(String category) {
  return _serviceCategoryIcons[normalizeServiceCategory(category)] ??
      Icons.home_repair_service_rounded;
}

IconData _iconForService(BackendService service) {
  return _iconForCategory(service.category);
}

String _basePriceLabel(BackendService service) {
  return 'EGP ${service.basePrice.toStringAsFixed(0)}';
}

class _GroupedServicesSliver extends StatelessWidget {
  const _GroupedServicesSliver({
    required this.services,
    required this.onServiceTap,
    required this.expandedCategories,
    required this.onToggleCategory,
    required this.forceExpandSingle,
  });

  final List<BackendService> services;
  final ValueChanged<BackendService> onServiceTap;
  final Set<String> expandedCategories;
  final ValueChanged<String> onToggleCategory;
  final bool forceExpandSingle;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _MarketplaceEmptyState(),
      );
    }

    final Map<String, List<BackendService>> groups =
        <String, List<BackendService>>{};
    for (final BackendService service in services) {
      final String cat = normalizeServiceCategory(service.category);
      if (cat.isEmpty) continue;
      groups.putIfAbsent(cat, () => <BackendService>[]).add(service);
    }

    final List<String> ordered = <String>[
      ..._categoryDisplayOrder.where(groups.containsKey),
      ...groups.keys.where((String c) => !_categoryDisplayOrder.contains(c)),
    ];

    final bool autoExpandAll = forceExpandSingle && ordered.length == 1;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final String category = ordered[index];
          final List<BackendService> items = groups[category]!;
          final bool isLast = index == ordered.length - 1;
          final bool expanded =
              autoExpandAll || expandedCategories.contains(category);

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration:
                  Duration(milliseconds: 320 + (index * 60).clamp(0, 360)),
              curve: ServioMotion.reveal,
              builder: (BuildContext ctx, double t, Widget? child) {
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 18),
                    child: child,
                  ),
                );
              },
              child: _CategorySection(
                category: category,
                services: items,
                expanded: expanded,
                onToggle:
                    autoExpandAll ? null : () => onToggleCategory(category),
                onServiceTap: onServiceTap,
              ),
            ),
          );
        },
        childCount: ordered.length,
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.services,
    required this.expanded,
    required this.onToggle,
    required this.onServiceTap,
  });

  final String category;
  final List<BackendService> services;
  final bool expanded;
  final VoidCallback? onToggle;
  final ValueChanged<BackendService> onServiceTap;

  static const double _minGridCardWidth = 164;
  static const double _gridCardExtent = 178;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ServioThemeExtension servio = context.servio;
    final String label = serviceCategoryLabel(category);
    final IconData icon = _iconForCategory(category);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: servio.border),
        boxShadow: ServioShadows.rest,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CategoryHeader(
            label: label,
            count: services.length,
            icon: icon,
            expanded: expanded,
            onTap: onToggle,
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints constraints) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _buildGrid(constraints.maxWidth),
                );
              },
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: ServioMotion.bottomSheet,
            sizeCurve: ServioMotion.spring,
            firstCurve: ServioMotion.standard,
            secondCurve: ServioMotion.spring,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(double maxWidth) {
    int crossAxisCount = (maxWidth / _minGridCardWidth).floor();
    if (crossAxisCount < 1) {
      crossAxisCount = 1;
    } else if (crossAxisCount > 3) {
      crossAxisCount = 3;
    }
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: services.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: _gridCardExtent,
      ),
      itemBuilder: (BuildContext ctx, int index) {
        return _StaggeredReveal(
          index: index,
          child: _MarketplaceServiceGridCard(
            service: services[index],
            onTap: () => onServiceTap(services[index]),
          ),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.label,
    required this.count,
    required this.icon,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ServioThemeExtension servio = context.servio;
    final bool interactive = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: ServioMotion.normal,
                curve: ServioMotion.spring,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: ServioGradients.accent,
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  boxShadow: expanded ? ServioShadows.elevated : null,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? '1 service' : '$count services',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ServioColors.tint(servio.accent),
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: servio.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (interactive) ...<Widget>[
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: ServioMotion.normal,
                  curve: ServioMotion.spring,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: servio.textSecondary,
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

class _StaggeredReveal extends StatelessWidget {
  const _StaggeredReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) return child;
    final int delayMs = (index * 45).clamp(0, 360);
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(index),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: ServioMotion.reveal,
      builder: (BuildContext ctx, double t, Widget? c) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _MarketplaceServiceGridCard extends StatelessWidget {
  const _MarketplaceServiceGridCard({
    required this.service,
    required this.onTap,
  });

  final BackendService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final icon = _iconForService(service);

    return Semantics(
      button: true,
      label: 'View details for ${service.name}',
      child: ServioCard(
        onTap: onTap,
        radius: ServioRadius.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ServiceIconBadge(icon: icon, size: 44, iconSize: 22),
                const SizedBox(width: 8),
                Expanded(child: _CategoryBadge(category: service.category)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                service.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: servio.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _basePriceLabel(service),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: servio.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: servio.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceIconBadge extends StatelessWidget {
  const _ServiceIconBadge({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ServioGradients.brand,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final normalized = normalizeServiceCategory(category);
    final label = normalized.isEmpty
        ? 'SERVICE'
        : serviceCategoryLabel(normalized).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.accent),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: servio.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MarketplaceEmptyState extends StatelessWidget {
  const _MarketplaceEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 32,
            color: servio.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            'No services found',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Try another category.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartMatchCta extends StatefulWidget {
  const _SmartMatchCta({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SmartMatchCta> createState() => _SmartMatchCtaState();
}

class _SmartMatchCtaState extends State<_SmartMatchCta>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _pulse;
  late final AnimationController _press;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _press = AnimationController(
      vsync: this,
      duration: ServioMotion.fast,
      value: 1,
      lowerBound: 0.97,
      upperBound: 1,
    );
    _pressScale = CurvedAnimation(parent: _press, curve: ServioMotion.spring);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (pressed) {
      _press.animateTo(0.97);
    } else {
      _press.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: 'Open Smart Match — AI-powered service matching',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _pressScale,
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_shimmer, _pulse]),
            builder: (BuildContext ctx, Widget? child) {
              final double shimmerT = _shimmer.value;
              final double pulseT = _pulse.value;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                  gradient: ServioGradients.accent,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: servio.accent.withValues(
                        alpha: 0.28 + 0.12 * pulseT,
                      ),
                      blurRadius: 24 + 12 * pulseT,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: <Widget>[
                    if (!reduce)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _ShimmerSweep(progress: shimmerT),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Row(
                        children: <Widget>[
                          _SparkleBadge(pulse: pulseT, reduce: reduce),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Smart Match',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.22,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          ServioRadius.full,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Text(
                                        'AI',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Not sure what you need? Let AI match you.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ArrowChip(nudge: pulseT, reduce: reduce),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SparkleBadge extends StatelessWidget {
  const _SparkleBadge({required this.pulse, required this.reduce});

  final double pulse;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final double rotation = reduce ? 0 : (pulse - 0.5) * 0.18;
    final double scale = reduce ? 1 : 0.96 + pulse * 0.08;
    return Transform.rotate(
      angle: rotation,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(ServioRadius.md),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ArrowChip extends StatelessWidget {
  const _ArrowChip({required this.nudge, required this.reduce});

  final double nudge;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final double dx = reduce ? 0 : nudge * 4 - 2;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _ShimmerSweep extends StatelessWidget {
  const _ShimmerSweep({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double t = progress * 2 - 0.5;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1.0 + t, -0.2),
          end: Alignment(-0.4 + t, 0.6),
          colors: <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
