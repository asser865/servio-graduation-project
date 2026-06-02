import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/dispute.dart';
import '../../core/state/disputes_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_skeleton.dart';

class TechnicianDisputesScreen extends StatefulWidget {
  const TechnicianDisputesScreen({super.key});

  @override
  State<TechnicianDisputesScreen> createState() =>
      _TechnicianDisputesScreenState();
}

class _TechnicianDisputesScreenState
    extends State<TechnicianDisputesScreen> {
  String _selectedTab = 'open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DisputesProvider>().loadMyDisputes(asWorker: true);
      }
    });
  }

  void _showDetail(Dispute dispute) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
      ),
      builder: (_) => _DisputeDetailSheet(dispute: dispute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Disputes'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Consumer<DisputesProvider>(
        builder: (ctx, provider, _) {
          if (provider.loading && provider.disputes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.disputes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.wifi_off_rounded,
                      size: 40, color: servio.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load disputes.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        provider.loadMyDisputes(asWorker: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Filter duplicates by unique ID
          final seenIds = <String>{};
          final all = <Dispute>[];
          for (final d in provider.disputes) {
            if (d.id.isNotEmpty && !seenIds.contains(d.id)) {
              seenIds.add(d.id);
              all.add(d);
            }
          }

          final open = all.where((d) => d.status == 'open' || d.status == 'reviewing' || d.status == 'escalated').length;
          final awaiting = all.where((d) => d.status == 'awaiting_evidence' || d.status == 'appealed').length;
          final resolved = all
              .where((d) =>
                  d.status.startsWith('resolved') || d.status == 'closed')
              .length;

          // Filter disputes by selected tab
          final filtered = all.where((d) {
            if (_selectedTab == 'open') {
              return d.status == 'open' || d.status == 'reviewing' || d.status == 'escalated';
            } else if (_selectedTab == 'awaiting') {
              return d.status == 'awaiting_evidence' || d.status == 'appealed';
            } else {
              return d.status.startsWith('resolved') || d.status == 'closed';
            }
          }).toList();

          return RefreshIndicator(
            color: servio.accent,
            onRefresh: () => provider.loadMyDisputes(asWorker: true),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _DisputesSummaryGrid(
                      loading: provider.loading && provider.disputes.isEmpty,
                      open: open,
                      awaiting: awaiting,
                      resolved: resolved,
                      selectedTab: _selectedTab,
                      onTabChanged: (String tab) {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.gavel_rounded,
                              size: 48, color: servio.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTab == 'open'
                                ? 'No open disputes.'
                                : _selectedTab == 'awaiting'
                                    ? 'No disputes awaiting evidence.'
                                    : 'No resolved disputes.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DisputeCard(
                            dispute: filtered[i],
                            onTap: () => _showDetail(filtered[i]),
                          ),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}



// ── Dispute Card ──────────────────────────────────────────────────────────────

class _DisputeCard extends StatefulWidget {
  const _DisputeCard({required this.dispute, required this.onTap});
  final Dispute dispute;
  final VoidCallback onTap;

  static Color statusColor(String status, ServioThemeExtension servio) =>
      switch (status) {
        'open' => ServioColors.warning,
        'reviewing' => ServioColors.info,
        'awaiting_evidence' => ServioColors.danger,
        String s when s.startsWith('resolved') => ServioColors.success,
        'appealed' => ServioColors.info,
        'closed' => servio.textSecondary,
        _ => servio.textSecondary,
      };

  static String statusLabel(String status) => switch (status) {
        'open' => 'Open',
        'reviewing' => 'Reviewing',
        'awaiting_evidence' => 'Awaiting Evidence',
        'resolved_refund' => 'Resolved — Refund',
        'resolved_release' => 'Resolved — Released',
        'resolved_partial' => 'Resolved — Partial',
        'resolved_redo' => 'Resolved — Redo',
        'appealed' => 'Appealed',
        'closed' => 'Closed',
        _ => status,
      };

  static Color _severityColor(String s) => switch (s) {
        'low' => ServioColors.success,
        'medium' => ServioColors.warning,
        'high' || 'critical' => ServioColors.danger,
        _ => ServioColors.warning,
      };

  static String categoryLabel(String c) => switch (c) {
        'quality' => 'Quality of Work',
        'pricing' => 'Incorrect Pricing',
        'no_show' => 'No-Show',
        'damage' => 'Property Damage',
        _ => 'Other',
      };

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final sc = _DisputeCard.statusColor(widget.dispute.status, servio);
    final dateStr =
        '${widget.dispute.createdAt.day.toString().padLeft(2, '0')}/'
        '${widget.dispute.createdAt.month.toString().padLeft(2, '0')}/'
        '${widget.dispute.createdAt.year}';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            border: Border.all(
              color: servio.border.withValues(alpha: 0.3),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Status Badge + Severity + Date
              Row(
                children: <Widget>[
                  _Badge(label: _DisputeCard.statusLabel(widget.dispute.status), color: sc),
                  const SizedBox(width: 6),
                  _Badge(
                    label: widget.dispute.severity.toUpperCase(),
                    color: _DisputeCard._severityColor(widget.dispute.severity),
                    fontSize: 9,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: servio.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dispute Category / Title and details
              Text(
                _DisputeCard.categoryLabel(widget.dispute.category),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.dispute.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: servio.textSecondary,
                  height: 1.4,
                ),
              ),

              // Awaiting Evidence Highlight
              if (widget.dispute.status == 'awaiting_evidence') ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ServioColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    border: Border.all(color: ServioColors.danger.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.upload_file_outlined, size: 14, color: ServioColors.danger),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Evidence required — tap to upload',
                          style: TextStyle(
                            color: ServioColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Resolution details
              if (widget.dispute.resolution != null && widget.dispute.resolution!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: servio.success.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    border: Border.all(color: servio.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.check_circle_outline_rounded, size: 15, color: servio.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Resolution Decision',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: servio.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.dispute.resolution!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: servio.success,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.fontSize});
  final String label;
  final Color color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
      ),
    );
  }
}

// ── Dispute Detail Sheet ──────────────────────────────────────────────────────

class _DisputeDetailSheet extends StatefulWidget {
  const _DisputeDetailSheet({required this.dispute});
  final Dispute dispute;

  @override
  State<_DisputeDetailSheet> createState() => _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends State<_DisputeDetailSheet> {
  final _appealCtrl = TextEditingController();
  bool _submittingEvidence = false;
  bool _submittingAppeal = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<DisputesProvider>()
            .loadDisputeDetail(widget.dispute.id);
      }
    });
  }

  @override
  void dispose() {
    _appealCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadEvidence() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (files.isEmpty || !mounted) return;
    final provider = context.read<DisputesProvider>();
    setState(() {
      _submittingEvidence = true;
      _actionError = null;
    });
    try {
      final bytesList = await Future.wait(files.map((f) => f.readAsBytes()));
      final names = files.map((f) => f.name).toList();
      await provider.submitEvidence(
        disputeId: widget.dispute.id,
        description: 'Technician evidence',
        imageBytesList: bytesList,
        filenames: names,
      );
      if (mounted) provider.loadDisputeDetail(widget.dispute.id);
    } catch (e) {
      if (mounted) setState(() => _actionError = 'Upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _submittingEvidence = false);
    }
  }

  Future<void> _submitAppeal() async {
    final reason = _appealCtrl.text.trim();
    if (reason.length < 20) {
      setState(() => _actionError = 'Appeal must be at least 20 characters.');
      return;
    }
    setState(() {
      _submittingAppeal = true;
      _actionError = null;
    });
    try {
      await context.read<DisputesProvider>().appealDispute(
            disputeId: widget.dispute.id,
            reason: reason,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _actionError = 'Appeal failed. Try again.');
    } finally {
      if (mounted) setState(() => _submittingAppeal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Consumer<DisputesProvider>(
      builder: (_, provider, __) {
        final loading = provider.detailLoading;
        final error = provider.detailError;
        final d = provider.detail ?? widget.dispute;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: <Widget>[
              _SheetHandle(servio: servio),
              if (loading && provider.detail == null)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (error != null && provider.detail == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.wifi_off_rounded,
                            size: 36, color: servio.textSecondary),
                        const SizedBox(height: 12),
                        Text('Could not load details.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.textSecondary)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context
                              .read<DisputesProvider>()
                              .loadDisputeDetail(widget.dispute.id),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: _DetailBody(
                    dispute: d,
                    scrollCtrl: scrollCtrl,
                    appealCtrl: _appealCtrl,
                    submittingEvidence: _submittingEvidence,
                    submittingAppeal: _submittingAppeal,
                    actionError: _actionError,
                    onUpload: _uploadEvidence,
                    onAppeal: _submitAppeal,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.servio});
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: servio.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.dispute,
    required this.scrollCtrl,
    required this.appealCtrl,
    required this.submittingEvidence,
    required this.submittingAppeal,
    required this.onUpload,
    required this.onAppeal,
    this.actionError,
  });

  final Dispute dispute;
  final ScrollController scrollCtrl;
  final TextEditingController appealCtrl;
  final bool submittingEvidence;
  final bool submittingAppeal;
  final String? actionError;
  final VoidCallback onUpload;
  final VoidCallback onAppeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final d = dispute;

    final sc = _DisputeCard.statusColor(d.status, servio);
    final dateStr = '${d.createdAt.day.toString().padLeft(2, '0')}/'
        '${d.createdAt.month.toString().padLeft(2, '0')}/'
        '${d.createdAt.year}';

    final customerEvidence =
        d.evidence.where((e) => e.uploadedByRole == 'user').toList();
    final workerEvidence =
        d.evidence.where((e) => e.uploadedByRole == 'worker').toList();
    final adminEvidence =
        d.evidence.where((e) => e.uploadedByRole == 'admin').toList();

    final isResolved =
        d.status.startsWith('resolved') || d.status == 'closed';
    final canUpload = !isResolved;
    final canAppeal = ['resolved_refund', 'resolved_partial', 'resolved_redo']
            .contains(d.status) &&
        d.appealStatus == null;

    final evidenceRequested = d.status == 'awaiting_evidence' &&
        (d.evidenceRequestedFrom == 'worker' ||
            d.evidenceRequestedFrom == 'both');

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: <Widget>[
        // ── Header ───────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _Badge(
                          label: _DisputeCard.statusLabel(d.status),
                          color: sc),
                      if (evidenceRequested) ...<Widget>[
                        const SizedBox(width: 8),
                        _Badge(
                            label: 'Action Required',
                            color: ServioColors.danger),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (d.serviceName != null)
                    Text(d.serviceName!,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Filed by ${d.customerName ?? 'Customer'}  ·  $dateStr',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                  Text(
                    'Severity: ${d.severity}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Evidence request callout ──────────────────────────────────
        if (evidenceRequested) ...<Widget>[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ServioColors.tint(ServioColors.warning),
              borderRadius: BorderRadius.circular(ServioRadius.md),
              border: Border.all(
                  color: ServioColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded,
                    color: ServioColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Admin requested evidence from you.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ServioColors.warning),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload photos, receipts, or proof that supports your work.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const Divider(height: 32),

        // ── Customer's complaint ──────────────────────────────────────
        _SectionTitle(label: "Customer's Complaint"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: servio.backgroundSoft,
            borderRadius: BorderRadius.circular(ServioRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Badge(
                label: _DisputeCard.categoryLabel(d.category),
                color: servio.textSecondary,
                fontSize: 11,
              ),
              const SizedBox(height: 8),
              Text(d.reason,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
            ],
          ),
        ),

        // ── Admin Decision ────────────────────────────────────────────
        if (d.decision != null) ...<Widget>[
          const Divider(height: 32),
          _SectionTitle(label: 'Admin Decision'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ServioColors.tint(
                  isResolved ? ServioColors.success : ServioColors.warning),
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _decisionLabel(d.decision!),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (d.refundAmount != null && d.refundAmount! > 0) ...<Widget>[
                  const SizedBox(height: 4),
                  Text('Refund: EGP ${d.refundAmount!.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall),
                ],
                if (d.resolution != null && d.resolution!.isNotEmpty)
                  ...<Widget>[
                  const SizedBox(height: 6),
                  Text(d.resolution!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary)),
                ],
                if (d.resolvedAt != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Resolved ${_fmtDateTime(d.resolvedAt!)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ] else if (d.resolution != null && d.resolution!.isNotEmpty)
          ...<Widget>[
          const Divider(height: 32),
          _SectionTitle(label: 'Resolution'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ServioColors.tint(ServioColors.success),
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Text(d.resolution!, style: theme.textTheme.bodyMedium),
          ),
        ],

        // ── Appeal status ─────────────────────────────────────────────
        if (d.appealStatus != null) ...<Widget>[
          const Divider(height: 32),
          _SectionTitle(label: 'Appeal'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ServioColors.tint(ServioColors.info),
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.gavel_rounded,
                        color: ServioColors.info, size: 18),
                    const SizedBox(width: 8),
                    Text('Status: ${d.appealStatus}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: ServioColors.info,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                if (d.appealReason != null && d.appealReason!.isNotEmpty)
                  ...<Widget>[
                  const SizedBox(height: 6),
                  Text(d.appealReason!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary)),
                ],
                if (d.appealedAt != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Filed ${_fmtDateTime(d.appealedAt!)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],

        const Divider(height: 32),

        // ── Customer Evidence ─────────────────────────────────────────
        _SectionTitle(
          label: customerEvidence.isEmpty
              ? 'Customer Evidence'
              : 'Customer Evidence (${customerEvidence.length})',
        ),
        const SizedBox(height: 10),
        if (customerEvidence.isEmpty)
          _EmptyInline(label: 'No customer evidence uploaded.')
        else
          _EvidenceGrid(items: customerEvidence, servio: servio),

        const Divider(height: 32),

        // ── Your Evidence ─────────────────────────────────────────────
        _SectionTitle(
          label: workerEvidence.isEmpty
              ? 'Your Evidence'
              : 'Your Evidence (${workerEvidence.length})',
        ),
        const SizedBox(height: 10),
        if (workerEvidence.isEmpty)
          _EmptyInline(label: 'You have not uploaded evidence yet.')
        else
          _EvidenceGrid(items: workerEvidence, servio: servio),

        if (canUpload) ...<Widget>[
          const SizedBox(height: 14),
          if (actionError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(actionError!,
                  style: TextStyle(color: servio.danger, fontSize: 13)),
            ),
          SizedBox(
            width: double.infinity,
            child: submittingEvidence
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Upload Evidence'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: servio.accent,
                      side: BorderSide(color: servio.accent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ServioRadius.md)),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'JPG / PNG / WebP · up to 12 files',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
        ],

        // ── Admin Evidence ────────────────────────────────────────────
        if (adminEvidence.isNotEmpty) ...<Widget>[
          const Divider(height: 32),
          _SectionTitle(label: 'Admin Evidence (${adminEvidence.length})'),
          const SizedBox(height: 10),
          _EvidenceGrid(items: adminEvidence, servio: servio),
        ],

        const Divider(height: 32),

        // ── Timeline ──────────────────────────────────────────────────
        _SectionTitle(label: 'Timeline'),
        const SizedBox(height: 10),
        if (d.history.isEmpty)
          _EmptyInline(label: 'No activity yet.')
        else
          _Timeline(
              events: List<DisputeHistory>.from(d.history)
                ..sort((a, b) => a.at.compareTo(b.at)),
              servio: servio,
              theme: theme),

        // ── Appeal form ───────────────────────────────────────────────
        if (canAppeal) ...<Widget>[
          const Divider(height: 32),
          _SectionTitle(label: 'File an Appeal'),
          const SizedBox(height: 6),
          Text(
            'Disagree with the decision? You have 48 hours. Be specific — admins will re-review.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: appealCtrl,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText:
                  'Explain why this decision should be reconsidered (min. 20 characters)…',
              border: OutlineInputBorder(),
            ),
          ),
          if (actionError != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(actionError!,
                style: TextStyle(color: servio.danger, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: submittingAppeal
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: onAppeal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: servio.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md)),
                    ),
                    child: const Text('Submit Appeal'),
                  ),
          ),
        ],
      ],
    );
  }

  String _decisionLabel(String d) => switch (d) {
        'refund' => 'Full refund to customer',
        'release' => 'Payment released to worker',
        'partial' => 'Partial refund',
        'redo' => 'Redo the job',
        _ => d,
      };

  String _fmtDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
      '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.servio.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      );
}

// ── Inline empty label ────────────────────────────────────────────────────────

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: context.servio.textSecondary),
      );
}

// ── Evidence grid ─────────────────────────────────────────────────────────────

class _EvidenceGrid extends StatelessWidget {
  const _EvidenceGrid({required this.items, required this.servio});
  final List<DisputeEvidence> items;
  final ServioThemeExtension servio;

  static const _roleLabelMap = <String, String>{
    'user': 'Customer',
    'worker': 'You',
    'admin': 'Admin',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          final roleLabel =
              _roleLabelMap[item.uploadedByRole] ?? item.uploadedByRole;
          return SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.url,
                    width: 90,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 80,
                      color: servio.backgroundSoft,
                      child: Icon(Icons.insert_drive_file_outlined,
                          color: servio.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: servio.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline(
      {required this.events, required this.servio, required this.theme});
  final List<DisputeHistory> events;
  final ServioThemeExtension servio;
  final ThemeData theme;

  static Color _dotColor(String role, ServioThemeExtension s) => switch (role) {
        'user' => ServioColors.info,
        'worker' => ServioColors.success,
        'admin' => ServioColors.warning,
        _ => s.textSecondary,
      };

  static String _actionDesc(String status) => switch (status) {
        'open' => 'Dispute opened',
        'reviewing' => 'Review started',
        'awaiting_evidence' => 'Evidence requested',
        'appealed' => 'Decision appealed',
        'closed' => 'Dispute closed',
        String s when s.startsWith('resolved') =>
          'Resolved: ${_DisputeCard.statusLabel(s)}',
        _ => 'Status updated',
      };

  static String _roleFriendly(String role) => switch (role) {
        'user' => 'Customer',
        'worker' => 'Technician (You)',
        'admin' => 'Support Admin',
        _ => 'System',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < events.length; i++)
          _TimelineItem(
            event: events[i],
            isLast: i == events.length - 1,
            dotColor: _dotColor(events[i].byRole, servio),
            actionDesc: _actionDesc(events[i].status),
            roleFriendly: _roleFriendly(events[i].byRole),
            servio: servio,
            theme: theme,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.dotColor,
    required this.actionDesc,
    required this.roleFriendly,
    required this.servio,
    required this.theme,
  });

  final DisputeHistory event;
  final bool isLast;
  final Color dotColor;
  final String actionDesc;
  final String roleFriendly;
  final ServioThemeExtension servio;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${event.at.day.toString().padLeft(2, '0')}/${event.at.month.toString().padLeft(2, '0')}/${event.at.year}'
        '  ${event.at.hour.toString().padLeft(2, '0')}:${event.at.minute.toString().padLeft(2, '0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Column(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: servio.border.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          actionDesc,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'By: ${event.byName ?? roleFriendly}  ($roleFriendly)',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                  if (event.note != null && event.note!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '"${event.note!}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: servio.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disputes Summary Grid — Open / Awaiting Evidence / Resolved
// ─────────────────────────────────────────────────────────────────────────────

class _DisputesSummaryGrid extends StatelessWidget {
  const _DisputesSummaryGrid({
    required this.loading,
    required this.open,
    required this.awaiting,
    required this.resolved,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final bool loading;
  final int open;
  final int awaiting;
  final int resolved;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _DisputesSummaryCard(
            label: 'Open Disputes',
            count: open,
            color: ServioColors.warning,
            loading: loading,
            isSelected: selectedTab == 'open',
            onTap: () => onTabChanged('open'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DisputesSummaryCard(
            label: 'Awaiting Evidence',
            count: awaiting,
            color: ServioColors.info,
            loading: loading,
            isSelected: selectedTab == 'awaiting',
            onTap: () => onTabChanged('awaiting'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DisputesSummaryCard(
            label: 'Resolved',
            count: resolved,
            color: ServioColors.success,
            loading: loading,
            isSelected: selectedTab == 'resolved',
            onTap: () => onTabChanged('resolved'),
          ),
        ),
      ],
    );
  }
}

class _DisputesSummaryCard extends StatelessWidget {
  const _DisputesSummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.loading,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool loading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(
            color: isSelected
                ? color
                : servio.border.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Opacity(
          opacity: isSelected ? 1.0 : 0.65,
          child: Column(
            children: <Widget>[
              if (loading)
                ServioSkeleton(height: 24, width: 40, radius: ServioRadius.sm)
              else
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: servio.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
