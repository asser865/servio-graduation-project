import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/ai_api.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../shared/search_results_screen.dart';
import 'technician_profile_screen.dart';

class AiSmartMatchScreen extends StatefulWidget {
  const AiSmartMatchScreen({super.key});

  @override
  State<AiSmartMatchScreen> createState() => _AiSmartMatchScreenState();
}

class _AiSmartMatchScreenState extends State<AiSmartMatchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _showResults = false;
  bool _loading = false;
  String? _error;
  AiRecommendationResponse? _recommendation;

  @override
  void dispose() {
    _controller.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _serviceCategory(String service) {
    const map = <String, String>{
      'Plumbing': 'plumbing',
      'Electrical': 'electrical',
      'A/C': 'hvac',
      'Carpentry': 'carpentry',
      'Cleaning': 'cleaning',
      'Painting': 'painting',
      'Appliance Repair': 'appliance',
      'Handyman': 'handyman',
    };
    return map[service] ?? service.toLowerCase();
  }

  Future<void> _analyze() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _showResults = false;
      _error = null;
    });
    try {
      final client = context.read<ApiClient>();
      final recommendation = await AiApi(client).recommend(
        description: query,
        location: _locationController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _recommendation = recommendation;
        _showResults = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'AI service unavailable. Try again later.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xCCF3EDE7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _GlassCircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Text(
          'Smart Match',
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF1A1D23),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          0,
          0,
          0,
          ServioSpacing.screenPadding + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Hero
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  ServioSpacing.screenPadding, 24, ServioSpacing.screenPadding, 0),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.brand,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: ServioShadows.elevated,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Smart matching for\nreal home issues',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF1A1D23),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Glass composer
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: _GlassComposer(
                controller: _controller,
              ),
            ),
            const SizedBox(height: 20),
            // Inputs + CTA
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: _InputsSection(
                locationController: _locationController,
                loading: _loading,
                onFind: _analyze,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ServioSpacing.screenPadding),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (_showResults && _recommendation != null) ...<Widget>[
              const SizedBox(height: 32),
              // Diagnostic results
              if (_recommendation!.isMulti &&
                  _recommendation!.steps.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ServioSpacing.screenPadding),
                  child: _DiagnosticResults(steps: _recommendation!.steps),
                ),
                const SizedBox(height: 28),
              ],
              // Matched technicians carousel
              _TechnicianCarousel(
                recommendation: _recommendation!,
                serviceCategory: _serviceCategory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.40),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, color: const Color(0xFF1A1D23), size: 20),
          ),
        ),
      ),
    );
  }
}

