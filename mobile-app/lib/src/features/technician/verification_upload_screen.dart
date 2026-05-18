import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

enum VerificationDocumentStatus {
  pending,
  uploaded,
  underReview,
  verified,
  rejected,
}

class VerificationUploadController extends ChangeNotifier {
  final Map<String, String> _files = <String, String>{};
  final Map<String, String> _errors = <String, String>{};
  final List<String> _portfolio = <String>[];

  String? fileName(String id) => _files[id];
  String? errorFor(String id) => _errors[id];
  List<String> get portfolio => List<String>.unmodifiable(_portfolio);

  bool get requiredComplete =>
      _files['idFront'] != null &&
      _files['idBack'] != null &&
      _files['selfie'] != null;

  void upload(String id, String fileName) {
    _files[id] = fileName;
    _errors.remove(id);
    notifyListeners();
  }

  void remove(String id) {
    _files.remove(id);
    notifyListeners();
  }

  void addPortfolioPhoto() {
    if (_portfolio.length >= 5) return;
    _portfolio.add('portfolio_${_portfolio.length + 1}.jpg');
    notifyListeners();
  }

  void removePortfolioPhoto(int index) {
    if (index < 0 || index >= _portfolio.length) return;
    _portfolio.removeAt(index);
    notifyListeners();
  }

  bool validate() {
    _errors
      ..clear()
      ..addAll(<String, String>{
        if (_files['idFront'] == null)
          'idFront': 'National ID front is required.',
        if (_files['idBack'] == null) 'idBack': 'National ID back is required.',
        if (_files['selfie'] == null)
          'selfie': 'Selfie holding ID is required.',
      });
    notifyListeners();
    return _errors.isEmpty;
  }
}

class VerificationUploadScreen extends StatefulWidget {
  const VerificationUploadScreen({super.key});

  @override
  State<VerificationUploadScreen> createState() =>
      _VerificationUploadScreenState();
}

class _VerificationUploadScreenState extends State<VerificationUploadScreen> {
  late final VerificationUploadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VerificationUploadController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Documents'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: VerificationUploadStep(
            controller: _controller,
            stepLabel: 'Step 7 of 8',
            progress: 7 / 8,
            showActions: true,
            onBack: () => Navigator.of(context).maybePop(),
            onSubmit: () {
              if (!_controller.validate()) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Documents submitted for review.')),
              );
            },
          ),
        ),
      ),
    );
  }
}

class VerificationUploadStep extends StatefulWidget {
  const VerificationUploadStep({
    required this.controller,
    super.key,
    this.stepLabel = 'Verify your identity',
    this.progress = 1,
    this.showActions = false,
    this.onBack,
    this.onSubmit,
  });

  final VerificationUploadController controller;
  final String stepLabel;
  final double progress;
  final bool showActions;
  final VoidCallback? onBack;
  final VoidCallback? onSubmit;

  @override
  State<VerificationUploadStep> createState() => _VerificationUploadStepState();
}

