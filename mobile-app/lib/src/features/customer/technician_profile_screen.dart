import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/reviews_api.dart';
import '../../core/api/users_api.dart';
import '../../core/models/backend_worker_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../booking/booking_flow_data.dart';
import '../booking/booking_step_one_screen.dart';
import '../messages/chat_screen.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({this.technicianId, super.key});

  final String? technicianId;

  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  final Set<int> _expandedSections = <int>{0, 1, 2, 5, 6};

  BackendWorker? _worker;
  List<ReviewResult> _reviews = <ReviewResult>[];
  bool _loading = true;
  String? _error;

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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.technicianId == null) {
      setState(() => _loading = false);
      return;
    }
    final workersProvider = context.read<WorkersProvider>();
    final client = context.read<ApiClient>();
    try {
      final cached = workersProvider.findById(widget.technicianId!);
      if (cached != null) {
        setState(() => _worker = cached);
      } else {
        final worker = await UsersApi(client).getWorkerById(widget.technicianId!);
        if (mounted) setState(() => _worker = worker);
      }
      if (!mounted) return;
      final reviews = await ReviewsApi(client).getWorkerReviews(widget.technicianId!);
      if (mounted) setState(() => _reviews = reviews);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load technician profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _worker == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Technician not found.')));
    }

    final worker = _worker!;
    final techName = worker.name;

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
                  title: Text(techName, style: theme.textTheme.titleMedium),
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
                                  worker.initials,
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
                        worker.skills.join(', '),
                        style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _StatTile(
                              value: worker.rating.toStringAsFixed(1),
                              label: locale == 'ar' ? 'التقييم' : 'Rating',
                            ),
                          ),
                          Expanded(
                            child: _StatTile(
                              value: '${worker.reviewCount}',
                              label: locale == 'ar' ? 'تقييم' : 'Reviews',
                            ),
                          ),
                          Expanded(
                            child: _StatTile(
                              value: worker.availabilityType,
                              label: locale == 'ar' ? 'استجابة' : 'Response',
                            ),
                          ),
                          Expanded(
                            child: _StatTile(
                              value: '${worker.hourlyRate}',
                              label: locale == 'ar' ? 'جنيه/ساعة' : 'EGP/hr',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _AccordionSection(
                        title: locale == 'ar' ? 'الملف المهني' : 'Professional Summary',
                        expanded: _expandedSections.contains(0),
                        onTap: () => _toggleSection(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              worker.skills.join(' · '),
                              style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                _MiniChip(label: locale == 'ar' ? 'عربي' : 'AR'),
                                _MiniChip(label: locale == 'ar' ? 'إنجليزي' : 'EN'),
                                if (worker.isVerified)
                                  _MiniChip(label: locale == 'ar' ? 'موثّق' : 'Verified'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: locale == 'ar' ? 'الخدمات المقدمة' : 'Services Offered',
                        expanded: _expandedSections.contains(1),
                        onTap: () => _toggleSection(1),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: worker.skills.map((String s) => _MiniChip(label: s)).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: locale == 'ar' ? 'معرض الأعمال' : 'Portfolio',
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
                        title: locale == 'ar' ? 'آراء العملاء' : 'Reviews',
                        expanded: _expandedSections.contains(3),
                        onTap: () => _toggleSection(3),
                        child: _reviews.isEmpty
                            ? Text('No reviews yet.', style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary))
                            : Column(
                                children: _reviews.take(3).map((ReviewResult r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MiniReviewCard(name: r.reviewerName, body: r.comment),
                                )).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: locale == 'ar' ? 'نطاق الخدمة' : 'Service Coverage',
                        expanded: _expandedSections.contains(4),
                        onTap: () => _toggleSection(4),
                        child: _CoverageCard(area: worker.locationLabel),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: locale == 'ar' ? 'الاعتمادات' : 'Verified Credentials',
                        expanded: _expandedSections.contains(5),
                        onTap: () => _toggleSection(5),
                        child: Column(
                          children: <Widget>[
                            _CredentialRow(
                              label: locale == 'ar' ? 'الرخصة المهنية' : 'License',
                              status: locale == 'ar' ? 'موثّق' : 'Verified',
                              pending: false,
                            ),
                            const SizedBox(height: 10),
                            _CredentialRow(
                              label: locale == 'ar' ? 'التأمين' : 'Insurance',
                              status: locale == 'ar' ? 'موثّق' : 'Verified',
                              pending: false,
                            ),
                            const SizedBox(height: 10),
                            _CredentialRow(
                              label: locale == 'ar' ? 'فحص الخلفية' : 'Background Check',
                              status: locale == 'ar' ? 'قيد المراجعة' : 'Pending',
                              pending: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccordionSection(
                        title: locale == 'ar' ? 'التوفر' : 'Availability',
                        expanded: _expandedSections.contains(6),
                        onTap: () => _toggleSection(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              worker.availabilityType,
                              style: theme.textTheme.bodyMedium?.copyWith(color: servio.success),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _AvailabilityPill(day: locale == 'ar' ? 'إث' : 'Mon', available: true),
                                _AvailabilityPill(day: locale == 'ar' ? 'ثل' : 'Tue', available: true),
                                _AvailabilityPill(day: locale == 'ar' ? 'أر' : 'Wed', available: true),
                                _AvailabilityPill(day: locale == 'ar' ? 'خم' : 'Thu', available: false),
                                _AvailabilityPill(day: locale == 'ar' ? 'جم' : 'Fri', available: true),
                                _AvailabilityPill(day: locale == 'ar' ? 'سب' : 'Sat', available: false),
                                _AvailabilityPill(day: locale == 'ar' ? 'أح' : 'Sun', available: true),
                              ],
                            ),
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
                        label: locale == 'ar' ? 'احجز الآن' : 'Book Now',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BookingStepOneScreen(
                                data: BookingFlowData(
                                  technicianName: worker.name,
                                  technicianId: worker.id,
                                  specialty: worker.skills.isNotEmpty ? worker.skills.first : '',
                                ),
                              ),
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
                              builder: (_) => ChatScreen(contactName: techName),
                            ),
                          );
                        },
                        child: Text(locale == 'ar' ? 'مراسلة' : 'Message'),
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
  const _CoverageCard({required this.area});

  final String area;

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
          area,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: servio.accent),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.status,
    required this.pending,
  });

  final String label;
  final String status;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Row(
      children: <Widget>[
        Icon(
          pending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
          color: pending ? servio.warning : servio.success,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          status,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: pending ? servio.warning : servio.success,
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
