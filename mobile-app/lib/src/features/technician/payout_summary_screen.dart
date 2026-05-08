import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/payments_api.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

/// Worker-only Payout Summary screen.
///
/// Mirrors the website's technician-dashboard payout/earnings sections:
///   • Wallet balance header (total earned, pending, available)
///   • Metric cards (completed jobs, this-month placeholder)
///   • Payout method card (bank / wallet — settings placeholder)
///   • Payout schedule card (weekly / monthly / instant)
///   • Security hint
///
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
      final client = context.read<ApiClient>();
      _summary = await PaymentsApi(client).getEarnings();
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorBody(message: _error!, onRetry: _load)
                    : _SuccessBody(summary: _summary!),
          ),
        ),
      ),
    );
  }
}

// ── Error state ──────────────────────────────────────────────────────────────

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
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

// ── Success body ─────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      children: [
        // ── Wallet header card ───────────────────────────────────────────
        Container(
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
                      borderRadius: BorderRadius.circular(ServioRadius.sm),
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
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${summary.totalEarnings.toStringAsFixed(0)} EGP',
                style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Pending: ${summary.pendingPayout.toStringAsFixed(0)} EGP',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: ServioColors.accentLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Metric cards ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed Jobs',
                value: '${summary.completedJobs}',
                color: servio.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.schedule_rounded,
                label: 'Pending Payout',
                value: '${summary.pendingPayout.toStringAsFixed(0)} EGP',
                color: servio.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Payout Method card ───────────────────────────────────────────
        // Matches website: tech_payout_method_title / tech_payout_method_desc
        _SectionTitle(label: 'Payout Method'),
        const SizedBox(height: 8),
        ServioCard(
          radius: ServioRadius.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how you receive your earnings from completed jobs.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: servio.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              _PayoutMethodOption(
                icon: Icons.account_balance_rounded,
                label: 'Bank Transfer',
                selected: true,
                servio: servio,
              ),
              const SizedBox(height: 10),
              _PayoutMethodOption(
                icon: Icons.phone_android_rounded,
                label: 'Mobile Wallet',
                selected: false,
                servio: servio,
              ),
              const SizedBox(height: 16),
              // Account details placeholder
              // Matches website: tech_payout_details_title
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: servio.backgroundSoft,
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                  border: Border.all(
                    color: servio.border,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: servio.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account details are encrypted and never shared publicly.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Payout Schedule card ─────────────────────────────────────────
        // Matches website: tech_payout_schedule_title
        _SectionTitle(label: 'Payout Schedule'),
        const SizedBox(height: 8),
        ServioCard(
          radius: ServioRadius.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how often you want your earnings transferred.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: servio.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              _ScheduleOption(
                label: 'Weekly',
                subtitle: 'Every Sunday — earnings from the past 7 days.',
                selected: true,
                servio: servio,
              ),
              const SizedBox(height: 10),
              _ScheduleOption(
                label: 'Monthly',
                subtitle: '1st of each month — previous month\'s earnings.',
                selected: false,
                servio: servio,
              ),
              const SizedBox(height: 10),
              _ScheduleOption(
                label: 'Instant',
                subtitle:
                    'Request a payout at any time (small processing fee applies).',
                selected: false,
                servio: servio,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Security hint ────────────────────────────────────────────────
        Row(
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
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Reusable helpers ─────────────────────────────────────────────────────────

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
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
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
          Text(
            value,
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
    return Container(
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
    return Container(
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