class _VerificationUploadStepState extends State<VerificationUploadStep> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant VerificationUploadStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _upload(String id, String label) {
    widget.controller.upload(
      id,
      '${label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.jpg',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final controller = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.stepLabel,
          style:
              theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: widget.progress.clamp(0, 1),
            backgroundColor: servio.backgroundSoft,
            valueColor:
                const AlwaysStoppedAnimation<Color>(ServioColors.accent),
          ),
        ),
        const SizedBox(height: 24),
        Text('Verify your identity', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Upload the required documents so our team can review your technician application.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: servio.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _TrustStrip(),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: VerificationUploadCard(
                title: 'National ID - Front',
                requiredLabel: true,
                fileName: controller.fileName('idFront'),
                errorText: controller.errorFor('idFront'),
                onTap: () => _upload('idFront', 'National ID Front'),
                onRemove: () => controller.remove('idFront'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: VerificationUploadCard(
                title: 'National ID - Back',
                requiredLabel: true,
                fileName: controller.fileName('idBack'),
                errorText: controller.errorFor('idBack'),
                onTap: () => _upload('idBack', 'National ID Back'),
                onRemove: () => controller.remove('idBack'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        VerificationUploadCard(
          title: 'Selfie holding ID',
          requiredLabel: true,
          fileName: controller.fileName('selfie'),
          errorText: controller.errorFor('selfie'),
          onTap: () => _upload('selfie', 'Selfie Holding ID'),
          onRemove: () => controller.remove('selfie'),
        ),
        const SizedBox(height: 14),
        VerificationUploadCard(
          title: 'Trade Certificate / Licence',
          fileName: controller.fileName('tradeLicence'),
          onTap: () => _upload('tradeLicence', 'Trade Licence'),
          onRemove: () => controller.remove('tradeLicence'),
        ),
        const SizedBox(height: 14),
        _PortfolioUpload(controller: controller),
        if (widget.showActions) ...<Widget>[
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ServioPrimaryButton(
                  label: 'Submit Application',
                  onPressed:
                      controller.requiredComplete ? widget.onSubmit : null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class VerificationUploadCard extends StatelessWidget {
  const VerificationUploadCard({
    required this.title,
    required this.onTap,
    required this.onRemove,
    super.key,
    this.requiredLabel = false,
    this.fileName,
    this.errorText,
    this.status,
  });

  final String title;
  final bool requiredLabel;
  final String? fileName;
  final String? errorText;
  final VerificationDocumentStatus? status;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final effectiveStatus = status ??
        (fileName == null
            ? VerificationDocumentStatus.pending
            : VerificationDocumentStatus.uploaded);
    final palette = _palette(context, effectiveStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: ServioCard(
            radius: ServioRadius.lg,
            padding: const EdgeInsets.all(12),
            borderColor: palette.color,
            backgroundColor:
                effectiveStatus == VerificationDocumentStatus.pending
                    ? servio.surfaceAlt
                    : Theme.of(context).colorScheme.surface,
            child: SizedBox(
              height: 132,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        requiredLabel ? 'Required' : 'Optional',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: requiredLabel
                              ? servio.accent
                              : servio.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Icon(palette.icon, color: palette.color, size: 34),
                  const SizedBox(height: 10),
                  if (fileName == null)
                    Text(
                      palette.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.color,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ServioColors.tint(palette.color),
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.full),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    fileName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: palette.color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: onRemove,
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: palette.color,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: servio.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  _UploadPalette _palette(
    BuildContext context,
    VerificationDocumentStatus status,
  ) {
    final servio = context.servio;
    return switch (status) {
      VerificationDocumentStatus.pending => _UploadPalette(
          servio.border,
          'Tap to upload',
          Icons.upload_file_outlined,
        ),
      VerificationDocumentStatus.uploaded => _UploadPalette(
          servio.accent,
          'Uploaded',
          Icons.check_circle_outline_rounded,
        ),
      VerificationDocumentStatus.underReview => _UploadPalette(
          servio.warning,
          'Under Review',
          Icons.hourglass_top_rounded,
        ),
      VerificationDocumentStatus.verified => _UploadPalette(
          servio.success,
          'Verified',
          Icons.verified_rounded,
        ),
      VerificationDocumentStatus.rejected => _UploadPalette(
          servio.danger,
          'Rejected - Re-upload',
          Icons.error_outline_rounded,
        ),
    };
  }
}

class _PortfolioUpload extends StatelessWidget {
  const _PortfolioUpload({required this.controller});

  final VerificationUploadController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Portfolio Photos',
                    style: theme.textTheme.titleMedium),
              ),
              Text(
                'Optional',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: servio.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.portfolio.length >= 5
                ? null
                : controller.addPortfolioPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add portfolio photo'),
          ),
          if (controller.portfolio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  List<Widget>.generate(controller.portfolio.length, (index) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: index.isEven
                            ? ServioGradients.brand
                            : ServioGradients.warm,
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_outlined,
                        color: index.isEven
                            ? Colors.white.withValues(alpha: 0.86)
                            : ServioColors.deepBrown,
                      ),
                    ),
                    PositionedDirectional(
                      top: -8,
                      end: -8,
                      child: GestureDetector(
                        onTap: () => controller.removePortfolioPhoto(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: servio.border),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: servio.danger,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.accent),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, color: servio.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your documents are encrypted and reviewed only by our team.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: servio.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPalette {
  const _UploadPalette(this.color, this.label, this.icon);

  final Color color;
  final String label;
  final IconData icon;
}
