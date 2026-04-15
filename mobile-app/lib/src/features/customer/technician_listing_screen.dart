import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/demo_technicians.dart';
import '../../core/models/technician_model.dart';
import '../../core/state/app_state.dart';
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
  final Set<String> _selectedIds = <String>{};

  static const List<String> _filters = <String>[
    'Rating 4+',
    'Available Today',
    'Under 200 EGP/hr',
    'Verified Only',
  ];

  List<TechnicianModel> get _technicians {
    if (widget.serviceId == null) return kDemoTechnicians;
    return kDemoTechnicians.where((t) => t.specialty == widget.serviceId).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().languageCode;
    final technicians = _technicians;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${technicians.length} Technicians Available',
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final tech = technicians[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _TechnicianListCard(
                            technician: tech,
                            locale: locale,
                            selected: _selectedIds.contains(tech.id),
                            onSelect: () => _toggleSelection(tech.id),
                            onViewProfile: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TechnicianProfileScreen(technicianId: tech.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: technicians.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedIds.length >= 2)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(ServioRadius.xl),
                    boxShadow: ServioShadows.elevated,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Compare (${_selectedIds.length})',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(_selectedIds.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('View Comparison'),
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

class _TechnicianListCard extends StatelessWidget {
  const _TechnicianListCard({
    required this.technician,
    required this.locale,
    required this.selected,
    required this.onSelect,
    required this.onViewProfile,
  });

  final TechnicianModel technician;
  final String locale;
  final bool selected;
  final VoidCallback onSelect;
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
                    technician.avatarInitials,
                    style: theme.textTheme.labelLarge?.copyWith(color: ServioColors.deepBrown),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(technician.name.of(locale), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      technician.title.of(locale),
                      style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${technician.rating} rating  •  (${technician.reviewCount} reviews)  •  ${technician.responseTime}',
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${technician.pricePerHour} EGP / hour',
                      style: theme.textTheme.titleMedium?.copyWith(color: servio.accent),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onSelect(),
                    activeColor: servio.accent,
                  ),
                  if (technician.verified)
                    const ServioStatusChip(label: 'Verified'),
                ],
              ),
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
