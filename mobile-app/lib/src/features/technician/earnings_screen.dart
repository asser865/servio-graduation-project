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
    'All Time',
  ];

  static const List<String> _periodApiParams = <String>[
    'week',
    'month',
    'all',
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
      final period = _periodApiParams[_periodIndex];

      final summaryFuture = PaymentsApi(client).getEarnings(period: period);
      final bookingsFuture =
          BookingsApi(client).getWorkerBookings(workerId: workerId);

      final results =
          await Future.wait(<Future<dynamic>>[summaryFuture, bookingsFuture]);
      if (!mounted) return;
      _summary = results[0] as EarningsSummary;

      final jobs = results[1] as List<BackendBooking>;
      // Filter to period window on the client side so the chart stays consistent
      // with the summary figures shown above it.
      final now = DateTime.now();
      final periodStart = switch (_periodIndex) {
        0 => now.subtract(const Duration(days: 7)),  // This Week
        1 => DateTime(now.year, now.month, 1),        // This Month
        _ => DateTime(2000),                          // All Time
      };
      _recentJobs = jobs
          .where((job) =>
              ['completed', 'done'].contains(job.status) &&
              !job.scheduledDate.isBefore(periodStart))
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

  // ── Chart helpers ────────────────────────────────────────────────────────────

  /// Builds the bar chart columns from real [_recentJobs] data.
  ///
  /// - Week  → 7 bars labelled Mon–Sun, showing the current ISO week.
  /// - Month → last 8 bar-buckets (roughly weekly within the month).
  /// - All   → the 6 most active months from the data set.
  List<_BarData> _buildChartBars() {
    if (_recentJobs.isEmpty) {
      // Return flat zero bars as placeholder so the chart axis is visible.
      return switch (_periodIndex) {
        0 => _weekdayLabels()
            .map((l) => _BarData(label: l, amount: 0, active: false))
            .toList(),
        1 => List<_BarData>.generate(
            4,
            (i) => _BarData(label: 'Wk ${i + 1}', amount: 0, active: false)),
        _ => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
            .map((l) => _BarData(label: l, amount: 0, active: false))
            .toList(),
      };
    }

    switch (_periodIndex) {
      // ── This Week ─────────────────────────────────────────────────────────
      case 0:
        final buckets = List<double>.filled(7, 0);
        final today = DateTime.now();
        // ISO weekday: Mon=1 … Sun=7 → index 0–6
        final weekStart =
            today.subtract(Duration(days: today.weekday - 1));
        for (final job in _recentJobs) {
          final diff = job.scheduledDate
              .difference(DateTime(
                  weekStart.year, weekStart.month, weekStart.day))
              .inDays;
          if (diff >= 0 && diff < 7) buckets[diff] += job.totalAmount;
        }
        final todayIdx = today.weekday - 1;
        return List<_BarData>.generate(7, (i) {
          return _BarData(
            label: _weekdayLabels()[i],
            amount: buckets[i],
            active: buckets[i] > 0 || i == todayIdx,
          );
        });

      // ── This Month ────────────────────────────────────────────────────────
      case 1:
        final now = DateTime.now();
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        final weeksCount = (daysInMonth / 7).ceil();
        final buckets = List<double>.filled(weeksCount, 0);
        for (final job in _recentJobs) {
          final d = job.scheduledDate;
          if (d.month == now.month && d.year == now.year) {
            final weekIdx = ((d.day - 1) / 7).floor();
            if (weekIdx < weeksCount) buckets[weekIdx] += job.totalAmount;
          }
        }
        return List<_BarData>.generate(weeksCount, (i) {
          return _BarData(
            label: 'W${i + 1}',
            amount: buckets[i],
            active: buckets[i] > 0,
          );
        });

      // ── All Time ──────────────────────────────────────────────────────────
      default:
        final monthMap = <String, double>{};
        final monthOrder = <String>[];
        for (final job in _recentJobs) {
          final key =
              '${_monthAbbr(job.scheduledDate.month)} ${job.scheduledDate.year}';
          if (!monthMap.containsKey(key)) monthOrder.add(key);
          monthMap[key] = (monthMap[key] ?? 0) + job.totalAmount;
        }
        // Show most recent 6 months, oldest first
        final keys = monthOrder.reversed.take(6).toList().reversed.toList();
        return keys
            .map((k) => _BarData(
                  label: k.split(' ').first, // e.g. 'Jan'
                  amount: monthMap[k]!,
                  active: monthMap[k]! > 0,
                ))
            .toList();
    }
  }

  static List<String> _weekdayLabels() =>
      const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _monthAbbr(int month) => const <String>[
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month - 1];

  // ── Withdraw bottom sheet ─────────────────────────────────────────────────

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
                    onTap: () {
                      if (_periodIndex == index) return;
                      setState(() => _periodIndex = index);
                      _fetchData();
                    },
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
                  child: _recentJobs.isEmpty
                      ? Center(
                          child: Text(
                            'No earnings data for this period.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final bars = _buildChartBars();
                            final maxAmt =
                                bars.map((b) => b.amount).fold(0.0, (a, b) => a > b ? a : b);
                            final maxBarH = constraints.maxHeight - 32.0;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: bars.map((bar) {
                                final ratio = maxAmt > 0 ? bar.amount / maxAmt : 0.0;
                                final barH = (ratio * maxBarH).clamp(8.0, maxBarH);
                                return _BarColumn(
                                  label: bar.label,
                                  height: barH,
                                  active: bar.active,
                                );
                              }).toList(),
                            );
                          },
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
                        paymentStatus: job.paymentStatus,
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

/// Data model for one bar in the earnings chart.
class _BarData {
  const _BarData({
    required this.label,
    required this.amount,
    required this.active,
  });
  final String label;
  final double amount;
  final bool active;
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
    required this.paymentStatus,
  });

  final String date;
  final String service;
  final String customer;
  final String amount;

  /// Backend paymentStatus value: released | cash_settled | held | unpaid | …
  final String paymentStatus;

  bool get _isReleased =>
      paymentStatus == 'released' || paymentStatus == 'cash_settled';

  bool get _isHeld => paymentStatus == 'held';

  String get _badgeLabel => switch (paymentStatus) {
        'released' || 'cash_settled' => 'Released',
        'held' => 'Held',
        'refunded' => 'Refunded',
        'failed' => 'Failed',
        'disputed' => 'Disputed',
        'cash_pending_settlement' => 'Cash Pending',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final badgeColor = _isReleased
        ? servio.success
        : _isHeld
            ? servio.info
            : servio.warning;

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
                  color: ServioColors.tint(badgeColor),
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  _badgeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badgeColor,
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
