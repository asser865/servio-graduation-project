import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class TechnicianPricingScreen extends StatefulWidget {
  const TechnicianPricingScreen({super.key});

  @override
  State<TechnicianPricingScreen> createState() =>
      _TechnicianPricingScreenState();
}

class _TechnicianPricingScreenState extends State<TechnicianPricingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _minFeeCtrl;
  late TextEditingController _travelFeeCtrl;
  late TextEditingController _emergencyMultCtrl;
  late bool _acceptCash;
  late bool _acceptCard;
  late bool _acceptInstapay;
  late bool _acceptWallet;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _minFeeCtrl = TextEditingController(
      text: account != null && account.minFee > 0
          ? account.minFee.toStringAsFixed(0)
          : '',
    );
    _travelFeeCtrl = TextEditingController(
      text: account != null && account.travelFee > 0
          ? account.travelFee.toStringAsFixed(0)
          : '',
    );
    _emergencyMultCtrl = TextEditingController(
      text: account != null && account.emergencyMultiplier != 1.0
          ? account.emergencyMultiplier.toStringAsFixed(1)
          : '',
    );
    _acceptCash = account?.acceptCash ?? false;
    _acceptCard = account?.acceptCard ?? false;
    _acceptInstapay = account?.acceptInstapay ?? false;
    _acceptWallet = account?.acceptWallet ?? false;
  }

  @override
  void dispose() {
    _minFeeCtrl.dispose();
    _travelFeeCtrl.dispose();
    _emergencyMultCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final session = context.read<SessionProvider>();

    try {
      final fields = <String, dynamic>{
        'acceptCash': _acceptCash,
        'acceptCard': _acceptCard,
        'acceptInstapay': _acceptInstapay,
        'acceptWallet': _acceptWallet,
      };

      final minFeeText = _minFeeCtrl.text.trim();
      if (minFeeText.isNotEmpty) {
        final v = double.tryParse(minFeeText);
        if (v != null) fields['minFee'] = v;
      }
      final travelFeeText = _travelFeeCtrl.text.trim();
      if (travelFeeText.isNotEmpty) {
        final v = double.tryParse(travelFeeText);
        if (v != null) fields['travelFee'] = v;
      }
      final multText = _emergencyMultCtrl.text.trim();
      if (multText.isNotEmpty) {
        final v = double.tryParse(multText);
        if (v != null) fields['emergencyMultiplier'] = v;
      }

      final error = await session.updateProfile(fields);

      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing saved.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing & Payments'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Fee Structure', servio),
              const SizedBox(height: 12),
              _PriceField(
                controller: _minFeeCtrl,
                label: 'Minimum Job Fee (EGP)',
                hint: '0',
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid amount ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PriceField(
                controller: _travelFeeCtrl,
                label: 'Call-out / Travel Fee (EGP)',
                hint: '0',
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid amount ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PriceField(
                controller: _emergencyMultCtrl,
                label: 'Emergency Rate Multiplier',
                hint: '1.5',
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 1.0 || n > 5.0) {
                    return 'Must be between 1.0 and 5.0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _sectionLabel('Payment Methods Accepted', servio),
              const SizedBox(height: 8),
              _PaymentSwitch(
                label: 'Cash',
                value: _acceptCash,
                onChanged: (v) => setState(() => _acceptCash = v),
              ),
              _PaymentSwitch(
                label: 'Credit / Debit Card',
                value: _acceptCard,
                onChanged: (v) => setState(() => _acceptCard = v),
              ),
              _PaymentSwitch(
                label: 'Instapay',
                value: _acceptInstapay,
                onChanged: (v) => setState(() => _acceptInstapay = v),
              ),
              _PaymentSwitch(
                label: 'Mobile Wallet',
                value: _acceptWallet,
                onChanged: (v) => setState(() => _acceptWallet = v),
              ),
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: 'Save Pricing',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, ServioThemeExtension servio) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: servio.textSecondary.withValues(alpha: 0.7),
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _PaymentSwitch extends StatelessWidget {
  const _PaymentSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
