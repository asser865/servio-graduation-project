import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/demo_technicians.dart';
import '../../core/models/technician_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/ai_smart_match_screen.dart';
import '../customer/technician_profile_screen.dart';

// ---------------------------------------------------------------------------
// Demo service catalogue
// ---------------------------------------------------------------------------

class _ServiceResult {
  const _ServiceResult({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.priceFrom,
    required this.rating,
    required this.reviewCount,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final IconData icon;
  final int priceFrom;
  final double rating;
  final int reviewCount;
}

const List<_ServiceResult> _kServices = <_ServiceResult>[
  _ServiceResult(
    id: 'plumbing',
    name: 'Plumbing Repair',
    category: 'Plumbing',
    description: 'Leak fixes, pipe replacement, bathroom installation & more.',
    icon: Icons.water_drop_outlined,
    priceFrom: 200,
    rating: 4.8,
    reviewCount: 2341,
  ),
  _ServiceResult(
    id: 'electrical',
    name: 'Electrical Work',
    category: 'Electrical',
    description:
        'Wiring, lighting installation, panel upgrades & fault diagnosis.',
    icon: Icons.bolt_outlined,
    priceFrom: 250,
    rating: 4.7,
    reviewCount: 1876,
  ),
  _ServiceResult(
    id: 'ac-maintenance',
    name: 'AC Maintenance',
    category: 'HVAC',
    description: 'AC service, cleaning, installation & compressor repair.',
    icon: Icons.ac_unit_outlined,
    priceFrom: 220,
    rating: 4.9,
    reviewCount: 3102,
  ),
  _ServiceResult(
    id: 'painting',
    name: 'Painting & Finishing',
    category: 'Painting',
    description:
        'Interior & exterior painting, Venetian plaster, decorative finishes.',
    icon: Icons.format_paint_outlined,
    priceFrom: 180,
    rating: 4.6,
    reviewCount: 987,
  ),
  _ServiceResult(
    id: 'carpentry',
    name: 'Carpentry & Woodwork',
    category: 'Carpentry',
    description:
        'Custom furniture, built-in wardrobes, kitchen cabinets & repairs.',
    icon: Icons.handyman_outlined,
    priceFrom: 210,
    rating: 4.5,
    reviewCount: 654,
  ),
  _ServiceResult(
    id: 'cleaning',
    name: 'Deep Cleaning',
    category: 'Cleaning',
    description: 'Full apartment deep clean, post-construction clean-up.',
    icon: Icons.cleaning_services_outlined,
    priceFrom: 150,
    rating: 4.7,
    reviewCount: 1423,
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

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
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _q => _searchCtrl.text.trim().toLowerCase();

  List<_ServiceResult> get _filteredServices {
    return _kServices.where((_ServiceResult s) {
      if (_q.isNotEmpty &&
          !s.name.toLowerCase().contains(_q) &&
          !s.category.toLowerCase().contains(_q)) {
        return false;
      }
      if (_activeFilters.contains('Rating 4+') && s.rating < 4.0) return false;
      return true;
    }).toList();
  }

  List<TechnicianModel> get _filteredTechnicians {
    return kDemoTechnicians.where((TechnicianModel t) {
      if (_q.isNotEmpty &&
          !t.name.en.toLowerCase().contains(_q) &&
          !t.specialty.toLowerCase().contains(_q) &&
          !t.title.en.toLowerCase().contains(_q)) {
        return false;
      }
      if (_activeFilters.contains('Verified Only') && !t.verified) return false;
      if (_activeFilters.contains('Rating 4+') && t.rating < 4.0) return false;
      if (_activeFilters.contains('Available Today') &&
          !t.availability.en.toLowerCase().contains('today')) {
        return false;
      }
      if (_activeFilters.contains('Under 250 EGP/hr') &&
          t.pricePerHour >= 250) {
        return false;
      }
      return true;
    }).toList();
  }

  void _toggleFilter(String f) {
    setState(() {
      if (_activeFilters.contains(f)) {
        _activeFilters.remove(f);
      } else {
        _activeFilters.add(f);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final services = _filteredServices;
    final technicians = _filteredTechnicians;
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
                      onPressed: () =>
                          setState(() => _searchCtrl.clear()),
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
          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding, 12, ServioSpacing.screenPadding, 0),
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
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding, vertical: 8),
              children: _filterOptions.map((String f) {
                final active = _activeFilters.contains(f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _toggleFilter(f),
                    child: AnimatedContainer(
                      duration: ServioMotion.micro,
                      curve: ServioMotion.curve,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? servio.accent : servio.backgroundSoft,
                        borderRadius:
                            BorderRadius.circular(ServioRadius.full),
                        border: Border.all(
                          color: active ? servio.accent : servio.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (active) ...<Widget>[
                            Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            f,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: active
                                  ? Colors.white
                                  : servio.textSecondary,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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
          // Result count
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding, 4, ServioSpacing.screenPadding, 4),
            child: Text(
              '$count result${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
          // Results
          Expanded(
            child: _tabIndex == 0
                ? _ServicesResults(results: services)
                : _TechniciansResults(technicians: technicians),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Services results
// ---------------------------------------------------------------------------

class _ServicesResults extends StatelessWidget {
  const _ServicesResults({required this.results});

  final List<_ServiceResult> results;

  @override
  Widget build(BuildContext context) {
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

  final _ServiceResult result;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return ServioCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: ServioGradients.brand,
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Icon(result.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(result.name,
                          style: theme.textTheme.titleSmall),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ServioColors.tint(servio.accent),
                        borderRadius:
                            BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        result.category,
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
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded,
                        color: servio.accent, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      result.rating.toStringAsFixed(1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ' (${result.reviewCount})',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      'From ${result.priceFrom} EGP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: servio.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Technician results
// ---------------------------------------------------------------------------

class _TechniciansResults extends StatelessWidget {
  const _TechniciansResults({required this.technicians});

  final List<TechnicianModel> technicians;

  @override
  Widget build(BuildContext context) {
    if (technicians.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      itemCount: technicians.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, int i) => _TechnicianCard(tech: technicians[i]),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.tech});

  final TechnicianModel tech;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>().languageCode;

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
                child: Center(
                  child: Text(
                    tech.avatarInitials,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: ServioColors.deepBrown),
                  ),
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
                            locale == 'ar'
                                ? tech.name.ar
                                : tech.name.en,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (tech.verified)
                          Icon(Icons.verified_rounded,
                              color: servio.accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locale == 'ar' ? tech.title.ar : tech.title.en,
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
                tech.rating.toStringAsFixed(1),
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                ' (${tech.reviewCount})',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(width: 12),
              Icon(Icons.location_on_outlined,
                  size: 13, color: servio.textSecondary),
              const SizedBox(width: 2),
              Text(
                tech.distance,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: servio.textSecondary),
              ),
              const Spacer(),
              Text(
                '${tech.pricePerHour} EGP/hr',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: servio.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: tech.availability.en.toLowerCase().contains('today')
                      ? servio.success
                      : servio.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                locale == 'ar'
                    ? tech.availability.ar
                    : tech.availability.en,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: servio.textSecondary),
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
                    builder: (_) =>
                        TechnicianProfileScreen(technicianId: tech.id),
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

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
              child: Icon(Icons.travel_explore_rounded,
                  size: 52, color: servio.accent),
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
