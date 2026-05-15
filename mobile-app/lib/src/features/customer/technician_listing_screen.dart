import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_worker_model.dart';
import '../../core/models/service_category.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'technician_profile_screen.dart';

class TechnicianListingScreen extends StatefulWidget {
  const TechnicianListingScreen({
    this.serviceId,
    this.category,
    this.title,
    super.key,
  });

  final String? serviceId;
  final String? category;
  final String? title;

  @override
  State<TechnicianListingScreen> createState() =>
      _TechnicianListingScreenState();
}

class _TechnicianListingScreenState extends State<TechnicianListingScreen> {
  static const List<String> _filters = <String>[
    'Rating 4+',
    'Available Today',
    'Under 200 EGP/hr',
    'Verified Only',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final serviceId =
          _looksLikeMongoId(widget.serviceId) ? widget.serviceId : null;
      final category = normalizeServiceCategory(
        widget.category ??
            (_looksLikeMongoId(widget.serviceId) ? null : widget.serviceId),
      );

      context.read<WorkersProvider>().fetchAll(
            serviceId: serviceId,
            category: category.isEmpty ? null : category,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final provider = context.watch<WorkersProvider>();
    final serviceId =
        _looksLikeMongoId(widget.serviceId) ? widget.serviceId!.trim() : '';
    final category = normalizeServiceCategory(
      widget.category ??
          (_looksLikeMongoId(widget.serviceId) ? null : widget.serviceId),
    );
    final workers = _filterWorkersForSelection(
      provider.workers,
      serviceId: serviceId,
      category: category,
    );
    final listingTitle = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : category.isNotEmpty
            ? serviceCategoryLabel(category)
            : 'Technicians';
    final selectedServiceName = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : category.isNotEmpty
            ? listingTitle
            : null;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '$listingTitle\n${workers.length} Technicians Available',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    Text(
                      'Sort: Rating',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: servio.backgroundSoft,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        _filters[index],
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (provider.error != null)
              SliverFillRemaining(child: Center(child: Text(provider.error!)))
            else if (workers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _TechnicianEmptyState(category: listingTitle),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final worker = workers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TechnicianListCard(
                          worker: worker,
                          onViewProfile: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TechnicianProfileScreen(
                                  technicianId: worker.id,
                                  selectedServiceId:
                                      serviceId.isNotEmpty ? serviceId : null,
                                  selectedServiceCategory:
                                      category.isNotEmpty ? category : null,
                                  selectedServiceName: selectedServiceName,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: workers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _looksLikeMongoId(String? value) =>
    value != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value);

List<BackendWorker> _filterWorkersForSelection(
  List<BackendWorker> workers, {
  required String serviceId,
  required String category,
}) {
  if (serviceId.isEmpty && category.isEmpty) return workers;
  return workers.where((worker) {
    final serviceMatches =
        serviceId.isNotEmpty && worker.offersService(serviceId);
    final categoryMatches =
        category.isNotEmpty && worker.offersCategory(category);
    return serviceMatches || categoryMatches;
  }).toList();
}

class _TechnicianEmptyState extends StatelessWidget {
  const _TechnicianEmptyState({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_search_rounded,
              size: 42,
              color: servio.textSecondary,
            ),
            const SizedBox(height: 12),
            Text('No technicians found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'There are no available technicians for $category right now.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianListCard extends StatelessWidget {
  const _TechnicianListCard({
    required this.worker,
    required this.onViewProfile,
  });

  final BackendWorker worker;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: ServioGradients.warm,
                  shape: BoxShape.circle,
                  border: Border.all(color: servio.accent, width: 2),
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
                    Text(worker.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      worker.skills.take(2).join(', '),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${worker.rating.toStringAsFixed(1)} rating - (${worker.reviewCount} reviews)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'EGP ${worker.hourlyRate}/hr',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: servio.accent),
                    ),
                  ],
                ),
              ),
              if (worker.isVerified) const ServioStatusChip(label: 'Verified'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onViewProfile,
              child: const Text('View Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerInitials extends StatelessWidget {
  const _WorkerInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ServioColors.deepBrown,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
