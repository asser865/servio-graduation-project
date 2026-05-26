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
import '../../design_system/widgets/servio_tab_shell.dart';
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
  int _historyFilterIndex = -1; // -1: All History, 3: Completed, 4: Cancelled, 5: Rejected

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

  List<BackendBooking> _activeScheduleJobs() {
    return [
      ..._jobsForTab(1),
      ..._jobsForTab(2),
    ]..sort((a, b) {
      final aInProgress = _isInProgress(a);
      final bInProgress = _isInProgress(b);
      if (aInProgress && !bInProgress) return -1;
      if (!aInProgress && bInProgress) return 1;

      final dateCompare = a.scheduledDate.compareTo(b.scheduledDate);
      if (dateCompare != 0) return dateCompare;
      return a.scheduledTime.compareTo(b.scheduledTime);
    });
  }

  bool _isInProgress(BackendBooking job) {
    const statuses = <String>{
      'arrived',
      'en_route',
      'enroute',
      'in_progress',
      'inprogress',
      'active',
      'started',
    };
    return statuses.contains(_normalizedStatus(job.status));
  }

  List<BackendBooking> _historyJobs() {
    if (_historyFilterIndex == -1) {
      return [
        ..._jobsForTab(3),
        ..._jobsForTab(4),
        ..._jobsForTab(5),
      ]..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    }
    return _jobsForTab(_historyFilterIndex);
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${weekdays[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}';
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
      });
    }
    try {
      await BookingsApi(client).updateStatus(job.id, 'rejected', reason: reason);
      if (mounted) await _fetchJobs(silent: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jobs = originalJobs;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navyAnchor = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23);
    final taupeAccent = const Color(0xFF9A8C73);

    final pendingJobs = _jobsForTab(0);
    final activeSchedule = _activeScheduleJobs();
    final historyJobsList = _historyJobs();

    final activeRemainingCount = pendingJobs.length + activeSchedule.length;
    final dynamicSubtitle =
        '${_formatCurrentDate()} • $activeRemainingCount ${activeRemainingCount == 1 ? 'Job' : 'Jobs'} Remaining';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Portal'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: navyAnchor,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: navyAnchor,
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchJobs(silent: false),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height - 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Something went wrong',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => _fetchJobs(silent: false),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: ServioSpacing.screenPadding,
                      right: ServioSpacing.screenPadding,
                      top: 24,
                      bottom: bottomInset + 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // ── Page Title & Stats ─────────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Job Queue',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: navyAnchor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dynamicSubtitle,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: servio.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── New Requests (Pending) ──────────────────────────────
                        _buildSectionHeader(
                          title: 'New Requests',
                          badgeCount: pendingJobs.length,
                          badgeLabel: 'Pending',
                          taupeAccent: taupeAccent,
                        ),
                        const SizedBox(height: 12),
                        if (pendingJobs.isEmpty)
                          _buildEmptyCard(
                            icon: Icons.assignment_late_outlined,
                            message: 'No new requests pending.',
                            taupeAccent: taupeAccent,
                            theme: theme,
                          )
                        else
                          ...pendingJobs.map((job) => _buildNewRequestCard(
                                job: job,
                                theme: theme,
                                isDark: isDark,
                                navyAnchor: navyAnchor,
                                taupeAccent: taupeAccent,
                                servio: servio,
                              )),
                        const SizedBox(height: 28),

                        // ── Today's Schedule ────────────────────────────────────
                        Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: navyAnchor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (activeSchedule.isEmpty)
                          _buildEmptyCard(
                            icon: Icons.calendar_today_outlined,
                            message: 'No jobs scheduled for today.',
                            taupeAccent: taupeAccent,
                            theme: theme,
                          )
                        else
                          ...activeSchedule.map((job) => _buildScheduleCard(
                                job: job,
                                theme: theme,
                                isDark: isDark,
                                navyAnchor: navyAnchor,
                                taupeAccent: taupeAccent,
                                servio: servio,
                              )),
                        const SizedBox(height: 28),

                        // ── Job History ─────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Job History',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: navyAnchor,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _historyFilterIndex = -1);
                              },
                              child: Text(
                                'View All',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  color: taupeAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Horizontal scroll chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildHistoryFilterChip(
                                label: 'All History',
                                isSelected: _historyFilterIndex == -1,
                                onTap: () => setState(() => _historyFilterIndex = -1),
                                taupeAccent: taupeAccent,
                                navyAnchor: navyAnchor,
                                isDark: isDark,
                                theme: theme,
                              ),
                              const SizedBox(width: 8),
                              _buildHistoryFilterChip(
                                label: 'Completed',
                                isSelected: _historyFilterIndex == 3,
                                onTap: () => setState(() => _historyFilterIndex = 3),
                                taupeAccent: taupeAccent,
                                navyAnchor: navyAnchor,
                                isDark: isDark,
                                theme: theme,
                              ),
                              const SizedBox(width: 8),
                              _buildHistoryFilterChip(
                                label: 'Cancelled',
                                isSelected: _historyFilterIndex == 4,
                                onTap: () => setState(() => _historyFilterIndex = 4),
                                taupeAccent: taupeAccent,
                                navyAnchor: navyAnchor,
                                isDark: isDark,
                                theme: theme,
                              ),
                              const SizedBox(width: 8),
                              _buildHistoryFilterChip(
                                label: 'Rejected',
                                isSelected: _historyFilterIndex == 5,
                                onTap: () => setState(() => _historyFilterIndex = 5),
                                taupeAccent: taupeAccent,
                                navyAnchor: navyAnchor,
                                isDark: isDark,
                                theme: theme,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (historyJobsList.isEmpty)
                          _buildEmptyCard(
                            icon: Icons.history_outlined,
                            message: 'No history records found.',
                            taupeAccent: taupeAccent,
                            theme: theme,
                          )
                        else
                          ...historyJobsList.map((job) => _buildScheduleCard(
                                job: job,
                                theme: theme,
                                isDark: isDark,
                                navyAnchor: navyAnchor,
                                taupeAccent: taupeAccent,
                                servio: servio,
                              )),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int badgeCount,
    required String badgeLabel,
    required Color taupeAccent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1D23),
          ),
        ),
        if (badgeCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2E0C4),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '$badgeCount $badgeLabel',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF231A09),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNewRequestCard({
    required BackendBooking job,
    required ThemeData theme,
    required bool isDark,
    required Color navyAnchor,
    required Color taupeAccent,
    required ServioThemeExtension servio,
  }) {
    final location = <String>[job.addressStreet, job.addressCity]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: taupeAccent.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(26, 29, 37, 0.04),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JobDetailsScreen(jobId: job.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.serviceName,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: navyAnchor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: servio.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'High Priority',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: taupeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Metadata Row
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: servio.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      job.addressCity,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: servio.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.schedule_outlined, size: 16, color: servio.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      job.scheduledTime.isNotEmpty ? job.scheduledTime : 'ASAP',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: servio.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.person_outline, size: 16, color: servio.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      job.customerName,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: servio.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptJob(job),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                        label: const Text('Accept Job'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyAnchor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _declineJob(job),
                        icon: Icon(Icons.cancel_outlined, size: 18, color: navyAnchor),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: taupeAccent.withValues(alpha: 0.3), width: 1.5),
                          foregroundColor: navyAnchor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
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

  Widget _buildScheduleCard({
    required BackendBooking job,
    required ThemeData theme,
    required bool isDark,
    required Color navyAnchor,
    required Color taupeAccent,
    required ServioThemeExtension servio,
  }) {
    final location = <String>[job.addressStreet, job.addressCity]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: taupeAccent.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(26, 29, 37, 0.03),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JobDetailsScreen(jobId: job.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top clock icon and time
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: taupeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job.scheduledTime.isNotEmpty ? job.scheduledTime : '00:00',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: navyAnchor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Title and Address
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.serviceName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: navyAnchor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: servio.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Status Badge on the bottom-left
                _buildStatusBadge(job.status, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    String label;
    Color bg;
    Color fg;

    switch (_normalizedStatus(status)) {
      case 'pending':
        label = 'Pending';
        bg = isDark ? const Color(0xFF38322B) : const Color(0xFFFFF7ED);
        fg = isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
        break;
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        label = 'Confirmed';
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
        break;
      case 'arrived':
        label = 'Arrived';
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
        break;
      case 'en_route':
      case 'enroute':
        label = 'En Route';
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
        break;
      case 'in_progress':
      case 'inprogress':
      case 'active':
      case 'started':
        label = 'In Progress';
        bg = isDark ? const Color(0xFF38322B) : const Color(0xFFF2ECE4);
        fg = isDark ? const Color(0xFFD5C5A9) : const Color(0xFF5A4D35);
        break;
      case 'completed':
      case 'done':
        label = 'Completed';
        bg = isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        fg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        break;
      case 'awaiting_customer_confirmation':
        label = 'Awaiting Customer';
        bg = isDark ? const Color(0xFF38322B) : const Color(0xFFFFF7ED);
        fg = isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
        break;
      case 'pending_admin_review':
        label = 'Pending Review';
        bg = isDark ? const Color(0xFF38322B) : const Color(0xFFFFF7ED);
        fg = isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
        break;
      case 'cancelled':
      case 'canceled':
      case 'cancelled_by_customer':
      case 'canceled_by_customer':
      case 'cancelled_by_provider':
      case 'canceled_by_provider':
      case 'cancelled_by_worker':
      case 'canceled_by_worker':
        label = 'Cancelled';
        bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
        break;
      case 'rejected':
      case 'declined':
        label = 'Rejected';
        bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
        break;
      default:
        label = status;
        bg = isDark ? const Color(0xFF32363F) : const Color(0xFFE4E2DF);
        fg = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF45474B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String message,
    required Color taupeAccent,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: taupeAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: taupeAccent.withValues(alpha: 0.6), size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Inter',
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color taupeAccent,
    required Color navyAnchor,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? navyAnchor : (isDark ? const Color(0xFF1E222B) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.transparent : taupeAccent.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(26, 29, 37, 0.08),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected
                  ? (isDark ? const Color(0xFF262B34) : Colors.white)
                  : (isDark ? const Color(0xFFE3D5CA) : const Color(0xFF262B34)),
            ),
          ),
        ),
      ),
    );
  }

  bool _isAssignedToWorker(BackendBooking job, String workerId) {
    final bookingWorkerId = job.workerId.trim();
    return bookingWorkerId == workerId;
  }

  String _normalizedStatus(String status) => status.trim().toLowerCase().replaceAll('-', '_');
}