class _GlassComposer extends StatelessWidget {
  const _GlassComposer({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(ServioRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EDE7).withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(ServioRadius.xl),
            border: Border.all(
                color: ServioColors.accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: <Widget>[
              TextField(
                controller: controller,
                maxLines: 5,
                minLines: 4,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF262B34)),
                decoration: InputDecoration(
                  hintText:
                      'e.g., My kitchen faucet is dripping constantly...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: ServioColors.textSecondaryLight.withValues(alpha: 0.60),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputsSection extends StatelessWidget {
  const _InputsSection({
    required this.locationController,
    required this.loading,
    required this.onFind,
  });

  final TextEditingController locationController;
  final bool loading;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Location
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Service Location',
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF1A1D23),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: ServioColors.accent,
                  size: 20,
                ),
                hintText: 'Enter your area',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                  borderSide: BorderSide(
                      color: ServioColors.accent.withValues(alpha: 0.30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                  borderSide: BorderSide(
                      color: ServioColors.accent.withValues(alpha: 0.30)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                  borderSide: const BorderSide(
                      color: Color(0xFF1A1D23), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Find Matches CTA
        GestureDetector(
          onTap: loading ? null : onFind,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: loading ? null : ServioGradients.brand,
              color: loading ? ServioColors.navySoft : null,
              borderRadius: BorderRadius.circular(ServioRadius.xl),
              boxShadow: loading ? null : ServioShadows.elevated,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  loading ? 'Analyzing Issue...' : 'Find Matches',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  loading ? Icons.hourglass_empty_rounded : Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticResults extends StatelessWidget {
  const _DiagnosticResults({required this.steps});

  final List<ServiceStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Diagnostic AI Results',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1A1D23),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Auto-generated',
              style: theme.textTheme.labelSmall?.copyWith(
                color: ServioColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: steps.length,
          itemBuilder: (BuildContext context, int index) {
            return _StepCard(step: steps[index], index: index);
          },
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index});

  final ServiceStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrgent = step.urgency == 'urgent';
    final badgeColor =
        isUrgent ? const Color(0xFF137333) : const Color(0xFF1967D2);
    final badgeBg =
        isUrgent ? const Color(0xFFE6F4EA) : const Color(0xFFE8F0FE);
    final badgeLabel = isUrgent ? 'URGENT' : 'FLEXIBLE';
    final badgeIcon =
        isUrgent ? Icons.check_circle_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(
            color: ServioColors.accent.withValues(alpha: 0.20)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  badgeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(badgeIcon, color: badgeColor, size: 18),
            ],
          ),
          const Spacer(),
          Text(
            'Step ${index + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: ServioColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            step.service,
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFF1A1D23),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TechnicianCarousel extends StatelessWidget {
  const _TechnicianCarousel({
    required this.recommendation,
    required this.serviceCategory,
  });

  final AiRecommendationResponse recommendation;
  final String Function(String) serviceCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workers = recommendation.recommendedWorkers;
    final catKey = recommendation.isMulti && recommendation.steps.isNotEmpty
        ? serviceCategory(recommendation.steps.first.service)
        : recommendation.predictedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ServioSpacing.screenPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Top Matched Technicians',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1A1D23),
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SearchResultsScreen(query: ''),
                  ),
                ),
                child: Text(
                  'SEE ALL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ServioColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (workers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding),
            child: Text(
              'No matches found. Try describing your issue in more detail.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
              ),
            ),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              itemCount: workers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (BuildContext context, int index) {
                final worker = workers[index];
                return _TechnicianCard(
                  worker: worker,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TechnicianProfileScreen(
                        technicianId:
                            worker.id.isEmpty ? null : worker.id,
                        selectedServiceCategory:
                            catKey.isEmpty ? null : catKey,
                        selectedServiceName:
                            recommendation.serviceName.isEmpty
                                ? null
                                : recommendation.serviceName,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.worker,
    required this.onTap,
  });

  final RecommendedWorker worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final hasImage =
        worker.profileImage != null && worker.profileImage!.isNotEmpty;
    final initial =
        worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(
            color: ServioColors.accent.withValues(alpha: 0.10)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Avatar + name + rating
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(ServioRadius.md),
                child: hasImage
                    ? Image.network(
                        worker.profileImage!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _InitialsBox(initial: initial),
                      )
                    : _InitialsBox(initial: initial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      worker.name.isEmpty ? 'Professional' : worker.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF1A1D23),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFB400),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          worker.averageRating != null
                              ? worker.averageRating!.toStringAsFixed(1)
                              : worker.matchLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF1A1D23),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (worker.totalReviews != null) ...<Widget>[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(${worker.totalReviews}+ reviews)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: servio.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              if (worker.categories.isNotEmpty)
                _TagChip(
                    label: worker.categories.first.toUpperCase()),
              if (worker.locationLabel != null &&
                  worker.locationLabel!.isNotEmpty)
                _TagChip(label: worker.locationLabel!.toUpperCase()),
            ],
          ),
          const Spacer(),
          // Book Now button (outlined)
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A1D23),
                side: const BorderSide(
                    color: Color(0xFF1A1D23), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.lg),
                ),
              ),
              child: const Text('Book Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEEB),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: ServioColors.textSecondaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _InitialsBox extends StatelessWidget {
  const _InitialsBox({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(gradient: ServioGradients.warm),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF1A1D23),
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
