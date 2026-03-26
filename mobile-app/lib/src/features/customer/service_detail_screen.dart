import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'technician_listing_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  int _selectedTab = 0;

  static const List<String> _tabs = <String>['Overview', 'About', 'Reviews'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

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
                              Icons.plumbing_rounded,
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
                                    ServioColors.navyDark.withValues(alpha: 0.6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.sm),
                        ),
                        child: Text(
                          'HOME MAINTENANCE',
                          style: theme.textTheme.labelSmall?.copyWith(color: servio.accent),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Plumbing Repair Visit', style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: ServioGradients.accent,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Text(
                          'AI PRICE ESTIMATE',
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            '850 EGP - 1,200 EGP / session',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: 28,
                              color: servio.accent,
                            ),
                          ),
                          const ServioStatusChip(label: '2-2.5 Hours'),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Row(
                          children: List<Widget>.generate(_tabs.length, (int index) {
                            final active = index == _selectedTab;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = index),
                                child: AnimatedContainer(
                                  duration: ServioMotion.micro,
                                  curve: ServioMotion.curve,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: active ? Theme.of(context).colorScheme.surface : Colors.transparent,
                                    borderRadius: BorderRadius.circular(ServioRadius.full),
                                  ),
                                  child: Text(
                                    _tabs[index],
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: active ? servio.accent : servio.textSecondary,
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
                        child: _buildTabContent(context),
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
                  label: 'Find a Technician',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TechnicianListingScreen(),
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

  Widget _buildTabContent(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    switch (_selectedTab) {
      case 0:
        return Column(
          key: const ValueKey<int>(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'We diagnose leaks, replace damaged connectors, reseal exposed joints, and restore proper water flow with clear pricing before work begins.',
              style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('What\'s included', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _ChecklistItem(label: 'Leak source inspection'),
            const _ChecklistItem(label: 'Minor pipe and faucet adjustments'),
            const _ChecklistItem(label: 'Transparent repair recommendation'),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey<int>(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('About This Service', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Delivered by verified plumbing professionals with documented experience, response-time standards, and customer review history.',
              style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey<int>(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Customer Reviews', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _ReviewBar(label: '5 stars', value: 0.72),
            const SizedBox(height: 8),
            _ReviewBar(label: '4 stars', value: 0.18),
            const SizedBox(height: 8),
            _ReviewBar(label: '3 stars', value: 0.06),
            const SizedBox(height: 20),
            const _ReviewCard(
              name: 'Nour Hany',
              body: 'Quick visit, clear communication, and no surprise charges.',
            ),
            const SizedBox(height: 12),
            const _ReviewCard(
              name: 'Karim Adel',
              body: 'The technician arrived on time and fixed the leak in one session.',
            ),
          ],
        );
    }
  }
}

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
  const _ChecklistItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: servio.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
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
  });

  final String name;
  final String body;

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
          Text(
            '5.0 rating',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}
