import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/users_api.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import 'verification_upload_screen.dart' show VerificationDocumentStatus;

// ── Document definitions ──────────────────────────────────────────────────────

enum _DocType { image, file, portfolio }

class _DocDef {
  const _DocDef(this.key, this.label, this.hint, this.required, this.type);
  final String key;
  final String label;
  final String hint;
  final bool required;
  final _DocType type;
}

const _kDocs = <_DocDef>[
  _DocDef('idFront', 'National ID — Front',
      'Front side of government-issued photo ID', true, _DocType.image),
  _DocDef('idBack', 'National ID — Back',
      'Back side of government-issued photo ID', true, _DocType.image),
  _DocDef('idSelfie', 'Selfie with ID',
      'Photo of you holding your ID card', true, _DocType.image),
  _DocDef('cvFile', 'CV / Resume',
      'PDF or Word document', false, _DocType.file),
  _DocDef('portfolio', 'Portfolio Photos',
      'Past work samples (up to 5 photos)', false, _DocType.portfolio),
];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _urlFor(UserAccount a, String key) => switch (key) {
      'idFront' => a.idFrontUrl,
      'idBack' => a.idBackUrl,
      'idSelfie' => a.idSelfieUrl,
      'cvFile' => a.cvUrl,
      'portfolio' =>
        a.portfolioFiles.isNotEmpty ? a.portfolioFiles.first['url']! : '',
      _ => '',
    };

String _urlFieldFor(String key) => switch (key) {
      'idFront' => 'idFrontUrl',
      'idBack' => 'idBackUrl',
      'idSelfie' => 'idSelfieUrl',
      'cvFile' => 'cvUrl',
      _ => '',
    };

String _nameFieldFor(String key) => switch (key) {
      'idFront' => 'idFrontName',
      'idBack' => 'idBackName',
      'idSelfie' => 'idSelfieName',
      'cvFile' => 'cvName',
      _ => '',
    };

