import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/payments_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'technician_shell.dart';
import 'transaction_details_sheet.dart';

// ── Stitch Design Token Colors ──────────────────────────────────────────────

const _kNavy = Color(0xFF1A1D23);
const _kTaupe = Color(0xFF9A8C73);
const _kWarm = Color(0xFFF3EDE7);
const _kSurface = Color(0xFFFBF9F6);
const _kMuted = Color(0xFF6B6560);
const _kBorder = Color(0xFFE4E2DF);
const _kWhite = Colors.white;

// ── Period ────────────────────────────────────────────────────────────────────

enum _Period { week, month, allTime }

extension _PeriodExt on _Period {
  String get label => switch (this) {
        _Period.week => 'Week',
        _Period.month => 'Month',
        _Period.allTime => 'All',
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
      duration: const Duration(milliseconds: 900),
    );
    _s0 = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.00, 0.50, curve: ServioMotion.spring),
    );
    _s1 = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.20, 0.70, curve: ServioMotion.spring),
    );
    _s2 = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.40, 1.00, curve: ServioMotion.spring),
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

  double get _periodEarnings {
    if (_summary != null) {
      switch (_period) {
        case _Period.week:
          return _filtered.fold(0.0, (sum, j) => sum + j.totalAmount * 0.95);
        case _Period.month:
          return _summary!.thisMonthEarnings;
        case _Period.allTime:
          return _summary!.totalEarnings;
      }
    }
    return _filtered.fold(0.0, (sum, j) => sum + j.totalAmount * 0.95);
  }

  int get _periodJobs {
    if (_summary != null) {
      switch (_period) {
        case _Period.week:
          return _filtered.length;
        case _Period.month:
          return _filtered.length;
        case _Period.allTime:
          return _summary!.completedJobs;
      }
    }
    return _filtered.length;
  }

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
          'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
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
        const monthLabels = <String>[
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
          return (
            label: monthLabels[month - 1],
            value: buckets[key] ?? 0,
          );
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
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
      ),
      builder: (BuildContext ctx) {
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
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kWarm,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 30,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Withdrawals Coming Soon',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                        fontFamily: 'Poppins',
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Instant payouts to your bank or wallet will be available '
                  'in an upcoming release. Your earnings are safe and '
                  'accumulating until then.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: _kMuted,
                        height: 1.5,
                        fontFamily: 'Inter',
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: _kWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
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
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: _kSurface,
        appBar: _buildAppBar(context),
        body: const Center(
          child: CircularProgressIndicator(color: _kNavy),
        ),
      );
    }

    if (_fetchError != null) {
      return Scaffold(
        backgroundColor: _kSurface,
        appBar: _buildAppBar(context),
        body: _ErrorBody(error: _fetchError!, onRetry: _fetchData),
      );
    }

    final earnings = _periodEarnings;
    final jobs = _periodJobs;
    final available = _summary?.availableBalance ?? 0.0;
    final completedTotal = _summary?.completedJobs ?? 0;
    final chart = _chartData;
    final transactions = _filtered.take(10).toList();

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        color: _kNavy,
        backgroundColor: _kWarm,
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
              // ── Balance card ──────────────────────────────────────────────
              _FadeSlide(
                animation: _s0,
                child: _BalanceCard(
                  available: available,
                  onWithdraw: _showWithdrawSheet,
                ),
              ),
              const SizedBox(height: 16),

              // ── Period filter + Chart ─────────────────────────────────────
              _FadeSlide(
                animation: _s1,
                child: _ChartCard(
                  period: _period,
                  data: chart,
                  onPeriodChanged: (p) => setState(() => _period = p),
                ),
              ),
              const SizedBox(height: 16),

              // ── Quick stats ────────────────────────────────────────────────
              _FadeSlide(
                animation: _s1,
                child: _QuickStatsRow(
                  jobs: jobs,
                  totalCompleted: completedTotal,
                  periodEarnings: earnings,
                ),
              ),
              const SizedBox(height: 16),

              // ── Transactions ──────────────────────────────────────────────
              _FadeSlide(
                animation: _s2,
                child: _TransactionSection(
                  transactions: transactions,
                  allTransactions: _filtered,
                  onTap: (job) => showTransactionDetailsSheet(
                    context,
                    job: job,
                    onReportSubmitted: _fetchData,
                  ),
                  onViewAll: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _AllTransactionsScreen(
                          transactions: _filtered,
                          onTap: (job) => showTransactionDetailsSheet(
                            context,
                            job: job,
                            onReportSubmitted: _fetchData,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _BackIconButton(onTap: _openDashboard),
        ),
      ),
      leadingWidth: 64,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Text(
            'Earnings Overview',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kNavy,
            ),
          ),
          Text(
            'Track your performance and manage payouts.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _openDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const TechnicianShell()),
      (Route<dynamic> route) => false,
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackIconButton extends StatelessWidget {
  const _BackIconButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kWhite,
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder),
          boxShadow: ServioShadows.rest,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back_rounded, size: 20, color: _kNavy),
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
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.available, required this.onWithdraw});
  final double available;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.12),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Decorative circle
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _kTaupe.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Decorative wallet icon
          Positioned(
            right: -4,
            bottom: -4,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 96,
              color: _kWhite.withValues(alpha: 0.06),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Available for Withdrawal',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color.fromRGBO(243, 237, 231, 0.8),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                key: ValueKey<double>(available),
                tween: Tween<double>(begin: 0, end: available),
                duration: const Duration(milliseconds: 900),
                curve: ServioMotion.spring,
                builder: (BuildContext context, double v, Widget? _) => Text(
                  '${v.toStringAsFixed(0)} EGP',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: _kWhite,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onWithdraw,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _kWhite,
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.10),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.account_balance_outlined,
                          size: 18, color: _kTaupe),
                      SizedBox(width: 8),
                      Text(
                        'Withdraw Funds',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kNavy,
                        ),
                      ),
                    ],
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

