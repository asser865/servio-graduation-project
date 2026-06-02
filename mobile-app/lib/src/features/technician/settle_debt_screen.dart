import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/cash_debt.dart';
import '../../core/state/payments_provider.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class SettleDebtScreen extends StatefulWidget {
  const SettleDebtScreen({required this.summary, super.key});
  final CashDebtSummary summary;

  @override
  State<SettleDebtScreen> createState() => _SettleDebtScreenState();
}

class _SettleDebtScreenState extends State<SettleDebtScreen>
    with SingleTickerProviderStateMixin {
  static const _methods = [
    ('Wallet Deduction', 'wallet'),
    ('InstaPay', 'instapay'),
    ('Vodafone Cash', 'vodafone_cash'),
    ('Bank Transfer', 'bank_transfer'),
  ];

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  String _method = 'wallet';
  final _referenceCtrl = TextEditingController();
  List<int>? _proofBytes;
  String _proofFilename = '';
  bool _submitting = false;
  String? _error;

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
  }

  @override
  void dispose() {
    _anim.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  List<String> get _unpaidDebtIds => widget.summary.debts
      .where((d) => !d.isPaid)
      .map((d) => d.id)
      .toList();

  Future<void> _pickProof() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _proofBytes = bytes;
      _proofFilename = file.name;
    });
  }

  Future<void> _submit() async {
    if (_method != 'wallet' && _referenceCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the transfer reference number.');
      return;
    }
    if (_method != 'wallet' && _proofBytes == null) {
      setState(() => _error = 'Upload a proof screenshot.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payments = context.read<PaymentsProvider>();
      if (_method == 'wallet') {
        await payments.settleDebtsWithWallet(_unpaidDebtIds);
      } else {
        await payments.api.settleDebtsManually(
          debtIds: _unpaidDebtIds,
          method: _method,
          reference: _referenceCtrl.text.trim(),
          proofBytes: _proofBytes!,
          proofFilename: _proofFilename,
        );
        await payments.loadDebtSummary();
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement submitted successfully.')),
      );
    } catch (e) {
      setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.summary.totalOutstanding;

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Cash Debt')),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Total to settle: EGP ${total.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Text('Payment Method', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final (label, value) in _methods)
                RadioListTile<String>(
                  title: Text(label),
                  value: value,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                ),
              if (_method != 'wallet') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference / Transaction ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickProof,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(_proofBytes != null
                      ? 'Proof selected (tap to change)'
                      : 'Upload Proof Screenshot'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: _submitting ? 'Submitting...' : 'Submit Settlement',
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
