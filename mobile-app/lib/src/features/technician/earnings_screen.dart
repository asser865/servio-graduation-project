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
import 'technician_shell.dart';
import 'transaction_details_sheet.dart';

// ── Period ────────────────────────────────────────────────────────────────────

enum _Period { week, month, allTime }

extension _PeriodExt on _Period {
  String get label => switch (this) {
        _Period.week => 'This Week',
        _Period.month => 'This Month',
        _Period.allTime => 'All Time',
      };
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with TickerProviderStateMixin {
  _Period _period = _Period.week;

  EarningsSummary? _summary;
  List<BackendBooking> _allCompleted = <BackendBooking>[];
  bool _loading = true;
  String? _fetchError;
  bool _firstLoad = true;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _s0;
  late final Animation<double> _s1;
  late final Animation<double> _s2;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _s0 = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.00, 0.50, curve: Curves.easeOutCubic),
    );
    _s1 = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
    );
    _s2 = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.40, 1.00, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ─────────────────────────────────────────────────────────

  List<BackendBooking> get _filtered {
    final now = DateTime.now();
    return _allCompleted.where((job) {
      switch (_period) {
        case _Period.week:
          final weekStart =
              DateTime(now.year, now.month, now.day - (now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 7));
          return !job.scheduledDate.isBefore(weekStart) &&
              job.scheduledDate.isBefore(weekEnd);
        case _Period.month:
          return job.scheduledDate.year == now.year &&
              job.scheduledDate.month == now.month;
        case _Period.allTime:
          return true;
      }
    }).toList();
  }

  double get _periodEarnings =>
      _filtered.fold(0.0, (sum, j) => sum + j.totalAmount * 0.95);

  int get _periodJobs => _filtered.length;

  List<({String label, double value})> get _chartData {
    final jobs = _filtered;
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        final buckets = List<double>.filled(7, 0);
        for (final job in jobs) {
          final idx = (job.scheduledDate.weekday - 1).clamp(0, 6);
          buckets[idx] += job.totalAmount * 0.95;
        }
        const labels = <String>[
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun'
        ];
        return List<({String label, double value})>.generate(
            7, (i) => (label: labels[i], value: buckets[i]));

      case _Period.month:
        final buckets = List<double>.filled(4, 0);
        for (final job in jobs) {
          final idx = ((job.scheduledDate.day - 1) ~/ 7).clamp(0, 3);
          buckets[idx] += job.totalAmount * 0.95;
        }
        return List<({String label, double value})>.generate(
            4, (i) => (label: 'W${i + 1}', value: buckets[i]));

      case _Period.allTime:
        final monthLabels = <String>[
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final ordered = <String>[];
        final buckets = <String, double>{};
        for (var i = 5; i >= 0; i--) {
          final m = DateTime(now.year, now.month - i);
          final key = '${m.year}-${m.month}';
          ordered.add(key);
          buckets[key] = 0;
        }
        for (final job in jobs) {
          final key = '${job.scheduledDate.year}-${job.scheduledDate.month}';
          if (buckets.containsKey(key)) {
            buckets[key] = (buckets[key] ?? 0) + job.totalAmount * 0.95;
          }
        }
        return ordered.map((key) {
          final month = int.parse(key.split('-')[1]);
          return (label: monthLabels[month - 1], value: buckets[key] ?? 0);
        }).toList();
    }
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

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

      final results = await Future.wait(<Future<dynamic>>[
        PaymentsApi(client).getEarnings(),
        BookingsApi(client).getWorkerBookings(workerId: workerId),
      ]);

      if (!mounted) return;
      final summary = results[0] as EarningsSummary;
      final all = results[1] as List<BackendBooking>;
      final completed = all
          .where((j) => <String>[
                'completed',
                'done',
                'awaiting_customer_confirmation',
              ].contains(j.status))
          .toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      setState(() {
        _summary = summary;
        _allCompleted = completed;
        _loading = false;
      });

      if (_firstLoad) {
        _firstLoad = false;
        _entranceCtrl.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fetchError = 'Could not load earnings data.';
        });
      }
    }
  }

  // ── Withdraw sheet ────────────────────────────────────────────────────────

  void _showWithdrawSheet() {
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
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: servio.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Instant payouts to your bank or wallet will be available '
                  'in an upcoming release. Your earnings are safe and '
                  'accumulating until then.',
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    if (_loading) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_fetchError != null) {
      return Scaffold(
        appBar: _appBar(context),
        body: _ErrorBody(error: _fetchError!, onRetry: _fetchData),
      );
    }

    final earnings = _periodEarnings;
    final jobs = _periodJobs;
    final pending = _summary?.pendingPayout ?? 0.0;
    final chart = _chartData;

    return Scaffold(
      appBar: _appBar(context),
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
              // ── Period filter ──────────────────────────────────────────────
              _FadeSlide(
                animation: _s0,
                child: _PeriodRow(
                  current: _period,
                  onSelect: (p) => setState(() => _period = p),
                ),
              ),
              const SizedBox(height: 20),

              // ── Earnings card ──────────────────────────────────────────────
              _FadeSlide(
                animation: _s0,
                child: _EarningsCard(
                  period: _period,
                  earnings: earnings,
                  jobs: jobs,
                  pending: pending,
                  onWithdraw: _showWithdrawSheet,
                ),
              ),
              const SizedBox(height: 24),

              // ── Bar chart ─────────────────────────────────────────────────
              _FadeSlide(
                animation: _s1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Overview', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ServioCard(
                      radius: ServioRadius.lg,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _BarChart(data: chart),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Transactions ──────────────────────────────────────────────
              _FadeSlide(
                animation: _s2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Transactions', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 14),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No transactions for this period.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._filtered.take(15).map((job) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TransactionCard(
                              job: job,
                              onTap: () => showTransactionDetailsSheet(
                                context,
                                job: job,
                                onReportSubmitted: _fetchData,
                              ),
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Payout summary ────────────────────────────────────────────
              _FadeSlide(
                animation: _s2,
                child: _PayoutSummaryCard(
                  pending: pending,
                  method: _summary?.payoutMethod ?? 'bank',
                  schedule: _summary?.payoutSchedule ?? 'weekly',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) => AppBar(
        title: const Text('Earnings'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _BackIconButton(onTap: _openDashboard),
          ),
        ),
      );

  void _openDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const TechnicianShell()),
      (Route<dynamic> route) => false,
    );
  }
}

