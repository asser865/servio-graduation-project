import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/ai_smart_match_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.query = 'plumbing',
  });

  final String query;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: TextField(
            controller: TextEditingController(text: widget.query),
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: servio.surfaceAlt,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.full),
                borderSide: BorderSide(color: servio.border),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Row(
                children: List<Widget>.generate(2, (int index) {
                  final active = index == _tabIndex;
                  final labels = <String>['Services', 'Technicians'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = index),
                      child: AnimatedContainer(
                        duration: ServioMotion.micro,
                        curve: ServioMotion.curve,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: active ? Theme.of(context).colorScheme.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Text(
                          labels[index],
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const <Widget>[
                _FilterChip(label: 'All'),
                _FilterChip(label: 'Plumbing'),
                _FilterChip(label: 'Rating 4+'),
                _FilterChip(label: 'Verified'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _tabIndex == 0 ? const _SearchEmptyState() : const _SearchEmptyState(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: servio.textSecondary),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: ServioGradients.warm,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(Icons.travel_explore_rounded, size: 60, color: servio.accent),
          ),
          const SizedBox(height: 20),
          Text('No results found', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            'Try different keywords or use Smart Match.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
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
    );
  }
}
