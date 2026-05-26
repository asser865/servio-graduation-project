import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'job_details_screen.dart';
import 'widgets/duration_estimation_sheet.dart';

class JobQueueScreen extends StatefulWidget {
  const JobQueueScreen({
    super.key,
    this.autoRefreshInterval = const Duration(seconds: 20),
  });

  final Duration? autoRefreshInterval;

  @override
  State<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends State<JobQueueScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  bool _historyExpanded = false;
  static const List<String> _tabs = <String>[
    'Pending',
    'Confirmed',
    'In Progress',
    'Completed',
    'Cancelled',
    'Rejected',
  ];
  static const List<int> _primaryTabs = <int>[0, 1, 2];
  static const List<int> _historyTabs = <int>[3, 4, 5];

  List<BackendBooking> _jobs = [];
  bool _loading = true;
  String? _error;
  bool _loadedOnce = false;
  bool? _pageActive;
  Timer? _autoRefreshTimer;
  Future<void>? _activeFetch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_fetchJobs());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = ServioTabShell.isPageActiveOf(context);
    if (_pageActive == active) return;

    final wasActive = _pageActive;
    _pageActive = active;

    if (active) {
      _startAutoRefresh();
      if (wasActive == false && _loadedOnce) {
        unawaited(_fetchJobs(silent: true));
      }
    } else {
      _stopAutoRefresh();
    }
  }

  @override
  void didUpdateWidget(covariant JobQueueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoRefreshInterval != oldWidget.autoRefreshInterval &&
        _pageActive != false) {
      _startAutoRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pageActive != false) {
      unawaited(_fetchJobs(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    super.dispose();
  }

  Future<void> _fetchJobs({bool silent = false}) {
    final activeFetch = _activeFetch;
    if (activeFetch != null) return activeFetch;

    final fetch = _fetchJobsNow(silent: silent);
    _activeFetch = fetch.whenComplete(() {
      _activeFetch = null;
    });
    return _activeFetch!;
  }

  Future<void> _fetchJobsNow({required bool silent}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final client = context.read<ApiClient>();
    final session = context.read<SessionProvider>();
    var workerId = session.account?.id.trim() ?? '';

    if (workerId.isEmpty || session.account?.role != UserRole.technician) {
      final profileError = await session.loadCurrentWorkerProfile();
      if (!mounted) return;
      if (profileError != null) {
        _handleFetchError(profileError, silent: silent);
        return;
      }
      workerId = session.account?.id.trim() ?? '';
    }

    if (workerId.isEmpty || session.account?.role != UserRole.technician) {
      _handleFetchError(
        'Log in as a technician to view assigned jobs.',
        silent: silent,
      );
      return;
    }

    try {
      final jobs = await BookingsApi(client).getWorkerBookings(
        workerId: workerId,
      );
      final assignedJobs =
          jobs.where((job) => _isAssignedToWorker(job, workerId)).toList();
      if (!mounted) return;
      setState(() {
        _jobs = assignedJobs;
        _tabIndex = _firstTabWithJobs(assignedJobs) ?? _tabIndex;
        _error = null;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      _handleFetchError(e.toString(), silent: silent);
    }
  }

  void _handleFetchError(String message, {required bool silent}) {
    if (silent && _loadedOnce) return;

    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    final interval = widget.autoRefreshInterval;
    if (interval == null) return;

    _autoRefreshTimer = Timer.periodic(interval, (_) {
      if (!mounted || _pageActive == false) return;
      unawaited(_fetchJobs(silent: true));
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  List<BackendBooking> _jobsForTab(int tab) {
    return _jobsForTabFrom(_jobs, tab);
  }

  List<BackendBooking> _jobsForTabFrom(List<BackendBooking> jobs, int tab) {
    const statusMap = <int, Set<String>>{
      0: <String>{'pending'},
      1: <String>{'accepted', 'confirmed', 'scheduled'},
      2: <String>{
        'arrived',
        'en_route',
        'enroute',
        'in_progress',
        'inprogress',
        'active',
        'started',
      },
      3: <String>{
        'awaiting_customer_confirmation',
        'pending_admin_review',
        'completed',
        'done',
      },
      4: <String>{
        'cancelled',
        'canceled',
        'cancelled_by_customer',
        'canceled_by_customer',
        'cancelled_by_provider',
        'canceled_by_provider',
        'cancelled_by_worker',
        'canceled_by_worker',
      },
      5: <String>{'rejected', 'declined'},
    };
    final statuses = statusMap[tab] ?? const <String>{};
    return jobs
        .where((job) => statuses.contains(_normalizedStatus(job.status)))
        .toList();
  }

  int? _firstTabWithJobs(List<BackendBooking> jobs) {
    if (_jobsForTabFrom(jobs, _tabIndex).isNotEmpty) return _tabIndex;
    for (var index = 0; index < _tabs.length; index += 1) {
      if (_jobsForTabFrom(jobs, index).isNotEmpty) return index;
    }
    return null;
  }

  Future<void> _acceptJob(BackendBooking job) async {
    final durationMin = await showDurationEstimationSheet(context);
    if (durationMin == null) return; // User dismissed

    if (!mounted) return;
    final client = context.read<ApiClient>();

    // Optimistic update
    final originalJobs = List<BackendBooking>.from(_jobs);
    final idx = _jobs.indexWhere((j) => j.id == job.id);
    if (idx != -1) {
      setState(() {
        _jobs = List<BackendBooking>.from(_jobs)
          ..[idx] = _jobs[idx].copyWith(status: 'accepted');
        _tabIndex = _firstTabWithJobs(_jobs) ?? _tabIndex;
      });
    }
    try {
      await BookingsApi(client).acceptBooking(
        job.id,
        estimatedDurationMin: durationMin,
      );
      if (mounted) await _fetchJobs(silent: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jobs = originalJobs;
        _tabIndex = _firstTabWithJobs(originalJobs) ?? _tabIndex;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept job. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _declineJob(BackendBooking job) async {
    final reason = await _showDeclineReasonSheet();
    if (reason == null) return; // User dismissed

    if (!mounted) return;
    final client = context.read<ApiClient>();

    // Optimistic update
    final originalJobs = List<BackendBooking>.from(_jobs);
    final idx = _jobs.indexWhere((j) => j.id == job.id);
    if (idx != -1) {
      setState(() {
        _jobs = List<BackendBooking>.from(_jobs)
          ..[idx] = _jobs[idx].copyWith(status: 'rejected');
        _tabIndex = _firstTabWithJobs(_jobs) ?? _tabIndex;
      });
    }
    try {
      await BookingsApi(client).updateStatus(job.id, 'rejected', reason: reason);
      if (mounted) await _fetchJobs(silent: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jobs = originalJobs;
        _tabIndex = _firstTabWithJobs(originalJobs) ?? _tabIndex;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not decline job. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> _showDeclineReasonSheet() async {
    String? selectedReason;
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Decline Job',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...([
                  "I'm busy at this time",
                  'Location is too far',
                  'Outside my skill set',
                  'Personal emergency',
                  'Other',
                ].map((reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (v) => setS(() => selectedReason = v),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ))),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () => Navigator.of(ctx).pop(selectedReason),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Queue'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.lg),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  const spacing = 6.0;
                  final tabWidth = (constraints.maxWidth - spacing * 2) / 3;

                  return Row(
                    children:
                        List<Widget>.generate(_primaryTabs.length, (int slot) {
                      final int index = _primaryTabs[slot];
                      final bool active = index == _tabIndex;
                      final String count = _jobsForTab(index).length.toString();
                      final Color tabColor = _tabColor(index, servio);

                      return Padding(
                        padding: EdgeInsets.only(
                          right: slot == _primaryTabs.length - 1 ? 0 : spacing,
                        ),
                        child: SizedBox(
                          width: tabWidth,
                          child: _PrimaryTabChip(
                            label: _tabs[index],
                            count: count,
                            tabColor: tabColor,
                            active: active,
                            onTap: () => setState(() => _tabIndex = index),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _HistorySection(
              tabs: _tabs,
              historyTabs: _historyTabs,
              activeIndex: _tabIndex,
              expanded: _historyExpanded,
              onToggle: () =>
                  setState(() => _historyExpanded = !_historyExpanded),
              onSelect: (int idx) => setState(() => _tabIndex = idx),
              countFor: (int idx) => _jobsForTab(idx).length,
              colorFor: (int idx) => _tabColor(idx, servio),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Something went wrong',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _fetchJobs,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final filteredJobs = _jobsForTab(_tabIndex);
                            if (filteredJobs.isEmpty) {
                              return Center(
                                child: Text(
                                  _jobs.isEmpty
                                      ? 'No jobs assigned to you yet.'
                                      : 'No ${_tabs[_tabIndex].toLowerCase()} jobs assigned to you.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: servio.textSecondary),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: EdgeInsets.only(bottom: bottomInset),
                              itemCount: filteredJobs.length,
                              separatorBuilder:
                                  (BuildContext context, int index) =>
                                      const SizedBox(height: 12),
                              itemBuilder: (BuildContext context, int index) {
                                final job = filteredJobs[index];
                                return _JobCard(
                                  job: job,
                                  onOpen: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            JobDetailsScreen(jobId: job.id),
                                      ),
                                    );
                                  },
                                  onAccept: _tabIndex == 0
                                      ? () => _acceptJob(job)
                                      : null,
                                  onDecline: _tabIndex == 0
                                      ? () => _declineJob(job)
                                      : null,
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onOpen,
    this.onAccept,
    this.onDecline,
  });

  final BackendBooking job;
  final VoidCallback onOpen;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  ServioStatusChipType _chipType(String status) {
    switch (_normalizedStatus(status)) {
      case 'pending':
        return ServioStatusChipType.warning;
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        return ServioStatusChipType.info;
      case 'arrived':
      case 'en_route':
      case 'enroute':
      case 'in_progress':
      case 'inprogress':
      case 'active':
      case 'started':
        return ServioStatusChipType.info;
      case 'completed':
      case 'done':
      case 'awaiting_customer_confirmation':
      case 'pending_admin_review':
        return ServioStatusChipType.success;
      case 'cancelled':
      case 'canceled':
      case 'cancelled_by_customer':
      case 'canceled_by_customer':
      case 'cancelled_by_provider':
      case 'canceled_by_provider':
      case 'cancelled_by_worker':
      case 'canceled_by_worker':
      case 'rejected':
      case 'declined':
        return ServioStatusChipType.danger;
      default:
        return ServioStatusChipType.warning;
    }
  }

  String _chipLabel(String status) {
    switch (_normalizedStatus(status)) {
      case 'pending':
        return 'Pending';
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        return 'Confirmed';
      case 'arrived':
        return 'Arrived';
      case 'en_route':
      case 'enroute':
        return 'En Route';
      case 'in_progress':
      case 'inprogress':
      case 'active':
      case 'started':
        return 'In Progress';
      case 'completed':
      case 'done':
        return 'Completed';
      case 'awaiting_customer_confirmation':
        return 'Awaiting Customer';
      case 'pending_admin_review':
        return 'Pending Review';
      case 'cancelled':
      case 'canceled':
      case 'cancelled_by_customer':
      case 'canceled_by_customer':
      case 'cancelled_by_provider':
      case 'canceled_by_provider':
      case 'cancelled_by_worker':
      case 'canceled_by_worker':
        return 'Cancelled';
      case 'rejected':
      case 'declined':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.warm,
                    shape: BoxShape.circle,
                    border: Border.all(color: servio.accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      job.serviceName.isNotEmpty
                          ? job.serviceName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(job.serviceName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      if (job.customerName.isNotEmpty)
                        Text(
                          job.customerName,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                    ],
                  ),
                ),
                ServioStatusChip(
                  label: _chipLabel(job.status),
                  type: _chipType(job.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${job.addressCity} • EGP ${job.totalAmount.toStringAsFixed(0)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 14),
            if (onAccept != null || onDecline != null)
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAccept,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: servio.success),
                        foregroundColor: servio.success,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: servio.danger),
                        foregroundColor: servio.danger,
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: onOpen,
                  child: const Text('View Details'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _tabColor(int index, ServioThemeExtension servio) {
  return switch (index) {
    0 => servio.warning,
    3 => servio.success,
    4 || 5 => servio.danger,
    _ => servio.info,
  };
}

bool _isAssignedToWorker(BackendBooking job, String workerId) {
  final bookingWorkerId = job.workerId.trim();
  return bookingWorkerId == workerId;
}

String _normalizedStatus(String status) =>
    status.trim().toLowerCase().replaceAll('-', '_');

class _PrimaryTabChip extends StatelessWidget {
  const _PrimaryTabChip({
    required this.label,
    required this.count,
    required this.tabColor,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String count;
  final Color tabColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.curve,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(ServioRadius.full),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? servio.accent : servio.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: ServioColors.tint(tabColor),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Text(
                count,
                style: theme.textTheme.labelSmall?.copyWith(color: tabColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.tabs,
    required this.historyTabs,
    required this.activeIndex,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
    required this.countFor,
    required this.colorFor,
  });

  final List<String> tabs;
  final List<int> historyTabs;
  final int activeIndex;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;
  final int Function(int index) countFor;
  final Color Function(int index) colorFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final int total =
        historyTabs.fold<int>(0, (int sum, int i) => sum + countFor(i));
    final bool historyActive = historyTabs.contains(activeIndex);
    final bool open = expanded || historyActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: servio.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'History',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: servio.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.textSecondary),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Text(
                    '$total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: servio.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: ServioMotion.normal,
                  curve: ServioMotion.spring,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: servio.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int idx in historyTabs)
                  _HistoryChip(
                    label: tabs[idx],
                    count: countFor(idx),
                    color: colorFor(idx),
                    active: idx == activeIndex,
                    onTap: () => onSelect(idx),
                  ),
              ],
            ),
          ),
          crossFadeState:
              open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: ServioMotion.normal,
          sizeCurve: ServioMotion.spring,
        ),
      ],
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ServioColors.tint(color) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(
            color: active ? color : servio.border,
            width: active ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? color : servio.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: ServioColors.tint(color),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
