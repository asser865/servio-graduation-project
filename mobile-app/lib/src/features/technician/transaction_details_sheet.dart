import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/payments_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/state/disputes_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

Future<void> showTransactionDetailsSheet(
  BuildContext context, {
  required BackendBooking job,
  Future<void> Function()? onReportSubmitted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionDetailsSheet(
      job: job,
      onReportSubmitted: onReportSubmitted,
    ),
  );
}

class TransactionDetailsSheet extends StatefulWidget {
  const TransactionDetailsSheet({
    required this.job,
    this.onReportSubmitted,
    super.key,
  });

  final BackendBooking job;
  final Future<void> Function()? onReportSubmitted;

  @override
  State<TransactionDetailsSheet> createState() =>
      _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<TransactionDetailsSheet> {
  bool _submittingReport = false;

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
      case 'done':
        return 'Released';
      case 'awaiting_customer_confirmation':
        return 'Awaiting Confirmation';
      case 'pending_admin_review':
        return 'Under Admin Review';
      case 'in_progress':
        return 'In Progress';
      case 'disputed':
        return 'Disputed';
      default:
        final clean = status.replaceAll('_', ' ');
        if (clean.isEmpty) return 'Pending';
        return '${clean[0].toUpperCase()}${clean.substring(1)}';
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash on Delivery';
      case 'card':
      case 'credit_card':
        return 'Credit / Debit Card';
      case 'wallet':
        return 'Wallet';
      default:
        return method.isEmpty ? 'Unknown' : method;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'held':
        return 'Held in Escrow';
      case 'released':
        return 'Released';
      case 'refunded':
        return 'Refunded';
      case 'failed':
        return 'Failed';
      case 'disputed':
        return 'Disputed';
      case 'cash_pending_settlement':
        return 'Cash — Pending Settlement';
      case 'cash_settled':
        return 'Cash — Settled';
      case 'unpaid':
        return 'Unpaid';
      default:
        return status;
    }
  }

  Future<void> _submitReport(String reason) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final disputes = context.read<DisputesProvider>();
    final apiClient = context.read<ApiClient>();
    setState(() => _submittingReport = true);
    try {
      String paymentId = '';
      try {
        final pd = await PaymentsApi(apiClient)
            .getPaymentByBooking(widget.job.id);
        paymentId = pd['_id'] as String? ?? '';
      } catch (_) {}
      await disputes.openDispute(
        bookingId: widget.job.id,
        paymentId: paymentId,
        reason: reason,
        category: 'other',
      );
      await widget.onReportSubmitted?.call();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Issue reported. Admin will review shortly.'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingReport = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not submit report. Try again.'),
      ));
    }
  }

  Future<void> _openReportDialog() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _ReportIssueDialog(),
    );
    if (reason != null && reason.isNotEmpty) {
      await _submitReport(reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final job = widget.job;
    final net = job.totalAmount * 0.90;
    final platformFee = job.totalAmount - net;
    final d = job.scheduledDate;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final timeStr = job.scheduledTime.isEmpty ? '—' : job.scheduledTime;
    final address = <String>[job.addressStreet, job.addressCity]
        .where((String s) => s.trim().isNotEmpty)
        .join(', ');
    final cardLabel = <String>[
      job.paymentCardType,
      if (job.paymentCardLast4.isNotEmpty) '••${job.paymentCardLast4}',
    ].where((String s) => s.trim().isNotEmpty).join(' ');
    final isDisputed = job.status == 'disputed';
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (BuildContext ctx, ScrollController scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: servio.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: ServioColors.tint(servio.accent),
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.md),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: servio.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  job.serviceName.isEmpty
                                      ? 'Service'
                                      : job.serviceName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (job.serviceCategory.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    job.serviceCategory.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: servio.textSecondary,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ServioColors.tint(
                                isDisputed ? servio.danger : servio.accent,
                              ),
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.full),
                            ),
                            child: Text(
                              _statusLabel(job.status),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    isDisputed ? servio.danger : servio.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _DetailGroup(
                        title: 'Schedule',
                        rows: <_DetailRow>[
                          _DetailRow('Date', dateStr,
                              icon: Icons.calendar_today_rounded),
                          _DetailRow('Time', timeStr,
                              icon: Icons.access_time_rounded),
                          if (address.isNotEmpty)
                            _DetailRow('Location', address,
                                icon: Icons.place_outlined),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailGroup(
                        title: 'Customer',
                        rows: <_DetailRow>[
                          _DetailRow(
                            'Name',
                            job.customerName.isEmpty
                                ? 'Unknown'
                                : job.customerName,
                            icon: Icons.person_outline_rounded,
                          ),
                          if (job.customerId.isNotEmpty)
                            _DetailRow(
                              'Customer ID',
                              job.customerId,
                              icon: Icons.badge_outlined,
                              mono: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailGroup(
                        title: 'Payment',
                        rows: <_DetailRow>[
                          _DetailRow(
                            'Method',
                            _paymentMethodLabel(job.paymentMethod),
                            icon: Icons.payments_outlined,
                          ),
                          if (cardLabel.isNotEmpty)
                            _DetailRow('Card', cardLabel,
                                icon: Icons.credit_card_rounded),
                          _DetailRow(
                            'Status',
                            _paymentStatusLabel(job.paymentStatus),
                            icon: Icons.verified_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.lg),
                        ),
                        child: Column(
                          children: <Widget>[
                            _AmountRow(
                              label: 'Total billed',
                              value:
                                  '${job.totalAmount.toStringAsFixed(0)} EGP',
                            ),
                            const SizedBox(height: 8),
                            _AmountRow(
                              label: 'Platform fee (10%)',
                              value: '- ${platformFee.toStringAsFixed(0)} EGP',
                              valueColor: servio.textSecondary,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: servio.border,
                                height: 1,
                              ),
                            ),
                            _AmountRow(
                              label: 'Your net earning',
                              value: '${net.toStringAsFixed(0)} EGP',
                              valueColor: servio.accent,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      if (job.notes.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        _DetailGroup(
                          title: 'Notes',
                          rows: <_DetailRow>[
                            _DetailRow('', job.notes,
                                icon: Icons.notes_rounded),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _DetailGroup(
                        title: 'Reference',
                        rows: <_DetailRow>[
                          _DetailRow('Booking ID', job.id,
                              icon: Icons.tag_rounded, mono: true),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_submittingReport || isDisputed)
                              ? null
                              : _openReportDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: servio.danger,
                            side: BorderSide(color: servio.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.md),
                            ),
                          ),
                          icon: _submittingReport
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: servio.danger,
                                  ),
                                )
                              : const Icon(Icons.flag_outlined),
                          label: Text(
                            isDisputed ? 'Already Reported' : 'Report an Issue',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reporting opens a dispute. Admin will contact both parties to resolve.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: servio.textSecondary,
                        ),
                      ),
                    ],
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

class _ReportIssueDialog extends StatefulWidget {
  const _ReportIssueDialog();

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Report an issue'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Describe the problem with this booking. Admin will review.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 500,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. customer disputes work quality',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow(
    this.label,
    this.value, {
    required this.icon,
    this.mono = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool mono;
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: servio.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: servio.textSecondary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(rows[i].icon, size: 18, color: servio.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (rows[i].label.isNotEmpty)
                        Text(
                          rows[i].label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary,
                          ),
                        ),
                      Text(
                        rows[i].value,
                        style: rows[i].mono
                            ? theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface,
                              )
                            : theme.textTheme.bodyMedium,
                      ),
                    ],
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

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final style =
        (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
            ?.copyWith(
      color: valueColor,
      fontWeight: bold ? FontWeight.w700 : null,
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
            ),
          ),
        ),
        Text(value, style: style),
      ],
    );
  }
}