VerificationDocumentStatus _docStatus(UserAccount acct, String key) {
  final url = _urlFor(acct, key);
  if (url.isEmpty) return VerificationDocumentStatus.pending;
  final s = acct.verificationUiStatus;
  if (s == 'approved') return VerificationDocumentStatus.verified;
  if (s == 'rejected' || s == 'additional_docs_required') {
    return VerificationDocumentStatus.rejected;
  }
  return VerificationDocumentStatus.underReview;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WorkerVerificationScreen extends StatefulWidget {
  const WorkerVerificationScreen({super.key});

  @override
  State<WorkerVerificationScreen> createState() =>
      _WorkerVerificationScreenState();
}

class _WorkerVerificationScreenState extends State<WorkerVerificationScreen> {
  final _picker = ImagePicker();
  final Map<String, bool> _uploading = <String, bool>{};
  bool _refreshing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _loadError = null;
    });
    final err =
        await context.read<SessionProvider>().loadCurrentWorkerProfile();
    if (mounted) {
      setState(() {
        _refreshing = false;
        _loadError = err;
      });
    }
  }

  Future<void> _uploadDoc(_DocDef doc, UserAccount acct) async {
    if (doc.type == _DocType.portfolio) {
      await _uploadPortfolio(acct);
      return;
    }
    final apiClient = context.read<ApiClient>();
    final session = context.read<SessionProvider>();

    List<int> bytes;
    String filename;
    String mime;

    if (doc.type == _DocType.file) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      bytes = picked.bytes!;
      filename = picked.name;
      mime = 'application/octet-stream';
    } else {
      final XFile? file =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null || !mounted) return;
      bytes = await file.readAsBytes();
      filename = file.name;
      mime = file.mimeType ?? 'image/jpeg';
    }

    // 20 MB guard
    if (bytes.length > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is too large. Maximum size is 20 MB.')),
        );
      }
      return;
    }

    setState(() => _uploading[doc.key] = true);
    try {
      final api = UsersApi(apiClient);
      await api.uploadVerificationDocument(
        urlField: _urlFieldFor(doc.key),
        nameField: _nameFieldFor(doc.key),
        bytes: bytes,
        filename: filename,
        mimeType: mime,
      );
      await session.loadCurrentWorkerProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading[doc.key] = false);
    }
  }

  Future<void> _uploadPortfolio(UserAccount acct) async {
    if (acct.portfolioFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 portfolio photos allowed.')),
      );
      return;
    }
    final apiClient = context.read<ApiClient>();
    final session = context.read<SessionProvider>();

    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    setState(() => _uploading['portfolio'] = true);
    try {
      final api = UsersApi(apiClient);
      await api.uploadPortfolioPhoto(
        bytes: bytes,
        filename: file.name,
        existingFiles: acct.portfolioFiles,
        mimeType: mime,
      );
      await session.loadCurrentWorkerProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading['portfolio'] = false);
    }
  }

  Future<void> _removePortfolioPhoto(UserAccount acct, int index) async {
    final updated =
        List<Map<String, String>>.from(acct.portfolioFiles)..removeAt(index);
    final apiClient = context.read<ApiClient>();
    final session = context.read<SessionProvider>();
    setState(() => _uploading['portfolio'] = true);
    try {
      final api = UsersApi(apiClient);
      await api.removePortfolioPhoto(updatedFiles: updated);
      await session.loadCurrentWorkerProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading['portfolio'] = false);
    }
  }

  Future<void> _viewDoc(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(context, account),
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserAccount? account) {
    if (_refreshing && account == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && account == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.wifi_off_rounded,
                  size: 40, color: context.servio.textSecondary),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (account == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final uiStatus = account.verificationUiStatus;

    return ListView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      children: <Widget>[
        _StatusBanner(
          uiStatus: uiStatus,
          rejectionReason: account.verificationRejectionReason,
          submittedAt: account.verificationSubmittedAt,
          reviewedAt: account.verificationReviewedAt,
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'DOCUMENTS'),
        const SizedBox(height: 10),
        ..._kDocs.map((doc) {
          final isPortfolio = doc.type == _DocType.portfolio;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: isPortfolio
                ? _PortfolioDocRow(
                    doc: doc,
                    account: account,
                    uploading: _uploading['portfolio'] ?? false,
                    onUpload: () => _uploadPortfolio(account),
                    onRemove: (i) => _removePortfolioPhoto(account, i),
                    onView: (url) => _viewDoc(url),
                  )
                : _SingleDocRow(
                    doc: doc,
                    status: _docStatus(account, doc.key),
                    url: _urlFor(account, doc.key),
                    uploading: _uploading[doc.key] ?? false,
                    onUpload: () => _uploadDoc(doc, account),
                    onView: () => _viewDoc(_urlFor(account, doc.key)),
                  ),
          );
        }),
        const SizedBox(height: 16),
        _TrustStrip(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.uiStatus,
    required this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final String uiStatus;
  final String rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    final ({
      String label,
      String hint,
      Color color,
      IconData icon,
    }) data = switch (uiStatus) {
      'approved' => (
          label: 'Approved',
          hint: 'Your identity has been verified. You can now receive bookings.',
          color: servio.success,
          icon: Icons.verified_rounded,
        ),
      'rejected' => (
          label: 'Rejected',
          hint: 'Your verification was rejected. Please re-upload your documents.',
          color: servio.danger,
          icon: Icons.cancel_rounded,
        ),
      'additional_docs_required' => (
          label: 'Additional Documents Required',
          hint: 'Please upload the requested additional documents.',
          color: servio.warning,
          icon: Icons.warning_rounded,
        ),
      'under_review' => (
          label: 'Under Review',
          hint: 'Your documents are being verified. This typically takes 1–2 business days.',
          color: servio.info,
          icon: Icons.hourglass_top_rounded,
        ),
      'pending_review' => (
          label: 'Pending Review',
          hint: 'Upload all required documents to complete your verification.',
          color: servio.warning,
          icon: Icons.upload_file_outlined,
        ),
      _ => (
          label: 'Not Submitted',
          hint: 'Upload your identity documents to get verified and start receiving bookings.',
          color: servio.textSecondary,
          icon: Icons.shield_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ServioColors.tint(data.color),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: data.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(data.icon, color: data.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Status: ${data.label}',
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: data.color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.hint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary, height: 1.4),
          ),
          if ((uiStatus == 'rejected' ||
                  uiStatus == 'additional_docs_required') &&
              rejectionReason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Reason: $rejectionReason',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: servio.danger, fontWeight: FontWeight.w600),
            ),
          ],
          if (uiStatus == 'approved' && reviewedAt != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Approved on ${reviewedAt!.day.toString().padLeft(2, '0')}/'
              '${reviewedAt!.month.toString().padLeft(2, '0')}/'
              '${reviewedAt!.year}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: servio.success, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Single document row ───────────────────────────────────────────────────────

class _SingleDocRow extends StatelessWidget {
  const _SingleDocRow({
    required this.doc,
    required this.status,
    required this.url,
    required this.uploading,
    required this.onUpload,
    required this.onView,
  });

  final _DocDef doc;
  final VerificationDocumentStatus status;
  final String url;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final ({Color color, String label, IconData icon}) palette =
        switch (status) {
      VerificationDocumentStatus.verified => (
          color: servio.success,
          label: 'Verified',
          icon: Icons.verified_rounded,
        ),
      VerificationDocumentStatus.underReview => (
          color: servio.info,
          label: 'Under Review',
          icon: Icons.hourglass_top_rounded,
        ),
      VerificationDocumentStatus.rejected => (
          color: servio.danger,
          label: 'Rejected',
          icon: Icons.error_outline_rounded,
        ),
      VerificationDocumentStatus.uploaded => (
          color: servio.accent,
          label: 'Uploaded',
          icon: Icons.check_circle_outline_rounded,
        ),
      _ => (
          color: servio.border,
          label: 'Pending',
          icon: Icons.upload_file_outlined,
        ),
    };

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            doc.label,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: doc.required
                                ? ServioColors.tint(servio.accent)
                                : servio.backgroundSoft,
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Text(
                            doc.required ? 'Required' : 'Optional',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: doc.required
                                  ? servio.accent
                                  : servio.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.hint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ServioColors.tint(palette.color),
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(palette.icon, size: 12, color: palette.color),
                    const SizedBox(width: 4),
                    Text(
                      palette.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (uploading) ...<Widget>[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(ServioRadius.full),
              backgroundColor: servio.backgroundSoft,
              color: servio.accent,
            ),
          ] else ...<Widget>[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (url.isNotEmpty) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: onUpload,
                  icon: Icon(
                    url.isEmpty
                        ? Icons.upload_outlined
                        : Icons.swap_horiz_rounded,
                    size: 14,
                  ),
                  label: Text(url.isEmpty ? 'Upload' : 'Replace'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Portfolio document row ────────────────────────────────────────────────────

class _PortfolioDocRow extends StatelessWidget {
  const _PortfolioDocRow({
    required this.doc,
    required this.account,
    required this.uploading,
    required this.onUpload,
    required this.onRemove,
    required this.onView,
  });

  final _DocDef doc;
  final UserAccount account;
  final bool uploading;
  final VoidCallback onUpload;
  final void Function(int index) onRemove;
  final void Function(String url) onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final photos = account.portfolioFiles;
    final count = photos.length;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          doc.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: servio.backgroundSoft,
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Text(
                            'Optional',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: servio.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.hint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '$count / 5',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: servio.textSecondary),
              ),
            ],
          ),
          if (uploading) ...<Widget>[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(ServioRadius.full),
              backgroundColor: servio.backgroundSoft,
              color: servio.accent,
            ),
          ],
          if (photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(photos.length, (i) {
                final photo = photos[i];
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    GestureDetector(
                      onTap: () => onView(photo['url']!),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: i.isEven
                              ? ServioGradients.brand
                              : ServioGradients.warm,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_outlined,
                          color: i.isEven
                              ? Colors.white.withValues(alpha: 0.8)
                              : ServioColors.deepBrown,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: -6,
                      end: -6,
                      child: GestureDetector(
                        onTap: uploading ? null : () => onRemove(i),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: servio.border),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: servio.danger,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (uploading || count >= 5) ? null : onUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
              label: const Text('Add Photo'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.servio.textSecondary,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ── Trust strip ───────────────────────────────────────────────────────────────

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
