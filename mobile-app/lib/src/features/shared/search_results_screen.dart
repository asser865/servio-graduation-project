import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_service_model.dart';
import '../../core/models/backend_worker_model.dart';
import '../../core/models/service_category.dart';
import '../../core/state/services_state.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/ai_smart_match_screen.dart';
import '../customer/service_detail_screen.dart';
import '../customer/technician_profile_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, this.query = ''});

  final String query;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  int _tabIndex = 0;
  final Set<String> _activeFilters = <String>{};
  late final TextEditingController _searchCtrl;

  static const List<String> _filterOptions = <String>[
    'Verified Only',
    'Rating 4+',
    'Available Today',
    'Under 250 EGP/hr',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchAll();
      context.read<WorkersProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _q => _searchCtrl.text.trim().toLowerCase();

  List<BackendService> _filteredServices(List<BackendService> services) {
    return services.where((service) {
      final category = serviceCategoryLabel(service.category).toLowerCase();
      if (_q.isNotEmpty &&
          !service.name.toLowerCase().contains(_q) &&
          !service.description.toLowerCase().contains(_q) &&
          !category.contains(_q)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<BackendWorker> _filteredTechnicians(List<BackendWorker> workers) {
    return workers.where((worker) {
      final searchable = <String>[
        worker.displayName,
        worker.bio,
        worker.locationLabel,
        ...worker.skills,
        ...worker.categories,
        ...worker.serviceLabels,
      ].join(' ').toLowerCase();

      if (_q.isNotEmpty && !searchable.contains(_q)) return false;
      if (_activeFilters.contains('Verified Only') && !worker.isVerified) {
        return false;
      }
      if (_activeFilters.contains('Rating 4+') && worker.rating < 4.0) {
        return false;
      }
      if (_activeFilters.contains('Available Today') &&
          worker.availability.isEmpty) {
        return false;
      }
      if (_activeFilters.contains('Under 250 EGP/hr') &&
          worker.hourlyRate >= 250) {
        return false;
      }
      return true;
    }).toList();
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_activeFilters.contains(filter)) {
        _activeFilters.remove(filter);
      } else {
        _activeFilters.add(filter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final servicesProvider = context.watch<ServicesProvider>();
    final workersProvider = context.watch<WorkersProvider>();
    final services = _filteredServices(servicesProvider.services);
    final technicians = _filteredTechnicians(workersProvider.workers);
    final activeLoading =
        _tabIndex == 0 ? servicesProvider.loading : workersProvider.loading;
    final activeError =
        _tabIndex == 0 ? servicesProvider.error : workersProvider.error;
    final count = _tabIndex == 0 ? services.length : technicians.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Padding(
          padding: const EdgeInsets.only(right: ServioSpacing.screenPadding),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search services & professionals...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    )
                  : null,
              filled: true,
              fillColor: servio.surfaceAlt,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.full),
                borderSide: BorderSide(color: servio.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.full),
                borderSide: BorderSide(color: servio.accent),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ServioSpacing.screenPadding,
              12,
              ServioSpacing.screenPadding,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Row(
                children: List<Widget>.generate(2, (int i) {
                  final active = i == _tabIndex;
                  final labels = <String>['Services', 'Technicians'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = i),
                      child: AnimatedContainer(
                        duration: ServioMotion.micro,
                        curve: ServioMotion.curve,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.surface
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                          boxShadow: active
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color:
                                active ? servio.accent : servio.textSecondary,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding,
                vertical: 8,
              ),
              children: _filterOptions.map((String filter) {
                final active = _activeFilters.contains(filter);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _toggleFilter(filter),
                    child: AnimatedContainer(
                      duration: ServioMotion.micro,
                      curve: ServioMotion.curve,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active ? servio.accent : servio.backgroundSoft,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                        border: Border.all(
                          color: active ? servio.accent : servio.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (active) ...<Widget>[
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            filter,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color:
                                  active ? Colors.white : servio.textSecondary,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ServioSpacing.screenPadding,
              4,
              ServioSpacing.screenPadding,
              4,
            ),
            child: Text(
              '$count result${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
          Expanded(
            child: _tabIndex == 0
                ? _ServicesResults(
                    results: services,
                    loading: activeLoading,
                    error: activeError,
                  )
                : _TechniciansResults(
                    technicians: technicians,
                    loading: activeLoading,
                    error: activeError,
                    query: _q,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServicesResults extends StatelessWidget {
  const _ServicesResults({
    required this.results,
    required this.loading,
    required this.error,
  });

  final List<BackendService> results;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorState(message: error!);
    if (results.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, int i) => _ServiceCard(result: results[i]),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.result});

  final BackendService result;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final category = normalizeServiceCategory(result.category);

    return ServioCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ServiceDetailScreen(serviceId: result.id),
          ),
        );
      },
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: ServioGradients.brand,
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Icon(
              _iconForCategory(category),
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child:
                          Text(result.name, style: theme.textTheme.titleSmall),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ServioColors.tint(servio.accent),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        serviceCategoryLabel(category),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: servio.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'From ${result.basePrice.toStringAsFixed(0)} EGP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: servio.accent,
                      fontWeight: FontWeight.w700,
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

class _TechniciansResults extends StatelessWidget {
  const _TechniciansResults({
    required this.technicians,
    required this.loading,
    required this.error,
    required this.query,
  });

  final List<BackendWorker> technicians;
  final bool loading;
  final String? error;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorState(message: error!);
    if (technicians.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      itemCount: technicians.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, int i) => _TechnicianCard(
        worker: technicians[i],
        query: query,
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.worker,
    required this.query,
  });

  final BackendWorker worker;
  final String query;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final subtitle = worker.serviceLabels.isNotEmpty
        ? worker.serviceLabels.take(2).join(', ')
        : worker.skills.take(2).join(', ');
    final selectedService = _serviceForQuery(worker, query);
    final selectedCategory = normalizeServiceCategory(
      selectedService?.category ?? query,
    );
    final selectedName = selectedCategory.isEmpty
        ? null
        : serviceCategoryLabel(selectedCategory);

    return ServioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: ServioGradients.warm,
                  shape: BoxShape.circle,
                  border: Border.all(color: servio.accent, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: worker.profileImage.isEmpty
                    ? _WorkerInitials(initials: worker.initials)
                    : Image.network(
                        worker.profileImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _WorkerInitials(initials: worker.initials),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            worker.displayName,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (worker.isVerified)
                          Icon(
                            Icons.verified_rounded,
                            color: servio.accent,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.isEmpty ? 'Technician' : subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.star_rounded, color: servio.accent, size: 14),
              const SizedBox(width: 3),
              Text(
                worker.rating.toStringAsFixed(1),
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                ' (${worker.reviewCount})',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: servio.textSecondary),
              ),
              const Spacer(),
              Text(
                '${worker.hourlyRate} EGP/hr',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: servio.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ServioPrimaryButton(
              label: 'View Profile',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TechnicianProfileScreen(
                      technicianId: worker.id,
                      selectedServiceId: selectedService?.id,
                      selectedServiceCategory:
                          selectedCategory.isEmpty ? null : selectedCategory,
                      selectedServiceName: selectedName,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

BackendWorkerService? _serviceForQuery(BackendWorker worker, String query) {
  final normalizedCategory = normalizeServiceCategory(query);
  if (normalizedCategory.isNotEmpty) {
    for (final service in worker.services) {
      if (normalizeServiceCategory(service.category) == normalizedCategory) {
        return service;
      }
    }
  }

  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return null;
  for (final service in worker.services) {
    if (service.displayName.toLowerCase().contains(normalizedQuery)) {
      return service;
    }
  }
  return null;
}

class _WorkerInitials extends StatelessWidget {
  const _WorkerInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ServioColors.deepBrown,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: servio.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: ServioGradients.warm,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 52,
                color: servio.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text('No results found', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters, or let Smart Match find the right professional for you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            ServioPrimaryButton(
              label: 'Try Smart Match',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiSmartMatchScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForCategory(String category) {
  return switch (normalizeServiceCategory(category)) {
    'plumbing' => Icons.water_drop_outlined,
    'electrical' => Icons.electrical_services_rounded,
    'hvac' => Icons.ac_unit_rounded,
    'carpentry' => Icons.handyman_rounded,
    'painting' => Icons.format_paint_rounded,
    'flooring' => Icons.grid_on_rounded,
    'cleaning' => Icons.cleaning_services_rounded,
    _ => Icons.home_repair_service_rounded,
  };
}
