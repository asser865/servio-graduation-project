import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/payments_provider.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen>
    with SingleTickerProviderStateMixin {
  static const _minAmount = 50.0;
  static const _methods = [
    ('Vodafone Cash', 'vodafone_cash'),
    ('InstaPay', 'instapay'),
    ('Bank Transfer', 'bank'),
  ];

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final _amountCtrl = TextEditingController();
  String _method = 'vodafone_cash';
  final _phoneCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

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
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _ibanCtrl.dispose();
    _holderCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildDetails() => switch (_method) {
        'vodafone_cash' || 'instapay' =>
          {'walletNumber': _phoneCtrl.text.trim()},
        'bank' => {
            'iban': _ibanCtrl.text.trim(),
            'accountHolder': _holderCtrl.text.trim(),
            'bankName': _bankCtrl.text.trim(),
          },
        _ => <String, dynamic>{},
      };

  String? _validate() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < _minAmount) return 'Minimum payout is EGP $_minAmount.';
    if (_method != 'bank' && _phoneCtrl.text.trim().isEmpty) {
      return 'Enter your wallet / InstaPay number.';
    }
    if (_method == 'bank') {
      if (_ibanCtrl.text.trim().isEmpty) return 'Enter IBAN.';
      if (_holderCtrl.text.trim().isEmpty) return 'Enter account holder name.';
      if (_bankCtrl.text.trim().isEmpty) return 'Enter bank name.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final amount = double.parse(_amountCtrl.text.trim());
      await context.read<PaymentsProvider>().requestPayout(
            amount: amount,
            payoutMethod: _method,
            payoutDetails: _buildDetails(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payout request of EGP ${amount.toStringAsFixed(2)} submitted.'),
        ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Request Payout')),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount (EGP)',
                  border: OutlineInputBorder(),
                  prefixText: 'EGP ',
                ),
              ),
              const SizedBox(height: 24),
              Text('Payout Method', style: theme.textTheme.titleSmall),
              for (final (label, value) in _methods)
                RadioListTile<String>(
                  title: Text(label),
                  value: value,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                ),
              const SizedBox(height: 16),
              if (_method == 'vodafone_cash' || _method == 'instapay')
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _method == 'vodafone_cash'
                        ? 'Vodafone Cash Number'
                        : 'InstaPay Number',
                    border: const OutlineInputBorder(),
                  ),
                )
              else ...[
                TextField(
                  controller: _ibanCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _holderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: _submitting ? 'Submitting…' : 'Submit Request',
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
