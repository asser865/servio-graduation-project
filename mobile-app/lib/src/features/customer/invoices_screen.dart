import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openReceipt(Invoice invoice, PaymentsProvider payments) async {
    final url = payments.receiptUrl(invoice.paymentId);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open receipt.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  final vat =
                      (invoice.vatRate * 100).toStringAsFixed(0);
                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.receipt_long_outlined),
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
                        icon: const Icon(Icons.download_outlined),
                        tooltip: 'Open Receipt',
                        onPressed: () =>
                            _openReceipt(invoice, payments),
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
