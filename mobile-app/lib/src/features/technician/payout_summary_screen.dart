import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/payments_api.dart';
import '../../core/state/payments_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'payout_request_screen.dart';
import 'settle_debt_screen.dart';

/// Worker-only Payout Summary screen.
///
/// Mirrors the website's technician-dashboard payout/earnings sections.
/// Data is fetched from `GET /payments/earnings` via [PaymentsApi].
class PayoutSummaryScreen extends StatefulWidget {
  const PayoutSummaryScreen({super.key});

  @override
  State<PayoutSummaryScreen> createState() => _PayoutSummaryScreenState();
}

class _PayoutSummaryScreenState extends State<PayoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  EarningsSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: ServioMotion.page);
    _fade = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.0, 0.6, curve: ServioMotion.spring),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.1, 0.7, curve: ServioMotion.spring),
    ));
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payments = context.read<PaymentsProvider>();
      await Future.wait([
        payments.loadEarnings(),
        payments.loadDebtSummary(),
      ]);
      _summary = payments.earnings;
    } catch (e) {
      _error = 'Unable to load payout summary.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Summary'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: servio.accent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loading
                  ? const _ShimmerBody()
                  : _error != null
                      ? _ErrorBody(message: _error!, onRetry: _load)
                      : _SuccessBody(summary: _summary!),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Shimmer loading state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ShimmerBody extends StatelessWidget {
  const _ShimmerBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      children: [
        _ShimmerBox(height: 140, radius: ServioRadius.xl),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _ShimmerBox(height: 110, radius: ServioRadius.lg)),
            const SizedBox(width: 12),
            Expanded(child: _ShimmerBox(height: 110, radius: ServioRadius.lg)),
          ],
        ),
        const SizedBox(height: 24),
        _ShimmerBox(height: 24, width: 120, radius: ServioRadius.sm),
        const SizedBox(height: 8),
        _ShimmerBox(height: 220, radius: ServioRadius.lg),
        const SizedBox(height: 24),
        _ShimmerBox(height: 24, width: 120, radius: ServioRadius.sm),
        const SizedBox(height: 8),
        _ShimmerBox(height: 260, radius: ServioRadius.lg),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double width;
  final double radius;
  const _ShimmerBox(
      {required this.height,
      this.width = double.infinity,
      required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.servio.border
                .withValues(alpha: 0.3 + (_ctrl.value * 0.3)),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// â”€â”€ Error state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ListView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 48, color: servio.textSecondary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 24),
        Center(
          child: _ScaleButton(
            onTap: onRetry,
            child: OutlinedButton.icon(
              onPressed: null, // Tap handled by _ScaleButton
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Success body (Stateful for forms) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SuccessBody extends StatefulWidget {
  const _SuccessBody({required this.summary});
  final EarningsSummary summary;

  @override
  State<_SuccessBody> createState() => _SuccessBodyState();
}

class _SuccessBodyState extends State<_SuccessBody> {
  late String _payoutMethod;
  late String _payoutSchedule;
  String? _selectedBank;
  late TextEditingController _accountHolderCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _walletNumberCtrl;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _payoutMethod = widget.summary.payoutMethod;
    if (!['bank', 'instapay', 'vodafone', 'orange'].contains(_payoutMethod)) {
      _payoutMethod = 'bank';
    }
    _payoutSchedule = widget.summary.payoutSchedule;
    if (!['weekly', 'monthly', 'instant'].contains(_payoutSchedule)) {
      _payoutSchedule = 'weekly';
    }

    _selectedBank = _kBankNames.contains(widget.summary.bankName)
        ? widget.summary.bankName
        : null;
    _accountHolderCtrl =
        TextEditingController(text: widget.summary.accountHolder);
    _accountNumberCtrl =
        TextEditingController(text: widget.summary.accountNumber);
    _walletNumberCtrl =
        TextEditingController(text: widget.summary.walletNumber);

    _isLocked = _hasSavedConfig(widget.summary);
  }

  bool _hasSavedConfig(EarningsSummary s) {
    final method = s.payoutMethod;
    if (method == 'bank') {
      return (s.bankName ?? '').trim().isNotEmpty &&
          (s.accountHolder ?? '').trim().isNotEmpty &&
          (s.accountNumber ?? '').trim().isNotEmpty;
    }
    if (['instapay', 'vodafone', 'orange'].contains(method)) {
      return (s.walletNumber ?? '').trim().isNotEmpty;
    }
    return false;
  }

  static const List<String> _kBankNames = <String>[
    'CIB',
    'NBE — National Bank of Egypt',
    'Banque Misr',
    'QNB',
    'HSBC Egypt',
    'Alex Bank',
    'Abu Dhabi Islamic Bank',
    'Faisal Islamic Bank',
  ];

  @override
  void dispose() {
    _accountHolderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _walletNumberCtrl.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    try {
      final client = context.read<ApiClient>();
      await PaymentsApi(client).updateSettings(
        payoutMethod: _payoutMethod,
        payoutSchedule: _payoutSchedule,
        payoutDetails: {
          'bankName': _selectedBank ?? '',
          'accountHolder': _accountHolderCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'walletNumber': _walletNumberCtrl.text.trim(),
        },
      );

      if (!mounted) return;
      setState(() => _isLocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payout settings saved.'),
          backgroundColor: context.servio.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save settings. Please try again.'),
          backgroundColor: context.servio.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleEdit() {
    setState(() => _isLocked = false);
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isNumeric = false,
  }) {
    final theme = Theme.of(context);
    final servio = context.servio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary),
              filled: true,
              fillColor: servio.backgroundSoft,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                borderSide: BorderSide(color: servio.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                borderSide: BorderSide(color: servio.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                borderSide: BorderSide(color: servio.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required String? value,
    required ValueChanged<String?> onChanged,
    required List<String> items,
  }) {
    final theme = Theme.of(context);
    final servio = context.servio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            hint: Text(hint,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: servio.textSecondary)),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: servio.backgroundSoft,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                borderSide: BorderSide(color: servio.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                borderSide: BorderSide(color: servio.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                borderSide: BorderSide(color: servio.accent, width: 1.5),
              ),
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsets.fromLTRB(
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding,
            120 + bottomInset,
          ),
          children: [
            // â”€â”€ Wallet header card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _StaggeredItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ServioGradients.brand,
                  borderRadius: BorderRadius.circular(ServioRadius.xl),
                  boxShadow: ServioShadows.rest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius:
                                BorderRadius.circular(ServioRadius.sm),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Total Earned',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _CountUpText(
                      value: widget.summary.totalEarnings,
                      suffix: ' EGP',
                      style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _CountUpText(
                      value: widget.summary.pendingPayout,
                      prefix: 'Pending: ',
                      suffix: ' EGP',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: ServioColors.accentLight),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // â”€â”€ Metric cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _StaggeredItem(
              index: 1,
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Completed Jobs',
                      value: widget.summary.completedJobs.toDouble(),
                      isCurrency: false,
                      color: servio.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.schedule_rounded,
                      label: 'Pending Payout',
                      value: widget.summary.pendingPayout,
                      isCurrency: true,
                      color: servio.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Saved-state banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            AnimatedSize(
              duration: ServioMotion.normal,
              curve: ServioMotion.spring,
              child: _isLocked
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ServioColors.tint(servio.success),
                          borderRadius: BorderRadius.circular(ServioRadius.md),
                          border: Border.all(
                            color: servio.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: servio.success),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Payout settings saved. Tap Edit to change.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: servio.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // â”€â”€ Payout Method form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            IgnorePointer(
              ignoring: _isLocked,
              child: AnimatedOpacity(
                duration: ServioMotion.normal,
                opacity: _isLocked ? 0.6 : 1,
                child: _StaggeredItem(
                  index: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(label: 'Payout Method'),
                      const SizedBox(height: 8),
                      ServioCard(
                        radius: ServioRadius.lg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose how you receive your earnings from completed jobs.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: servio.textSecondary, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutMethod = 'bank'),
                              child: _PayoutMethodOption(
                                icon: Icons.account_balance_rounded,
                                label: 'Bank Transfer',
                                selected: _payoutMethod == 'bank',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutMethod = 'instapay'),
                              child: _PayoutMethodOption(
                                icon: Icons.flash_on_rounded,
                                label: 'Instapay',
                                selected: _payoutMethod == 'instapay',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutMethod = 'vodafone'),
                              child: _PayoutMethodOption(
                                icon: Icons.phone_android_rounded,
                                label: 'Vodafone Cash',
                                selected: _payoutMethod == 'vodafone',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutMethod = 'orange'),
                              child: _PayoutMethodOption(
                                icon: Icons.phone_android_rounded,
                                label: 'Orange Cash',
                                selected: _payoutMethod == 'orange',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _SectionTitle(label: 'Account Details'),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: FadeTransition(
                                      opacity: animation, child: child),
                                );
                              },
                              child: _payoutMethod == 'bank'
                                  ? Column(
                                      key: const ValueKey('bank_form'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildDropdown(
                                            label: 'Bank Name',
                                            hint: 'Select bank...',
                                            value: _selectedBank,
                                            onChanged: (val) => setState(
                                                () => _selectedBank = val),
                                            items: _kBankNames),
                                        _buildTextField(
                                          label: 'Account Holder Name',
                                          hint: 'Exactly as on your bank card',
                                          controller: _accountHolderCtrl,
                                        ),
                                        _buildTextField(
                                          label: 'Account Number / IBAN',
                                          hint:
                                              'EG00 0000 0000 0000 0000 0000 0000',
                                          controller: _accountNumberCtrl,
                                        ),
                                      ],
                                    )
                                  : Column(
                                      key: const ValueKey('wallet_form'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildTextField(
                                          label: 'Registered Mobile Number',
                                          hint: '+20 100 000 0000',
                                          controller: _walletNumberCtrl,
                                          isNumeric: true,
                                        ),
                                        Text(
                                          'Must match the number registered with your wallet provider.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: servio.textSecondary),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Payout Schedule card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            IgnorePointer(
              ignoring: _isLocked,
              child: AnimatedOpacity(
                duration: ServioMotion.normal,
                opacity: _isLocked ? 0.6 : 1,
                child: _StaggeredItem(
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(label: 'Payout Schedule'),
                      const SizedBox(height: 8),
                      ServioCard(
                        radius: ServioRadius.lg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose how often you want your earnings transferred.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: servio.textSecondary, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutSchedule = 'weekly'),
                              child: _ScheduleOption(
                                label: 'Weekly',
                                subtitle:
                                    'Every Sunday â€” earnings from the past 7 days.',
                                selected: _payoutSchedule == 'weekly',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutSchedule = 'monthly'),
                              child: _ScheduleOption(
                                label: 'Monthly',
                                subtitle:
                                    '1st of each month â€” previous month\'s earnings.',
                                selected: _payoutSchedule == 'monthly',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () =>
                                  setState(() => _payoutSchedule = 'instant'),
                              child: _ScheduleOption(
                                label: 'Instant',
                                subtitle:
                                    'Request a payout at any time (small processing fee applies).',
                                selected: _payoutSchedule == 'instant',
                                servio: servio,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Form button moved to bottom
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Security hint â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _StaggeredItem(
              index: 4,
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: servio.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payout information is encrypted and secure.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const PayoutRequestScreen()),
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Request Payout'),
              ),
            ),
            const SizedBox(height: 32),

            // ── Cash Debt section ─────────────────────────────────────────────
            Consumer<PaymentsProvider>(
              builder: (ctx, payments, _) {
                final summary = payments.debtSummary;
                if (summary == null || summary.debts.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text('Cash Debt',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (summary.isBlocked)
                      _DebtBanner(
                        icon: Icons.lock_outline,
                        color: Colors.red.shade700,
                        message:
                            'Cash bookings locked. Outstanding: EGP ${summary.totalOutstanding.toStringAsFixed(2)}',
                      )
                    else if (summary.isWarning)
                      _DebtBanner(
                        icon: Icons.warning_amber_outlined,
                        color: Colors.orange.shade700,
                        message:
                            'Warning: EGP ${summary.totalOutstanding.toStringAsFixed(2)} outstanding cash debt.',
                      ),
                    const SizedBox(height: 12),
                    ...summary.debts.where((d) => !d.isPaid).map((debt) => ListTile(
                          dense: true,
                          title: Text(
                              'Booking #${debt.bookingId.length >= 8 ? debt.bookingId.substring(0, 8).toUpperCase() : debt.bookingId.toUpperCase()}'),
                          subtitle: Text(debt.status),
                          trailing: Text(
                            'EGP ${debt.remaining.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.bold),
                          ),
                        )),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          ctx,
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  SettleDebtScreen(summary: summary)),
                        ),
                        icon: const Icon(Icons.payment_outlined),
                        label: const Text('Settle Debt'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                10,
                ServioSpacing.screenPadding,
                12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SizedBox(
                    width: double.infinity,
                    child: ServioPrimaryButton(
                      label: _isLocked
                          ? 'Edit Payout Settings'
                          : (_isSaving ? 'Saving...' : 'Save Changes'),
                      onPressed: _isLocked
                          ? _handleEdit
                          : (_isSaving ? null : _handleSave),
                      isLoading: _isSaving,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Reusable helpers & animations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredItem({required this.index, required this.child});
  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: ServioMotion.spring));
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _CountUpText extends StatelessWidget {
  const _CountUpText({
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
  });
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text('$prefix${value.toStringAsFixed(0)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: ServioMotion.spring,
      builder: (context, val, child) {
        return Text('$prefix${val.toStringAsFixed(0)}$suffix', style: style);
      },
    );
  }
}

class _ScaleButton extends StatefulWidget {
  const _ScaleButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.98)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: widget.child);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isCurrency,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double value;
  final bool isCurrency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ServioColors.tint(color),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          _CountUpText(
            value: value,
            suffix: isCurrency ? ' EGP' : '',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PayoutMethodOption extends StatelessWidget {
  const _PayoutMethodOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.servio,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(
          color: selected ? servio.accent : servio.border,
          width: selected ? 1.5 : 1,
        ),
        color: selected
            ? servio.accent.withValues(alpha: 0.06)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20, color: selected ? servio.accent : servio.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? servio.accent : null,
                  ),
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 20, color: servio.accent),
        ],
      ),
    );
  }
}

class _ScheduleOption extends StatelessWidget {
  const _ScheduleOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.servio,
  });
  final String label;
  final String subtitle;
  final bool selected;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(
          color: selected ? servio.accent : servio.border,
          width: selected ? 1.5 : 1,
        ),
        color: selected
            ? servio.accent.withValues(alpha: 0.06)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? servio.accent : servio.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? servio.accent : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtBanner extends StatelessWidget {
  const _DebtBanner({
    required this.icon,
    required this.color,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
