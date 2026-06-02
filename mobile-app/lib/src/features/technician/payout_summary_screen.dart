import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/payments_api.dart';
import '../../core/state/payments_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'payout_request_screen.dart';
import 'settle_debt_screen.dart';

/// Worker-only Payout Summary screen.
///
/// Matches the Stitch premium redesign visual standards.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Stitch design token colors adjusted for light & dark mode
    final stitchBg = isDark ? const Color(0xFF131518) : const Color(0xFFFBF9F6);
    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);

    return Scaffold(
      backgroundColor: stitchBg,
      appBar: AppBar(
        title: const Text('Payout Summary'),
        backgroundColor: stitchBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: stitchNavy,
        ),
        iconTheme: IconThemeData(
          color: stitchNavy,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: isDark ? const Color(0xFFBA1A1A) : const Color(0xFF1A1D23),
        backgroundColor: isDark ? const Color(0xFF1E2124) : Colors.white,
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

// ── Shimmer loading state ──────────────────────────────────────────────────

class _ShimmerBody extends StatelessWidget {
  const _ShimmerBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ShimmerBox(height: 150, radius: 16),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _ShimmerBox(height: 80, radius: 12)),
            const SizedBox(width: 12),
            Expanded(child: _ShimmerBox(height: 80, radius: 12)),
          ],
        ),
        const SizedBox(height: 24),
        _ShimmerBox(height: 24, width: 140, radius: 4),
        const SizedBox(height: 12),
        _ShimmerBox(height: 380, radius: 16),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double width;
  final double radius;
  const _ShimmerBox({
    required this.height,
    this.width = double.infinity,
    required this.radius,
  });

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF26292D) : const Color(0xFFECEAEA);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.4 + (_ctrl.value * 0.4)),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// ── Error state ─────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 48, color: theme.disabledColor),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'Inter',
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: _ScaleButton(
            onTap: onRetry,
            child: OutlinedButton.icon(
              onPressed: null, // Tap handled by _ScaleButton
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: stitchNavy,
                side: BorderSide(color: stitchNavy.withValues(alpha: 0.3)),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Success body (Stateful for forms) ───────────────────────────────────────

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
  bool _obscureAccountNumber = true;

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
          content: const Text('Payout settings saved securely.'),
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
    bool isPassword = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);
    final stitchMuted = isDark ? const Color(0xFF9EA3AE) : const Color(0xFF6B6560);
    final inputBg = isDark ? const Color(0xFF1E2124) : const Color(0xFFFBF9F6);
    final borderColor = isDark ? const Color(0xFF383A40) : const Color(0xFFC6C6CB);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.bold,
              color: stitchNavy,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: isPassword && _obscureAccountNumber,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            cursorColor: stitchNavy,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Inter',
              color: stitchNavy,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                color: stitchMuted,
              ),
              filled: true,
              fillColor: inputBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: stitchNavy, width: 1.5),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureAccountNumber = !_obscureAccountNumber;
                        });
                      },
                      icon: Icon(
                        _obscureAccountNumber
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: stitchMuted,
                        size: 20,
                      ),
                    )
                  : null,
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
    final isDark = theme.brightness == Brightness.dark;
    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);
    final stitchMuted = isDark ? const Color(0xFF9EA3AE) : const Color(0xFF6B6560);
    final inputBg = isDark ? const Color(0xFF1E2124) : const Color(0xFFFBF9F6);
    final borderColor = isDark ? const Color(0xFF383A40) : const Color(0xFFC6C6CB);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.bold,
              color: stitchNavy,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            hint: Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                color: stitchMuted,
              ),
            ),
            dropdownColor: isDark ? const Color(0xFF1E2124) : Colors.white,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Inter',
              color: stitchNavy,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: stitchNavy, width: 1.5),
              ),
            ),
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(fontFamily: 'Inter'),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // HSL Stitch Color Definitions
    final stitchBg = isDark ? const Color(0xFF131518) : const Color(0xFFFBF9F6);
    final stitchWarm = isDark ? const Color(0xFF2C2520) : const Color(0xFFF3EDE7);
    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);
    final stitchTaupe = isDark ? const Color(0xFF9A8C73) : const Color(0xFF9A8C73);
    final stitchMuted = isDark ? const Color(0xFF9EA3AE) : const Color(0xFF6B6560);
    final stitchWhite = isDark ? const Color(0xFF1E2124) : Colors.white;
    final borderColor = isDark ? const Color(0xFF383A40) : const Color(0xFFE4E2DF);

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            120 + bottomInset,
          ),
          children: [
            // ── Wallet header card (Bento Stat Primary) ──────────────────────────
            _StaggeredItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: stitchWarm,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: stitchTaupe.withValues(alpha: isDark ? 0.35 : 0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PENDING PAYOUT',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: stitchMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _CountUpText(
                            value: widget.summary.pendingPayout,
                            suffix: ' EGP',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: stitchNavy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scheduled for transfer: ${widget.summary.payoutSchedule.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: stitchMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2124) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 22,
                        color: stitchNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Bento Metric Row ─────────────────────────────────────────────────
            _StaggeredItem(
              index: 1,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: stitchWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: stitchWarm,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              size: 20,
                              color: Color(0xFF3E2723),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COMPLETED JOBS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: stitchMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.summary.completedJobs}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: stitchNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: stitchWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: stitchWarm,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.trending_up_rounded,
                              size: 20,
                              color: Color(0xFF3E2723),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YTD EARNINGS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: stitchMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _CountUpText(
                                  value: widget.summary.totalEarnings,
                                  suffix: ' EGP',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: stitchNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Saved state alert ────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isLocked
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A24).withValues(alpha: 0.4)
                              : const Color(0xFFEFFDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1B6A2E)
                                : const Color(0xFFD1FAE5),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Payout settings are securely saved. Tap Edit to update.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Select Payout Method Form ────────────────────────────────────────
            IgnorePointer(
              ignoring: _isLocked,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isLocked ? 0.6 : 1,
                child: _StaggeredItem(
                  index: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Payout Method',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: stitchNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ScaleButton(
                        onTap: () => setState(() => _payoutMethod = 'bank'),
                        child: _PayoutMethodOptionCard(
                          icon: Icons.account_balance_rounded,
                          label: 'Bank Transfer',
                          subtitle: 'Direct deposit to checking/savings. 1-2 business days.',
                          selected: _payoutMethod == 'bank',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ScaleButton(
                        onTap: () => setState(() => _payoutMethod = 'instapay'),
                        child: _PayoutMethodOptionCard(
                          icon: Icons.bolt_rounded,
                          label: 'Instapay',
                          subtitle: 'Instant transfer to debit card. 1.5% fee applies.',
                          selected: _payoutMethod == 'instapay',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ScaleButton(
                        onTap: () => setState(() => _payoutMethod = 'vodafone'),
                        child: _PayoutMethodOptionCard(
                          icon: Icons.phone_android_rounded,
                          label: 'Vodafone Cash',
                          subtitle: 'Transfer directly to integrated mobile wallet.',
                          selected: _payoutMethod == 'vodafone',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ScaleButton(
                        onTap: () => setState(() => _payoutMethod = 'orange'),
                        child: _PayoutMethodOptionCard(
                          icon: Icons.phone_android_rounded,
                          label: 'Orange Cash',
                          subtitle: 'Transfer directly to integrated mobile wallet.',
                          selected: _payoutMethod == 'orange',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Secure Details Card ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: stitchWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(34, 40, 49, 0.03),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: stitchTaupe,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Secure Account Details',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: stitchNavy,
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 32, color: borderColor),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: _payoutMethod == 'bank'
                                  ? Column(
                                      key: const ValueKey('bank_form_fields'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildDropdown(
                                          label: 'Bank Name',
                                          hint: 'Select bank...',
                                          value: _selectedBank,
                                          onChanged: (val) => setState(
                                              () => _selectedBank = val),
                                          items: _kBankNames,
                                        ),
                                        _buildTextField(
                                          label: 'Account Holder Name',
                                          hint: 'Name exactly as on bank card',
                                          controller: _accountHolderCtrl,
                                        ),
                                        _buildTextField(
                                          label: 'Account Number / IBAN',
                                          hint: 'EG00 0000 0000 0000 0000 0000',
                                          controller: _accountNumberCtrl,
                                          isPassword: true,
                                        ),
                                      ],
                                    )
                                  : Column(
                                      key: const ValueKey('wallet_form_fields'),
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
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: stitchMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                            ),

                            // Mini inline button modeled on Stitch
                            if (!_isLocked) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _handleSave,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.shield_outlined, size: 16),
                                  label: Text(
                                    _isSaving ? 'Saving...' : 'Save Securely',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? const Color(0xFFBA1A1A)
                                        : const Color(0xFF1A1D23),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Payout Schedule card ─────────────────────────────────────────────
            IgnorePointer(
              ignoring: _isLocked,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isLocked ? 0.6 : 1,
                child: _StaggeredItem(
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout Schedule',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: stitchNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: stitchWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose how often you want your earnings transferred.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: stitchMuted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ScaleButton(
                              onTap: () => setState(() => _payoutSchedule = 'weekly'),
                              child: _PayoutScheduleCard(
                                label: 'Weekly',
                                subtitle: 'Every Sunday — earnings from the past 7 days.',
                                selected: _payoutSchedule == 'weekly',
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () => setState(() => _payoutSchedule = 'monthly'),
                              child: _PayoutScheduleCard(
                                label: 'Monthly',
                                subtitle: '1st of each month — previous month\'s earnings.',
                                selected: _payoutSchedule == 'monthly',
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ScaleButton(
                              onTap: () => setState(() => _payoutSchedule = 'instant'),
                              child: _PayoutScheduleCard(
                                label: 'Instant',
                                subtitle: 'Request payout at any time (processing fee applies).',
                                selected: _payoutSchedule == 'instant',
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

            // ── Request Payout button & Security hint ───────────────────────────
            _StaggeredItem(
              index: 4,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: stitchMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your payout information is encrypted and secure.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: stitchMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const PayoutRequestScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      label: const Text('Request Payout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: stitchNavy,
                        side: BorderSide(color: stitchNavy.withValues(alpha: 0.35)),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cash Debt Section ───────────────────────────────────────────────
            Consumer<PaymentsProvider>(
              builder: (ctx, payments, _) {
                final summary = payments.debtSummary;
                if (summary == null || summary.debts.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Cash Debt',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: stitchNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (summary.isBlocked)
                      _DebtBanner(
                        icon: Icons.lock_outline_rounded,
                        color: const Color(0xFFBA1A1A),
                        message:
                            'Cash bookings locked. Outstanding: EGP ${summary.totalOutstanding.toStringAsFixed(2)}',
                      )
                    else if (summary.isWarning)
                      _DebtBanner(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFF97316),
                        message:
                            'Warning: EGP ${summary.totalOutstanding.toStringAsFixed(2)} outstanding cash debt.',
                      ),
                    const SizedBox(height: 12),
                    ...summary.debts.where((d) => !d.isPaid).map((debt) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: stitchWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              'Booking #${debt.bookingId.length >= 8 ? debt.bookingId.substring(0, 8).toUpperCase() : debt.bookingId.toUpperCase()}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                color: stitchNavy,
                              ),
                            ),
                            subtitle: Text(
                              debt.status.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: stitchMuted,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            trailing: Text(
                              'EGP ${debt.remaining.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFBA1A1A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          ctx,
                          MaterialPageRoute<void>(
                            builder: (_) => SettleDebtScreen(summary: summary),
                          ),
                        ),
                        icon: const Icon(Icons.payment_outlined, size: 18),
                        label: const Text('Settle Debt'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBA1A1A),
                          side: const BorderSide(color: Color(0xFFFFDAD6)),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        // ── Floating Action Bar Footer ──────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  stitchBg.withValues(alpha: 0.0),
                  stitchBg.withValues(alpha: 0.95),
                  stitchBg,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
        ),
      ],
    );
  }
}

// ── Reusable helpers & animations ───────────────────────────────────────────

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
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
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
    this.suffix = '',
  });
  final double value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text('${value.toStringAsFixed(2)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: ServioMotion.spring,
      builder: (context, val, child) {
        return Text('${val.toStringAsFixed(2)}$suffix', style: style);
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
        vsync: this, duration: const Duration(milliseconds: 120));
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

// ── Stitch Custom Form Widgets ──────────────────────────────────────────────

class _PayoutMethodOptionCard extends StatelessWidget {
  const _PayoutMethodOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final stitchWarm = isDark ? const Color(0xFF2C2520) : const Color(0xFFF3EDE7);
    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);
    final stitchMuted = isDark ? const Color(0xFF9EA3AE) : const Color(0xFF6B6560);
    final stitchWhite = isDark ? const Color(0xFF1E2124) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stitchWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? stitchNavy : (isDark ? const Color(0xFF383A40) : const Color(0xFFC6C6CB)),
          width: selected ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? stitchWarm : (isDark ? const Color(0xFF26292D) : const Color(0xFFF1F3F5)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected ? stitchNavy : stitchMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected ? stitchNavy : theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: stitchMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? stitchNavy : stitchMuted.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: stitchNavy,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _PayoutScheduleCard extends StatelessWidget {
  const _PayoutScheduleCard({
    required this.label,
    required this.subtitle,
    required this.selected,
  });
  final String label;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final stitchNavy = isDark ? const Color(0xFFE4E2DF) : const Color(0xFF1A1D23);
    final stitchMuted = isDark ? const Color(0xFF9EA3AE) : const Color(0xFF6B6560);
    final stitchWhite = isDark ? const Color(0xFF1E2124) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: stitchWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? stitchNavy : (isDark ? const Color(0xFF383A40) : const Color(0xFFE4E2DF)),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? stitchNavy : stitchMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected ? stitchNavy : theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: stitchMuted,
                  ),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
