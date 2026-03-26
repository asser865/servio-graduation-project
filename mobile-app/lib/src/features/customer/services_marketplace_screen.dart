import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import 'ai_smart_match_screen.dart';
import 'customer_profile_screen.dart';
import 'service_detail_screen.dart';
import '../shared/search_results_screen.dart';

class ServicesMarketplaceScreen extends StatefulWidget {
  const ServicesMarketplaceScreen({super.key});

  @override
  State<ServicesMarketplaceScreen> createState() => _ServicesMarketplaceScreenState();
}

class _ServicesMarketplaceScreenState extends State<ServicesMarketplaceScreen> {
  int _selectedCategory = 0;
  bool _gridMode = false;

  static const List<String> _categories = <String>[
    'All',
    'Plumbing',
    'Electrical',
    'Painting',
    'HVAC',
    'Cleaning',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
          ServioBottomNavItem(icon: Icons.grid_view_rounded, label: 'Services'),
          ServioBottomNavItem(
            icon: Icons.auto_awesome_rounded,
            label: 'Smart Match',
            highlighted: true,
          ),
          ServioBottomNavItem(icon: Icons.calendar_month_rounded, label: 'Bookings'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 1,
        onTap: (int index) {
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AiSmartMatchScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerProfileScreen(),
              ),
            );
          }
        },
      ),
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
                              builder: (_) => const SearchResultsScreen(query: 'plumbing'),
                            ),
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search services',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: servio.surfaceAlt,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                            borderSide: BorderSide(color: servio.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                            borderSide: BorderSide(color: servio.accent, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                        boxShadow: ServioShadows.rest,
                      ),
                      child: Icon(Icons.tune_rounded, color: servio.accent),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 62,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final active = index == _selectedCategory;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? servio.accent : servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
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
                      'Sort: Rating',
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    _ToggleIcon(
                      icon: Icons.view_agenda_outlined,
                      active: !_gridMode,
                      onTap: () => setState(() => _gridMode = false),
                    ),
                    const SizedBox(width: 8),
                    _ToggleIcon(
                      icon: Icons.grid_view_rounded,
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
                          style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _MarketplaceServiceCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServiceDetailScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: 4,
                ),
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
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? servio.backgroundSoft : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(color: servio.border),
        ),
        child: Icon(icon, size: 20, color: active ? servio.accent : servio.textSecondary),
      ),
    );
  }
}

class _MarketplaceServiceCard extends StatelessWidget {
  const _MarketplaceServiceCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: ServioCard(
        radius: ServioRadius.lg,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: ServioGradients.brand,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ServioRadius.lg),
                ),
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    Icons.plumbing_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.sm),
                    ),
                    child: Text(
                      'PLUMBING',
                      style: theme.textTheme.labelSmall?.copyWith(color: servio.accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Plumbing Repair Visit', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Leak checks, faucet repairs, pressure issues, and fast maintenance support.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '850 EGP - 1,200 EGP / session',
                          style: theme.textTheme.titleMedium?.copyWith(color: servio.accent),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: onTap,
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '4.9 rating  •  328 reviews  •  2-2.5 Hours',
                    style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
