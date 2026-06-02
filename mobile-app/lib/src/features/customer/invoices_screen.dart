import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/invoice.dart';
import '../../core/state/payments_provider.dart';
import '../../design_system/servio_tokens.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: ServioMotion.page);
    _fade = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.0, 0.6, curve: ServioMotion.spring),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.1, 0.7, curve: ServioMotion.spring),
    ));
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentsProvider>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _showReceipt(BuildContext context, Invoice invoice, PaymentsProvider payments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptSheet(invoice: invoice, payments: payments),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices & Receipts')),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Consumer<PaymentsProvider>(
            builder: (ctx, payments, _) {
              if (payments.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (payments.invoices.isEmpty) {
                return const Center(
                  child: Text(
                    'No invoices yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: payments.invoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final invoice = payments.invoices[i];
                  final vat = (invoice.vatRate * 100).toStringAsFixed(0);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('Invoice #${invoice.number}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${invoice.displayTotal}  (incl. $vat% VAT)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${invoice.issuedAt.day}/${invoice.issuedAt.month}/${invoice.issuedAt.year}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.receipt_outlined),
                        tooltip: 'View Receipt',
                        onPressed: () => _showReceipt(ctx, invoice, payments),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReceiptSheet extends StatelessWidget {
  const _ReceiptSheet({required this.invoice, required this.payments});

  final Invoice invoice;
  final PaymentsProvider payments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vat = (invoice.vatRate * 100).toStringAsFixed(0);
    final issued =
        '${invoice.issuedAt.day.toString().padLeft(2, '0')}/'
        '${invoice.issuedAt.month.toString().padLeft(2, '0')}/'
        '${invoice.issuedAt.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Receipt',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '#${invoice.number}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Issued $issued',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),
                _Row(
                  label: 'Subtotal',
                  value: '${invoice.currency} ${invoice.subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 10),
                _Row(
                  label: 'VAT ($vat%)',
                  value: '${invoice.currency} ${invoice.vat.toStringAsFixed(2)}',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _Row(
                  label: 'Total',
                  value: invoice.displayTotal,
                  bold: true,
                  large: true,
                ),
                if (invoice.bookingId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Booking ref: ${invoice.bookingId}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    final effective = bold
        ? style?.copyWith(fontWeight: FontWeight.bold)
        : style;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: effective),
        Text(value, style: effective),
      ],
    );
  }
}
