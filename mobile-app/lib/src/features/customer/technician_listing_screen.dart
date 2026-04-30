import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_worker_model.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'technician_profile_screen.dart';

class TechnicianListingScreen extends StatefulWidget {
  const TechnicianListingScreen({this.serviceId, super.key});

  final String? serviceId;

  @override
  State<TechnicianListingScreen> createState() => _TechnicianListingScreenState();
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
      context.read<WorkersProvider>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final provider = context.watch<WorkersProvider>();
    final workers = provider.workers;

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
                        '${workers.length} Technicians Available',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    Text(
                      'Sort: Rating',
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: servio.backgroundSoft,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        _filters[index],
                        style: theme.textTheme.labelLarge?.copyWith(color: servio.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (provider.error != null)
              SliverFillRemaining(child: Center(child: Text(provider.error!)))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final worker = provider.workers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TechnicianListCard(
                          worker: worker,
                          onViewProfile: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TechnicianProfileScreen(technicianId: worker.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: provider.workers.length,
                  ),
                ),
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
                child: Center(
                  child: Text(
                    worker.initials,
                    style: theme.textTheme.labelLarge?.copyWith(color: ServioColors.deepBrown),
                  ),
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
                      style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${worker.rating.toStringAsFixed(1)} rating  ·  (${worker.reviewCount} reviews)',
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'EGP ${worker.hourlyRate}/hr',
                      style: theme.textTheme.titleMedium?.copyWith(color: servio.accent),
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
