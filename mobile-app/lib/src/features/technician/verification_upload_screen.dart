import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class VerificationUploadScreen extends StatelessWidget {
  const VerificationUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Documents'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Step 1 of 3',
              style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(ServioRadius.full),
              child: LinearProgressIndicator(
                value: 1 / 3,
                minHeight: 8,
                backgroundColor: servio.backgroundSoft,
                valueColor: AlwaysStoppedAnimation<Color>(servio.accent),
              ),
            ),
            const SizedBox(height: 24),
            Text('Upload Your National ID', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Row(
              children: const <Widget>[
                Expanded(child: _UploadZone(title: 'Front', state: _UploadState.underReview)),
                SizedBox(width: 12),
                Expanded(child: _UploadZone(title: 'Back', state: _UploadState.verified)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Trade License', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _UploadZone(title: 'Trade License', state: _UploadState.pending),
            const SizedBox(height: 20),
            Text('Insurance Certificate', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _UploadZone(title: 'Insurance', state: _UploadState.rejected),
            const SizedBox(height: 24),
            const ServioPrimaryButton(label: 'Save & Submit'),
          ],
        ),
      ),
    );
  }
}

enum _UploadState { pending, underReview, verified, rejected }

class _UploadZone extends StatelessWidget {
  const _UploadZone({
    required this.title,
    required this.state,
  });

  final String title;
  final _UploadState state;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final palette = switch (state) {
      _UploadState.pending => (servio.border, 'Tap to upload', Icons.upload_file_outlined),
      _UploadState.underReview => (servio.warning, 'Under Review', Icons.hourglass_top_rounded),
      _UploadState.verified => (servio.success, 'Verified', Icons.check_circle_rounded),
      _UploadState.rejected => (servio.danger, 'Rejected - Re-upload', Icons.error_outline_rounded),
    };

    return ServioCard(
      radius: ServioRadius.lg,
      borderColor: palette.$1,
      child: SizedBox(
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(palette.$3, color: palette.$1, size: 36),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              palette.$2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.$1),
            ),
          ],
        ),
      ),
    );
  }
}
