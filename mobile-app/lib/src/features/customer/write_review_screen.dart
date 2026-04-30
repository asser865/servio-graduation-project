import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/reviews_api.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({
    required this.technicianName,
    required this.jobSummary,
    this.bookingId = '',
    super.key,
  });

  final String technicianName;
  final String jobSummary;
  final String bookingId;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 0;
  final Set<String> _selectedTags = <String>{};
  final TextEditingController _controller = TextEditingController();
  int _photoCount = 0;
  bool _loading = false;

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

  bool get _canSubmit => _rating > 0 && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final client = context.read<ApiClient>();
      await ReviewsApi(client).submitReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _controller.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() {
    Navigator.of(context).pop(false);
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
                    child:
                        Center(child: Text(_initials(widget.technicianName))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.technicianName,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          widget.jobSummary,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
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
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Share your experience in detail...',
                alignLabelWithHint: true,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${_controller.text.length}/300',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _controller.text.length >= 300
                      ? servio.danger
                      : servio.textSecondary,
                  fontWeight: _controller.text.length >= 300
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                GestureDetector(
                  onTap: _photoCount >= 3
                      ? null
                      : () => setState(() => _photoCount += 1),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _photoCount >= 3 ? servio.border : servio.accent,
                      ),
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: _photoCount >= 3
                          ? servio.textSecondary
                          : servio.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ...List<Widget>.generate(
                  _photoCount,
                  (int index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: index.isEven
                            ? ServioGradients.brand
                            : ServioGradients.warm,
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => setState(() => _photoCount -= 1),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: servio.danger,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ServioPrimaryButton(
              label: _loading ? 'Submitting…' : 'Submit Review',
              onPressed: (_canSubmit && !_loading) ? _submit : null,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skip,
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
}
