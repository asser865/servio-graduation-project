import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';
import 'my_bookings_screen.dart';
import 'service_detail_screen.dart';
import 'services_marketplace_screen.dart';
import 'technician_profile_screen.dart';

class AiSmartMatchScreen extends StatefulWidget {
  const AiSmartMatchScreen({super.key});

  @override
  State<AiSmartMatchScreen> createState() => _AiSmartMatchScreenState();
}

class _AiSmartMatchScreenState extends State<AiSmartMatchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _showResults = false;

  static const List<String> _suggestions = <String>[
    'Leaky Faucet',
    'AC Not Cooling',
    'Power Outage',
    'Wall Painting',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applySuggestion(String text) {
    setState(() {
      _controller.text = text;
      _showResults = false;
    });
  }

  void _analyze() {
    setState(() {
      _showResults = true;
    });
  }

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
        currentIndex: 2,
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerHomeScreen(),
              ),
            );
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServicesMarketplaceScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MyBookingsScreen(),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ServioGradients.brand,
                  borderRadius: BorderRadius.circular(ServioRadius.xl),
                  boxShadow: ServioShadows.rest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        'POWERED BY SERVIO AI',
                        style: theme.textTheme.labelSmall?.copyWith(color: ServioColors.neutralWarm),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'What seems to be the',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'problem?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(color: ServioColors.accentLight),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Describe the issue in your own words.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'e.g., My kitchen faucet is dripping constantly.',
                  alignLabelWithHint: true,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Icon(Icons.mic_none_rounded),
                        SizedBox(width: 8),
                        Icon(Icons.camera_alt_outlined),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final suggestion = _suggestions[index];
                    return GestureDetector(
                      onTap: () => _applySuggestion(suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Text(
                          suggestion,
                          style: theme.textTheme.labelLarge?.copyWith(color: servio.textSecondary),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ServioPrimaryButton(
                label: 'Analyze Request',
                onPressed: _analyze,
              ),
              if (_showResults) ...<Widget>[
                const SizedBox(height: 32),
                Text('Recommended Service', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 14),
                ServioCard(
                  radius: ServioRadius.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: const <Widget>[
                          ServioStatusChip(label: 'Plumbing'),
                          SizedBox(width: 10),
                          ServioStatusChip(
                            label: '94% Match',
                            type: ServioStatusChipType.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Plumbing Repair Visit', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '850 EGP - 1,200 EGP / session',
                        style: theme.textTheme.bodyMedium?.copyWith(color: servio.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Top Matched Technicians', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _MatchedTechnicianCard(
                  name: 'Ahmed Nabil',
                  match: '97%',
                  reason: 'Fast leak diagnostics and strong plumbing review history.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TechnicianProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _MatchedTechnicianCard(
                  name: 'Mariam Adel',
                  match: '91%',
                  reason: 'Available today and highly rated for indoor maintenance calls.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TechnicianProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                ServioPrimaryButton(
                  label: 'Book This Service',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ServiceDetailScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ServicesMarketplaceScreen(),
                      ),
                    );
                  },
                  child: const Text('See All Similar Services'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchedTechnicianCard extends StatelessWidget {
  const _MatchedTechnicianCard({
    required this.name,
    required this.match,
    required this.reason,
    required this.onTap,
  });

  final String name;
  final String match;
  final String reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: ServioCard(
        radius: ServioRadius.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: ServioGradients.warm,
                shape: BoxShape.circle,
                border: Border.all(color: servio.accent, width: 2),
              ),
              child: Center(child: Text(name[0])),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
                      ServioStatusChip(
                        label: match,
                        type: ServioStatusChipType.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
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
