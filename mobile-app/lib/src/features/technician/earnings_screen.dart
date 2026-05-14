import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/payments_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _periodIndex = 0;
  static const List<String> _periods = <String>[
    'This Week',
    'This Month',
    'All Time'
  ];

  EarningsSummary? _summary;
  List<BackendBooking> _recentJobs = [];
  bool _loading = true;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _fetchError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final session = context.read<SessionProvider>();
      final workerId = session.account?.id.trim() ?? '';

      final summaryFuture = PaymentsApi(client).getEarnings();
      final bookingsFuture =
          BookingsApi(client).getWorkerBookings(workerId: workerId);

      final results =
          await Future.wait(<Future<dynamic>>[summaryFuture, bookingsFuture]);
      if (!mounted) return;
      _summary = results[0] as EarningsSummary;

      final jobs = results[1] as List<BackendBooking>;
      _recentJobs = jobs
          .where((job) => ['completed', 'done'].contains(job.status))
          .toList();
      _recentJobs.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    } catch (_) {
      if (mounted) {
        setState(() => _fetchError = 'Could not load earnings data.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showWithdrawComingSoon() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        final theme = Theme.of(ctx);
        final servio = ctx.servio;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: servio.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.accent),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 30,
                    color: servio.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Withdrawals Coming Soon',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Instant payouts to your bank or wallet will be '
                  'available in an upcoming release. '
                  'Your earnings are safe and accumulating until then.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: servio.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: servio.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final earnings = _summary?.totalEarnings ?? 0.0;
    final pending = _summary?.pendingPayout ?? 0.0;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    // ── Full-screen loading state ────────────────────────────────────────────
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Earnings'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ── Full-screen error state ──────────────────────────────────────────────
    if (_fetchError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Earnings'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(ServioColors.danger),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: ServioColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Data Unavailable',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your earnings could not be loaded.\nCheck your connection and try again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: servio.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _fetchData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: servio.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Normal content ───────────────────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: RefreshIndicator(
        color: servio.accent,
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(_periods.length, (int index) {
                  final active = index == _periodIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _periodIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? servio.accent : servio.backgroundSoft,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Text(
                        _periods[index],
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: active ? Colors.white : servio.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ServioGradients.brand,
                  borderRadius: BorderRadius.circular(ServioRadius.xl),
                  boxShadow: ServioShadows.rest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total Earnings',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 10),
                    _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            '${earnings.toStringAsFixed(0)} EGP',
                            style: theme.textTheme.displayLarge
                                ?.copyWith(color: Colors.white),
                          ),
                    const SizedBox(height: 8),
                    Text(
                      'Pending: ${pending.toStringAsFixed(0)} EGP',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: ServioColors.accentLight),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _showWithdrawComingSoon,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Withdraw'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Overview', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ServioCard(
                  radius: ServioRadius.lg,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const <Widget>[
                      _BarColumn(label: 'Mon', height: 54, active: false),
                      _BarColumn(label: 'Tue', height: 82, active: true),
                      _BarColumn(label: 'Wed', height: 66, active: true),
                      _BarColumn(label: 'Thu', height: 110, active: true),
                      _BarColumn(label: 'Fri', height: 94, active: true),
                      _BarColumn(label: 'Sat', height: 70, active: false),
                      _BarColumn(label: 'Sun', height: 120, active: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Transactions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              if (_recentJobs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No recent transactions.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ),
                )
              else
                ..._recentJobs.take(10).map((job) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TransactionCard(
                        date:
                            '${job.scheduledDate.day.toString().padLeft(2, '0')}/${job.scheduledDate.month.toString().padLeft(2, '0')}/${job.scheduledDate.year}',
                        service: job.serviceName,
                        customer: job.customerName,
                        amount: '${job.totalAmount.toStringAsFixed(0)} EGP',
                        released: true, // simplified
                      ),
                    )),
              const SizedBox(height: 12),
              _PayoutSummaryCard(
                pendingAmount: pending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.label,
    required this.height,
    required this.active,
  });

  final String label;
  final double height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 22,
          height: height,
          decoration: BoxDecoration(
            color: active ? ServioColors.accent : ServioColors.neutralWarm,
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.servio.textSecondary),
        ),
      ],
    );
  }
}

class _PayoutSummaryCard extends StatelessWidget {
  const _PayoutSummaryCard({
    required this.pendingAmount,
  });

  final double pendingAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      backgroundColor: servio.backgroundSoft,
      borderColor: servio.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ServioColors.tint(servio.accent),
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: servio.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Payout summary', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Pending release: ${pendingAmount.toStringAsFixed(0)} EGP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.date,
    required this.service,
    required this.customer,
    required this.amount,
    required this.released,
  });

  final String date;
  final String service;
  final String customer;
  final String amount;
  final bool released;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(date,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: servio.textSecondary)),
                const SizedBox(height: 6),
                Text(service, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(customer,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: servio.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                amount,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: servio.accent),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ServioColors.tint(
                      released ? servio.success : servio.warning),
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  released ? 'Released' : 'Pending',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: released ? servio.success : servio.warning,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
