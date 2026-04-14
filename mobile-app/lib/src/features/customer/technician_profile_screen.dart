import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../booking/booking_step_one_screen.dart';
import '../messages/chat_screen.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  final Set<int> _expandedSections = <int>{0, 1, 2, 5, 6};

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        _expandedSections.remove(index);
      } else {
        _expandedSections.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(start: 72, bottom: 16),
                  title: Text('Ahmed Nabil', style: theme.textTheme.titleMedium),
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(decoration: const BoxDecoration(gradient: ServioGradients.brand)),
                      Positioned(
                        right: 20,
                        top: 80,
                        child: Icon(
                          Icons.handyman_rounded,
                          size: 110,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 16,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: ServioGradients.warm,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: ServioShadows.rest,
                          ),
                          child: Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: servio.accent, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  'AN',
                                  style: theme.textTheme.titleMedium?.copyWith(color: ServioColors.deepBrown),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      Text(
                        'Plumbing Specialist',
                        style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: const <Widget>[
                          Expanded(child: _StatTile(value: '4.9', label: 'Rating')),
                          Expanded(child: _StatTile(value: '328', label: 'Jobs')),
                          Expanded(child: _StatTile(value: '<2h', label: 'Response')),
                          Expanded(child: _StatTile(value: '350', label: 'EGP/hr')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _AccordionSection(
                        title: 'Professional Summary',
                        expanded: _expandedSections.contains(0),
                        onTap: () => _toggleSection(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Verified technician with residential maintenance experience, transparent estimates, and consistent customer ratings.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: const <Widget>[
                                _MiniChip(label: 'EN'),
                                _MiniChip(label: 'AR'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: 'Services Offered',
                        expanded: _expandedSections.contains(1),
                        onTap: () => _toggleSection(1),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: const <Widget>[
                            _ServiceOfferCard(label: 'Leak Repair', meta: '250 EGP - 1h'),
                            _ServiceOfferCard(label: 'Faucet Install', meta: '300 EGP - 1.5h'),
                            _ServiceOfferCard(label: 'Pipe Check', meta: '200 EGP - 45m'),
                            _ServiceOfferCard(label: 'Pressure Fix', meta: '350 EGP - 2h'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: 'Portfolio',
                        expanded: _expandedSections.contains(2),
                        onTap: () => _toggleSection(2),
                        child: SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 3,
                            separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 12),
                            itemBuilder: (BuildContext context, int index) {
                              return Container(
                                width: 180,
                                decoration: BoxDecoration(
                                  gradient: index.isEven ? ServioGradients.brand : ServioGradients.warm,
                                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: ServioGradients.brand,
                                      borderRadius: BorderRadius.circular(ServioRadius.full),
                                    ),
                                    child: Text(
                                      '${1200 + (index * 350)} EGP',
                                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: 'Reviews',
                        expanded: _expandedSections.contains(3),
                        onTap: () => _toggleSection(3),
                        child: const Column(
                          children: <Widget>[
                            _MiniReviewCard(name: 'Nour Hany', body: 'Professional and very clear on pricing.'),
                            SizedBox(height: 10),
                            _MiniReviewCard(name: 'Karim Adel', body: 'Fast response and neat work.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: 'Service Coverage',
                        expanded: _expandedSections.contains(4),
                        onTap: () => _toggleSection(4),
                        child: const _CoverageCard(),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: 'Verified Credentials',
                        expanded: _expandedSections.contains(5),
                        onTap: () => _toggleSection(5),
                        child: const Column(
                          children: <Widget>[
                            _CredentialRow(label: 'License', status: 'Verified'),
                            SizedBox(height: 10),
                            _CredentialRow(label: 'Insurance', status: 'Verified'),
                            SizedBox(height: 10),
                            _CredentialRow(label: 'Background Check', status: 'Pending'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: 'Availability',
                        expanded: _expandedSections.contains(6),
                        onTap: () => _toggleSection(6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const <Widget>[
                            _AvailabilityPill(day: 'Mon', available: true),
                            _AvailabilityPill(day: 'Tue', available: true),
                            _AvailabilityPill(day: 'Wed', available: true),
                            _AvailabilityPill(day: 'Thu', available: false),
                            _AvailabilityPill(day: 'Fri', available: true),
                            _AvailabilityPill(day: 'Sat', available: false),
                            _AvailabilityPill(day: 'Sun', available: true),
                          ],
                        ),
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
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: ServioColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ServioPrimaryButton(
                        label: 'Book Now',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BookingStepOneScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChatScreen(contactName: 'Ahmed Nabil'),
                            ),
                          );
                        },
                        child: const Text('Message'),
                      ),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: servio.accent),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.title,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onTap,
            child: Row(
              children: <Widget>[
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: ServioMotion.micro,
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: servio.accent),
      ),
    );
  }
}

class _ServiceOfferCard extends StatelessWidget {
  const _ServiceOfferCard({required this.label, required this.meta});

  final String label;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.build_circle_outlined, color: servio.accent),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            meta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiniReviewCard extends StatelessWidget {
  const _MiniReviewCard({required this.name, required this.body});

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard();

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: ServioGradients.warm,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
      ),
      child: Center(
        child: Text(
          'Cairo - Giza - New Cairo',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: servio.accent),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final isPending = status == 'Pending';

    return Row(
      children: <Widget>[
        Icon(
          isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
          color: isPending ? servio.warning : servio.success,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          status,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isPending ? servio.warning : servio.success,
              ),
        ),
      ],
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.day, required this.available});

  final String day;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: available ? servio.success : servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        day,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: available ? Colors.white : servio.textSecondary,
            ),
      ),
    );
  }
}
