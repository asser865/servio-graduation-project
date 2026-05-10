import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_service_model.dart';
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
  bool _gridMode = false;
  _SortOrder _sortOrder = _SortOrder.relevance;

  static const List<String> _categories = <String>[
    'All',
    'Plumbing',
    'Electrical',
    'Painting',
    'HVAC',
    'Carpentry',
  ];

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
                24, 12, 24,
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
    final filtered = _selectedCategory == 0
        ? allServices
        : allServices
            .where((s) =>
                s.category.toLowerCase() ==
                _categories[_selectedCategory].toLowerCase())
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
                                  ? Border.all(
                                      color: servio.accent, width: 1.5)
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
                  itemCount: _categories.length,
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
                          _categories[index],
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
                child: Row(
                  children: <Widget>[
                    const Spacer(),
                    Text(
                      'Sort: ${_sortLabels[_sortOrder]}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasActiveFilter
                            ? servio.accent
                            : servio.textSecondary,
                        fontWeight: hasActiveFilter
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ToggleIcon(
                      icon: Icons.view_agenda_outlined,
                      tooltip: 'List view',
                      active: !_gridMode,
                      onTap: () => setState(() => _gridMode = false),
                    ),
                    const SizedBox(width: 8),
                    _ToggleIcon(
                      icon: Icons.grid_view_rounded,
                      tooltip: 'Grid view',
                      active: _gridMode,
                      onTap: () => setState(() => _gridMode = true),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AiSmartMatchScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ServioRadius.lg),
                      border: Border.all(color: servio.accent, width: 1.5),
                      color: theme.colorScheme.surface,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome_rounded, color: servio.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Not sure what you need? Try Smart Match ->',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                sliver: _MarketplaceServicesSliver(
                  services: services,
                  gridMode: _gridMode,
                  onServiceTap: _openServiceDetails,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Semantics(
      button: true,
      selected: active,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: ServioSpacing.tapTarget,
            height: ServioSpacing.tapTarget,
            decoration: BoxDecoration(
              color: active
                  ? servio.backgroundSoft
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ServioRadius.full),
              border: Border.all(color: servio.border),
            ),
            child: Icon(icon,
                size: 20, color: active ? servio.accent : servio.textSecondary),
          ),
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
  'painting': Icons.format_paint_rounded,
};

IconData _iconForService(BackendService service) {
  return _serviceCategoryIcons[service.category.toLowerCase()] ??
      Icons.home_repair_service_rounded;
}

String _basePriceLabel(BackendService service) {
  return 'EGP ${service.basePrice.toStringAsFixed(0)}';
}

class _MarketplaceServicesSliver extends StatelessWidget {
  const _MarketplaceServicesSliver({
    required this.services,
    required this.gridMode,
    required this.onServiceTap,
  });

  final List<BackendService> services;
  final bool gridMode;
  final ValueChanged<BackendService> onServiceTap;

  static const double _minGridCardWidth = 164;
  static const double _gridCardExtent = 178;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _MarketplaceEmptyState(),
      );
    }

    if (!gridMode) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final service = services[index];
            final isLast = index == services.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: _MarketplaceServiceCard(
                service: service,
                onTap: () => onServiceTap(service),
              ),
            );
          },
          childCount: services.length,
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (BuildContext context, constraints) {
        var crossAxisCount =
            (constraints.crossAxisExtent / _minGridCardWidth).floor();
        if (crossAxisCount < 1) {
          crossAxisCount = 1;
        } else if (crossAxisCount > 2) {
          crossAxisCount = 2;
        }

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: _gridCardExtent,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final service = services[index];

              return _MarketplaceServiceGridCard(
                service: service,
                onTap: () => onServiceTap(service),
              );
            },
            childCount: services.length,
          ),
        );
      },
    );
  }
}

class _MarketplaceServiceCard extends StatelessWidget {
  const _MarketplaceServiceCard({
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Row(
            children: <Widget>[
              _ServiceIconBadge(icon: icon, size: 52, iconSize: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CategoryBadge(category: service.category),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
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
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: servio.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final label = category.trim().isEmpty ? 'SERVICE' : category.toUpperCase();

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