// ── Chart card ────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.period,
    required this.data,
    required this.onPeriodChanged,
  });
  final _Period period;
  final List<({String label, double value})> data;
  final ValueChanged<_Period> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kWhite.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(
          color: _kTaupe.withValues(alpha: 0.15),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Weekly Performance',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kNavy,
                ),
              ),
              // Period toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EEEB),
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                ),
                child: Row(
                  children: _Period.values.map((p) {
                    final active = p == period;
                    return GestureDetector(
                      onTap: () => onPeriodChanged(p),
                      child: AnimatedContainer(
                        duration: ServioMotion.fast,
                        curve: ServioMotion.spring,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? _kWhite : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.sm - 2),
                          boxShadow: active
                              ? const <BoxShadow>[
                                  BoxShadow(
                                    color: Color.fromRGBO(26, 29, 35, 0.08),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? _kNavy : _kMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bar chart
          _BarChart(data: data),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _LegendDot(color: _kNavy, label: 'Current / Peak'),
              const SizedBox(width: 20),
              _LegendDot(
                  color: _kTaupe.withValues(alpha: 0.45), label: 'Completed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<({String label, double value})> data;

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold(0.0, (m, d) => d.value > m ? d.value : m);
    const maxBarH = 110.0;

    if (data.every((d) => d.value == 0)) {
      return SizedBox(
        height: maxBarH + 44,
        child: const Center(
          child: Text(
            'No data for this period',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: _kMuted,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: maxBarH + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: data.map((d) {
          final fraction = maxVal > 0 ? d.value / maxVal : 0.0;
          final barH = fraction > 0
              ? (fraction * maxBarH).clamp(8.0, maxBarH)
              : 0.0;
          final isPeak = fraction == 1.0 && maxVal > 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (d.value > 0)
                    Container(
                      width: double.infinity,
                      height: maxBarH,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        height: barH,
                        decoration: BoxDecoration(
                          color: isPeak
                              ? _kNavy.withValues(alpha: 0.85)
                              : _kTaupe.withValues(alpha: 0.40),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(height: maxBarH),
                  const SizedBox(height: 8),
                  Text(
                    d.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight:
                          isPeak ? FontWeight.w700 : FontWeight.w400,
                      color: isPeak ? _kNavy : _kMuted,
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

// ── Quick stats row ───────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.jobs,
    required this.totalCompleted,
    required this.periodEarnings,
  });
  final int jobs;
  final int totalCompleted;
  final double periodEarnings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            icon: Icons.work_history_outlined,
            label: 'Jobs Completed',
            value: '$jobs',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            label: 'Period Earnings',
            value: '${periodEarnings.toStringAsFixed(0)} EGP',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.12)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: _kWarm,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: _kNavy),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _kMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction section ───────────────────────────────────────────────────────

class _TransactionSection extends StatelessWidget {
  const _TransactionSection({
    required this.transactions,
    required this.allTransactions,
    required this.onTap,
    required this.onViewAll,
  });
  final List<BackendBooking> transactions;
  final List<BackendBooking> allTransactions;
  final void Function(BackendBooking) onTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.12)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kNavy,
                ),
              ),
              if (allTransactions.length > 10)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No transactions for this period.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: _kMuted,
                  ),
                ),
              ),
            )
          else
            ...transactions.map((job) => _TransactionItem(
                  job: job,
                  onTap: () => onTap(job),
                )),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  const _TransactionItem({required this.job, required this.onTap});
  final BackendBooking job;
  final VoidCallback onTap;

  static IconData _serviceIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('electric') || n.contains('panel') || n.contains('wir')) {
      return Icons.electrical_services_outlined;
    }
    if (n.contains('plumb') || n.contains('pipe') || n.contains('sink') ||
        n.contains('leak')) {
      return Icons.plumbing_outlined;
    }
    if (n.contains('ac') || n.contains('hvac') || n.contains('air') ||
        n.contains('cool') || n.contains('heat')) {
      return Icons.hvac_outlined;
    }
    if (n.contains('paint')) return Icons.format_paint_outlined;
    if (n.contains('clean')) return Icons.cleaning_services_outlined;
    if (n.contains('lock') || n.contains('security')) {
      return Icons.lock_outline_rounded;
    }
    return Icons.home_repair_service_outlined;
  }

  static ({String label, Color fg, Color bg}) _badge(String status) {
    switch (status) {
      case 'completed':
      case 'done':
        return (
          label: 'Released',
          fg: const Color(0xFF2E7D32),
          bg: const Color(0xFFE8F5E9),
        );
      case 'awaiting_customer_confirmation':
        return (
          label: 'Confirming',
          fg: const Color(0xFFE65100),
          bg: const Color(0xFFFFF3E0),
        );
      default:
        return (
          label: 'Pending',
          fg: _kMuted,
          bg: const Color(0xFFF0EEEB),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = job.scheduledDate;
    final now = DateTime.now();
    String dateLabel;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      dateLabel = 'Today';
    } else if (d.year == now.year &&
        d.month == now.month &&
        d.day == now.day - 1) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = '${_monthLabel(d.month)} ${d.day}';
    }

    final badge = _badge(job.status);
    final net = job.totalAmount * 0.95;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ServioRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EEEB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _serviceIcon(job.serviceName),
                size: 20,
                color: _kNavy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    job.serviceName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '+${net.toStringAsFixed(0)} EGP',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badge.bg,
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Text(
                    badge.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badge.fg,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _monthLabel(int m) => const <String>[
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}

// ── All transactions screen ───────────────────────────────────────────────────

class _AllTransactionsScreen extends StatelessWidget {
  const _AllTransactionsScreen({
    required this.transactions,
    required this.onTap,
  });
  final List<BackendBooking> transactions;
  final void Function(BackendBooking) onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kNavy,
          ),
        ),
        backgroundColor: _kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
      ),
      body: transactions.isEmpty
          ? const Center(
              child: Text(
                'No transactions yet.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: _kMuted,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(ServioSpacing.screenPadding),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: _kBorder,
              ),
              itemBuilder: (_, i) => _TransactionItem(
                job: transactions[i],
                onTap: () => onTap(transactions[i]),
              ),
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
                color: const Color(0xFFFFDAD6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFBA1A1A),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Data Unavailable',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: _kMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: _kWhite,
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
