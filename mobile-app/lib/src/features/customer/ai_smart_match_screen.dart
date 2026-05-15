import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/ai_api.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'services_marketplace_screen.dart';
import 'technician_profile_screen.dart';

class AiSmartMatchScreen extends StatefulWidget {
  const AiSmartMatchScreen({super.key});

  @override
  State<AiSmartMatchScreen> createState() => _AiSmartMatchScreenState();
}

class _AiSmartMatchScreenState extends State<AiSmartMatchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  bool _showResults = false;
  bool _loading = false;
  String? _error;
  AiRecommendationResponse? _recommendation;

  static const List<String> _suggestions = <String>[
    'Leaky Faucet',
    'AC Not Cooling',
    'Power Outage',
    'Wall Painting',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _applySuggestion(String text) {
    setState(() {
      _controller.text = text;
      _showResults = false;
    });
  }

  Future<void> _analyze() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final budgetText = _budgetController.text.trim();
    final budget = budgetText.isEmpty ? null : num.tryParse(budgetText);
    if (budgetText.isNotEmpty && budget == null) {
      setState(() => _error = 'Budget must be a number.');
      return;
    }
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
        budget: budget,
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
    final servio = context.servio;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding + bottomInset,
          ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        'POWERED BY SERVIO AI',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: ServioColors.neutralWarm),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'What seems to be the',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'problem?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(color: ServioColors.accentLight),
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
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final suggestion = _suggestions[index];
                    return GestureDetector(
                      onTap: () => _applySuggestion(suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Text(
                          suggestion,
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ServioPrimaryButton(
                label: _loading ? 'Analyzing…' : 'Analyze Request',
                onPressed: _loading ? null : _analyze,
                isLoading: _loading,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_showResults && _recommendation != null) ...<Widget>[
                const SizedBox(height: 32),
                Text('Recommended Service',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 14),
                ServioCard(
                  radius: ServioRadius.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ServioStatusChip(
                            label: _recommendation!.predictedCategory.isEmpty
                                ? 'Recommended'
                                : _recommendation!.predictedCategory,
                          ),
                          const SizedBox(width: 10),
                          ServioStatusChip(
                            label: _recommendation!.confidenceLabel,
                            type: ServioStatusChipType.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _recommendation!.serviceName.isEmpty
                            ? 'Recommended service match'
                            : _recommendation!.serviceName,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (_recommendation!.priceRange.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          _recommendation!.priceRange,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: servio.accent),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Top Matched Technicians',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_recommendation!.recommendedWorkers.isEmpty)
                  Text(
                    'No technician matches returned yet. Browse similar services to choose one.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: servio.textSecondary),
                  )
                else
                  ..._recommendation!.recommendedWorkers.map(
                    (worker) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MatchedTechnicianCard(
                        name: worker.name.isEmpty ? 'Technician' : worker.name,
                        match: worker.matchLabel,
                        reason: worker.reason.isEmpty
                            ? 'Recommended by SERVIO AI for this request.'
                            : worker.reason,
                        onTap: () {
                          final recommendation = _recommendation!;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TechnicianProfileScreen(
                                technicianId:
                                    worker.id.isEmpty ? null : worker.id,
                                selectedServiceCategory:
                                    recommendation.predictedCategory.isEmpty
                                        ? null
                                        : recommendation.predictedCategory,
                                selectedServiceName:
                                    recommendation.serviceName.isEmpty
                                        ? null
                                        : recommendation.serviceName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                ServioPrimaryButton(
                  label: 'Browse Matching Services',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ServicesMarketplaceScreen(),
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
                      Expanded(
                          child: Text(name,
                              style: Theme.of(context).textTheme.titleMedium)),
                      ServioStatusChip(
                        label: match,
                        type: ServioStatusChipType.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: servio.textSecondary),
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
