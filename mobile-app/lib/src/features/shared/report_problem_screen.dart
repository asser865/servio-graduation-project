import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage =
            'Please complete the required fields before submitting.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _successMessage =
          'Report submitted. Our team will investigate and follow up if needed.';
      _selectedCategory = null;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    _ReportFormCard(
                      formKey: _formKey,
                      descriptionController: _descriptionController,
                      selectedCategory: _selectedCategory,
                      isSubmitting: _isSubmitting,
                      successMessage: _successMessage,
                      errorMessage: _errorMessage,
                      onCategoryChanged: (val) =>
                          setState(() => _selectedCategory = val),
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 24),
                    const _ReportHero(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _ReportHero extends StatelessWidget {
  const _ReportHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 38),
      color: servio.warning,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          PositionedDirectional(
            top: -52,
            start: -42,
            child: _SoftDisc(
                size: 142, color: Colors.white.withValues(alpha: 0.08)),
          ),
          PositionedDirectional(
            bottom: -58,
            end: -46,
            child: _SoftDisc(
                size: 160, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.flag_outlined,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Report an issue',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Report a Problem',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Found a bug or experiencing an issue? Let us know so we can fix it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftDisc extends StatelessWidget {
  const _SoftDisc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _ReportFormCard extends StatelessWidget {
  const _ReportFormCard({
    required this.formKey,
    required this.descriptionController,
    required this.selectedCategory,
    required this.isSubmitting,
    required this.onCategoryChanged,
    required this.onSubmit,
    this.successMessage,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final bool isSubmitting;
  final String? successMessage;
  final String? errorMessage;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onSubmit;

  static const List<String> _categories = <String>[
    'Bug / App Crash',
    'Wrong Information',
    'Payment Issue',
    'Account Problem',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.warning),
                    borderRadius: BorderRadius.circular(ServioRadius.sm),
                    border: Border.all(
                        color: servio.warning.withValues(alpha: 0.22)),
                  ),
                  child: Icon(Icons.flag_outlined, color: servio.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Submit a report',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Tell us what went wrong and we'll look into it.",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Problem Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                  .toList(),
              onChanged: onCategoryChanged,
              validator: (val) =>
                  val == null ? 'Please select a category.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: descriptionController,
              minLines: 4,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue in detail…',
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Description is required.';
                }
                if (val.trim().length < 20) {
                  return 'Please provide at least 20 characters.';
                }
                return null;
              },
            ),
            if (successMessage != null || errorMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              _InlineMessage(
                message: successMessage ?? errorMessage!,
                color: successMessage != null ? servio.success : servio.danger,
                icon: successMessage != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: 18),
            ServioPrimaryButton(
              label: 'Submit Report',
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline message banner ────────────────────────────────────────────────────

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
