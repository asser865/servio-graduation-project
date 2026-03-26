import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 0;
  final Set<String> _selectedTags = <String>{};
  final TextEditingController _controller = TextEditingController();

  static const List<String> _tags = <String>[
    'Professional',
    'On Time',
    'Great Quality',
    'Clean Work',
    'Friendly',
    'Would Recommend',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Review'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ServioCard(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      shape: BoxShape.circle,
                      border: Border.all(color: servio.accent, width: 2),
                    ),
                    child: const Center(child: Text('AN')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Ahmed Nabil', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Plumbing Repair Visit',
                          style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Rate your experience',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(5, (int index) {
                final filled = index < _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  iconSize: 40,
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? servio.accent : servio.border,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your experience in detail...',
                alignLabelWithHint: true,
                helperText: '${_controller.text.length}/300',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tags.map((String tag) {
                final selected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? servio.accent : servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? Colors.white : servio.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(color: servio.accent, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Icon(Icons.add_rounded, color: servio.accent),
                ),
                const SizedBox(width: 12),
                ...List<Widget>.generate(
                  3,
                  (int index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: index.isEven ? ServioGradients.brand : ServioGradients.warm,
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const ServioPrimaryButton(label: 'Submit Review'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