class _BackIconButton extends StatelessWidget {
  const _BackIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Semantics(
      button: true,
      label: 'Back to dashboard',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: servio.border),
              boxShadow: ServioShadows.rest,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: servio.accent,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fade + slide wrapper ──────────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Period row ────────────────────────────────────────────────────────────────

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.current, required this.onSelect});

  final _Period current;
  final ValueChanged<_Period> onSelect;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _Period.values.map((p) {
        final active = p == current;
        return GestureDetector(
          onTap: () => onSelect(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? servio.accent : servio.backgroundSoft,
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
            child: Text(
              p.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: active ? Colors.white : servio.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Earnings card ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.period,
    required this.earnings,
    required this.jobs,
    required this.pending,
    required this.onWithdraw,
  });

  final _Period period;
  final double earnings;
  final int jobs;
  final double pending;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: ServioGradients.brand,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${period.label} Earnings',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            key: ValueKey<double>(earnings),
            tween: Tween<double>(begin: 0, end: earnings),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double v, Widget? _) => Text(
              '${v.toStringAsFixed(0)} EGP',
              style: theme.textTheme.displayLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TweenAnimationBuilder<double>(
                key: ValueKey<double>(jobs.toDouble()),
                tween: Tween<double>(begin: 0, end: jobs.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double v, Widget? _) => Text(
                  '${v.toInt()} jobs',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
              if (pending > 0) ...<Widget>[
                Text(
                  '  ·  ',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.5)),
                ),
                Text(
                  'Pending: ${pending.toStringAsFixed(0)} EGP',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: ServioColors.accentLight),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onWithdraw,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});

  final List<({String label, double value})> data;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final maxVal = data.fold(0.0, (m, d) => d.value > m ? d.value : m);
    const maxBarH = 100.0;

    if (data.every((d) => d.value == 0)) {
      return SizedBox(
        height: maxBarH + 40,
        child: Center(
          child: Text(
            'No data for this period',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: maxBarH + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: data.map((d) {
          final fraction = maxVal > 0 ? d.value / maxVal : 0.0;
          final barH = (fraction * maxBarH).clamp(4.0, maxBarH);
          final isTop = fraction == 1.0 && maxVal > 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    height: barH,
                    decoration: BoxDecoration(
                      color: isTop
                          ? servio.accent
                          : servio.accent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(ServioRadius.sm),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: servio.textSecondary,
                          fontSize: 10,
                        ),
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.job, this.onTap});

  final BackendBooking job;
  final VoidCallback? onTap;

  static ({String label, Color color, Color bg}) _statusBadge(
      String status, ServioThemeExtension servio) {
    switch (status) {
      case 'completed':
      case 'done':
        return (
          label: 'Released',
          color: servio.success,
          bg: ServioColors.tint(servio.success),
        );
      case 'awaiting_customer_confirmation':
        return (
          label: 'Confirming',
          color: servio.warning,
          bg: ServioColors.tint(servio.warning),
        );
      case 'pending_admin_review':
        return (
          label: 'Under Review',
          color: servio.warning,
          bg: ServioColors.tint(servio.warning),
        );
      default:
        return (
          label: 'Pending',
          color: servio.textSecondary,
          bg: ServioColors.tint(servio.textSecondary),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final d = job.scheduledDate;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final badge = _statusBadge(job.status, servio);
    final net = job.totalAmount * 0.95;

    return ServioCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(date,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary)),
                const SizedBox(height: 6),
                Text(job.serviceName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(job.customerName,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${net.toStringAsFixed(0)} EGP',
                style:
                    theme.textTheme.titleMedium?.copyWith(color: servio.accent),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badge.bg,
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  badge.label,
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: badge.color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Payout summary card ───────────────────────────────────────────────────────

class _PayoutSummaryCard extends StatelessWidget {
  const _PayoutSummaryCard({
    required this.pending,
    required this.method,
    required this.schedule,
  });

  final double pending;
  final String method;
  final String schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final methodLabel = method == 'wallet' ? 'Wallet' : 'Bank Transfer';
    final scheduleLabel = schedule == 'monthly' ? 'Monthly' : 'Weekly';

    return ServioCard(
      backgroundColor: servio.backgroundSoft,
      borderColor: servio.border,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 22, color: servio.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Payout Summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Pending: ${pending.toStringAsFixed(0)} EGP  ·  $methodLabel  ·  $scheduleLabel',
                  style: theme.textTheme.bodySmall
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

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    return Center(
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
              child: const Icon(Icons.wifi_off_rounded,
                  color: ServioColors.danger, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Data Unavailable',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your earnings could not be loaded.\nCheck your connection and try again.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
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
    );
  }
}
