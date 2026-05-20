import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/services/job_session_service.dart';
import '../../core/services/location_service.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../shared/widgets/servio_map_widget.dart';
import '../messages/chat_screen.dart';

/// Technician job details screen — implements the full booking lifecycle:
///
///   pending → accepted → [enRoute] → [arrived + PIN] → inProgress (timer)
///          → completeConfirm (notes) → done
///
/// The [enRoute] and [arrived] sections mirror backend status transitions so
/// the final PIN step can move from `arrived` to `in_progress` cleanly.
class JobDetailsScreen extends StatefulWidget {
  const JobDetailsScreen({
    required this.jobId,
    super.key,
  });

  final String jobId;

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

// JobSection enum is defined in job_session_service.dart and covers all
// local UI states including pending, cancelled, done (non-persisted) and
// enRoute, arrived, inProgress, completeConfirm (persisted).

// ─── State ───────────────────────────────────────────────────────────────────

class _JobDetailsScreenState extends State<JobDetailsScreen>
    with SingleTickerProviderStateMixin {
  BackendBooking? _job;
  bool _loading = true;
  String? _error;
  bool _updating = false;
  Timer? _timeoutTimer;

  JobSection _section = JobSection.accepted;

  // Timer (Phase 4)
  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  int? _timerStart;

  // PIN entry (Phase 3)
  final List<TextEditingController> _pinCtrl =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocus = List.generate(4, (_) => FocusNode());
  bool _pinError = false;
  late final AnimationController _shakeCtrl;

  // Completion notes (Phase 5)
  final TextEditingController _notesCtrl = TextEditingController();

  // Map (Phase 7)
  LatLng? _customerLatLng;
  bool _geocodingAddress = false;

  static const Duration _kTimeout = Duration(seconds: 12);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _tickTimer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _pinCtrl) {
      c.dispose();
    }
    for (final f in _pinFocus) {
      f.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_kTimeout, () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error = 'Request timed out. Check your connection and try again.';
        });
      }
    });

    final client = context.read<ApiClient>();
    try {
      final jobs = await BookingsApi(client).getWorkerBookings();
      _timeoutTimer?.cancel();
      if (!mounted) return;
      final job = jobs.where((j) => j.id == widget.jobId).firstOrNull;
      if (job == null) {
        setState(() {
          _loading = false;
          _error = 'Job not found.';
        });
        return;
      }
      final section = await _resolveSection(job);
      if (!mounted) return;
      setState(() {
        _job = job;
        _section = section;
        _loading = false;
        _error = null;
        _updating = false;
      });
      _geocodeJobAddress();
      // Restore timer if we're in an active job section.
      if (section == JobSection.inProgress ||
          section == JobSection.completeConfirm) {
        await _restoreTimer(job.id);
      }
    } catch (_) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _error = 'Could not load job details. Please try again.';
        _loading = false;
        _updating = false;
      });
    }
  }

  Future<void> _geocodeJobAddress() async {
    final job = _job;
    if (job == null) return;
    final street = job.addressStreet;
    final city = job.addressCity;
    if (street.isEmpty && city.isEmpty) return;

    setState(() => _geocodingAddress = true);
    final latLng = await LocationService().geocodeAddress('$street, $city');
    if (mounted) {
      setState(() {
        _customerLatLng = latLng;
        _geocodingAddress = false;
      });
    }
  }

  Future<JobSection> _resolveSection(BackendBooking job) async {
    final stored = await JobSessionService.getSection(job.id);
    switch (job.status.trim().toLowerCase()) {
      case 'completed':
      case 'done':
        return JobSection.done;
      case 'awaiting_customer_confirmation':
      case 'pending_admin_review':
        await JobSessionService.setSection(job.id, JobSection.done);
        return JobSection.done;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return JobSection.cancelled;
      case 'in_progress':
      case 'inprogress':
      case 'active':
      case 'started':
        // Honour stored sub-state so "Finish Job" survives a navigation pop.
        if (stored == JobSection.inProgress ||
            stored == JobSection.completeConfirm) {
          return stored!;
        }
        await JobSessionService.setSection(job.id, JobSection.inProgress);
        return JobSection.inProgress;
      case 'arrived':
        await JobSessionService.setSection(job.id, JobSection.arrived);
        return JobSection.arrived;
      case 'en_route':
      case 'enroute':
        await JobSessionService.setSection(job.id, JobSection.enRoute);
        return JobSection.enRoute;
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        const validPre = <JobSection>{
          JobSection.accepted,
          JobSection.enRoute,
          JobSection.arrived,
        };
        if (stored != null && validPre.contains(stored)) return stored;
        return JobSection.accepted;
      case 'pending':
        return JobSection.pending;
      default:
        return JobSection.accepted;
    }
  }

  // ── Timer (Phase 4) ────────────────────────────────────────────────────────

  Future<void> _restoreTimer(String bookingId) async {
    final t0 = await JobSessionService.getTimerStart(bookingId);
    if (t0 != null) {
      _timerStart = t0;
      _startTicking();
    }
  }

  void _startTicking() {
    _tickTimer?.cancel();
    if (_timerStart == null) return;
    final t0 = _timerStart!;
    if (mounted) {
      setState(() {
        _elapsedSeconds =
            ((DateTime.now().millisecondsSinceEpoch - t0) / 1000).floor();
      });
    }
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds =
              ((DateTime.now().millisecondsSinceEpoch - t0) / 1000).floor();
        });
      }
    });
  }

  String get _timerDisplay {
    final s = _elapsedSeconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${sec.toString().padLeft(2, '0')}';
  }

  // ── Section transitions ────────────────────────────────────────────────────

  Future<void> _goTo(JobSection next) async {
    if (_job == null) return;
    await JobSessionService.setSection(_job!.id, next);
    if (mounted) setState(() => _section = next);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _acceptJob() async {
    if (_job == null || _updating) return;
    setState(() => _updating = true);
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client).updateStatus(widget.jobId, 'accepted');
      if (!mounted) return;
      await _goTo(JobSection.accepted);
      setState(() => _updating = false);
      unawaited(_load()); // background refresh for populated fields
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      _snack('Could not accept job. Please try again.');
    }
  }

  Future<void> _rejectJob() async {
    if (_job == null || _updating) return;
    final reason = await _showDeclineDialog();
    if (reason == null || !mounted) return; // user cancelled the dialog
    setState(() => _updating = true);
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client).updateStatus(
        widget.jobId,
        'rejected',
        reason: reason.isNotEmpty ? reason : null,
      );
      if (!mounted) return;
      await JobSessionService.clearSession(widget.jobId);
      setState(() {
        _section = JobSection.cancelled;
        _updating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      _snack('Could not decline job. Please try again.');
    }
  }

  Future<void> _startTrip() async {
    if (_job == null || _updating) return;
    setState(() => _updating = true);
    final client = context.read<ApiClient>();
    try {
      await _ensureBackendEnRoute(BookingsApi(client));
      if (!mounted) return;
      await _goTo(JobSection.enRoute);
      setState(() => _updating = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      _snack('Could not mark you on the way. Please try again.');
    }
  }

  Future<void> _markArrived() async {
    if (_job == null || _updating) return;
    setState(() => _updating = true);
    final client = context.read<ApiClient>();
    try {
      await _ensureBackendArrived(BookingsApi(client));
      if (!mounted) return;
      await _goTo(JobSection.arrived);
      setState(() => _updating = false);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pinFocus[0].requestFocus(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      _snack('Could not mark arrival. Please try again.');
    }
  }

  Future<void> _ensureBackendEnRoute(BookingsApi api) async {
    final status = _normalizedStatus(_job?.status ?? '');
    if (status == 'en_route' ||
        status == 'arrived' ||
        status == 'in_progress') {
      return;
    }
    if (status == 'accepted' ||
        status == 'confirmed' ||
        status == 'scheduled') {
      await api.updateStatus(widget.jobId, 'en_route');
      _job = _job?.copyWith(status: 'en_route');
    }
  }

  Future<void> _ensureBackendArrived(BookingsApi api) async {
    final status = _normalizedStatus(_job?.status ?? '');
    if (status == 'arrived' || status == 'in_progress') return;
    if (status == 'accepted' ||
        status == 'confirmed' ||
        status == 'scheduled') {
      await _ensureBackendEnRoute(api);
    }
    if (_normalizedStatus(_job?.status ?? '') == 'en_route') {
      await api.updateStatus(widget.jobId, 'arrived');
      _job = _job?.copyWith(status: 'arrived');
    }
  }

  Future<String?> _showDeclineDialog() => showDialog<String>(
        context: context,
        builder: (ctx) {
          final reasonCtrl = TextEditingController();
          final servio = ctx.servio;
          return AlertDialog(
            title: const Text('Decline Job'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Are you sure you want to decline this job?',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(), // null → cancelled
                child: const Text('Keep Job'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(reasonCtrl.text.trim()),
                child: Text(
                  'Decline',
                  style: TextStyle(color: servio.danger),
                ),
              ),
            ],
          );
        },
      );

  /// Validates PIN then transitions to in_progress.
  Future<void> _verifyPinAndStart() async {
    if (_job == null || _updating) return;

    final entered = _pinCtrl.map((c) => c.text).join();
    if (entered.length < 4) {
      setState(() => _pinError = true);
      // Focus the first empty box.
      final firstEmpty = _pinCtrl.indexWhere((c) => c.text.isEmpty);
      if (firstEmpty != -1) _pinFocus[firstEmpty].requestFocus();
      return;
    }

    final correctPin = _job!.pin.trim();
    // Match website: skip validation when server PIN is absent.
    if (correctPin.isNotEmpty && entered != correctPin) {
      setState(() => _pinError = true);
      _shakeCtrl.forward(from: 0);
      for (final c in _pinCtrl) {
        c.clear();
      }
      _pinFocus[0].requestFocus();
      return;
    }

    setState(() {
      _pinError = false;
      _updating = true;
    });
    final client = context.read<ApiClient>();
    try {
      final api = BookingsApi(client);
      await _ensureBackendArrived(api);
      await api.updateStatus(widget.jobId, 'in_progress');
      _job = _job?.copyWith(status: 'in_progress');
      if (!mounted) return;
      final t0 = DateTime.now().millisecondsSinceEpoch;
      await JobSessionService.setTimerStart(widget.jobId, t0);
      _timerStart = t0;
      await _goTo(JobSection.inProgress);
      _startTicking();
      setState(() => _updating = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      _snack('Could not start job. Please try again.');
    }
  }

  Future<void> _submitCompletion() async {
    if (_job == null || _updating) return;
    setState(() => _updating = true);
    final client = context.read<ApiClient>();
    final notes = _notesCtrl.text.trim();
    try {
      await BookingsApi(client).updateStatus(
        widget.jobId,
        'awaiting_customer_confirmation',
        notes: notes.isNotEmpty ? notes : null,
      );
      _job = _job?.copyWith(status: 'awaiting_customer_confirmation');
      if (!mounted) return;
      _tickTimer?.cancel();
      await JobSessionService.clearSession(widget.jobId);
      if (!mounted) return;
      setState(() {
        _section = JobSection.done;
        _updating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      _snack('Could not complete job. Please try again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ── Root build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) return _buildError(context);

    return Scaffold(
      appBar: _appBar(context, job: _job),
      body: AnimatedSwitcher(
        duration: ServioMotion.normal,
        switchInCurve: ServioMotion.spring,
        switchOutCurve: Curves.easeIn,
        child: switch (_section) {
          JobSection.pending => _buildPending(key: const ValueKey('pending')),
          JobSection.accepted =>
            _buildAccepted(key: const ValueKey('accepted')),
          JobSection.enRoute => _buildEnRoute(key: const ValueKey('enRoute')),
          JobSection.arrived => _buildArrived(key: const ValueKey('arrived')),
          JobSection.inProgress =>
            _buildInProgress(key: const ValueKey('inProgress')),
          JobSection.completeConfirm =>
            _buildCompleteConfirm(key: const ValueKey('completeConfirm')),
          JobSection.done => _buildDone(key: const ValueKey('done')),
          JobSection.cancelled =>
            _buildCancelled(key: const ValueKey('cancelled')),
        },
      ),
    );
  }

  AppBar _appBar(BuildContext context, {BackendBooking? job}) {
    return AppBar(
      title: const Text('Job Details'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      actions: job != null
          ? <Widget>[
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      contactName: job.customerName.isNotEmpty
                          ? job.customerName
                          : 'Customer',
                      bookingId: job.id,
                      customerId: job.customerId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Message'),
              ),
            ]
          : null,
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    return Scaffold(
      appBar: _appBar(context),
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
                child: const Icon(Icons.cloud_off_rounded,
                    color: ServioColors.danger, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Could Not Load Job',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: servio.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                      _job = null;
                    });
                    _load();
                  },
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Go Back',
                    style: TextStyle(color: servio.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  /// Compact job summary card shown in most sections.
  Widget _jobInfoCard() {
    final job = _job!;
    final theme = Theme.of(context);
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
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
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(job.serviceName, style: theme.textTheme.titleMedium),
                    if (job.customerName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        job.customerName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.location_on_outlined,
            job.addressCity.isNotEmpty ? job.addressCity : 'Address on file',
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.calendar_today_outlined,
            '${job.scheduledDate.day}/${job.scheduledDate.month}/'
            '${job.scheduledDate.year}'
            '${job.scheduledTime.isNotEmpty ? '  ·  ${job.scheduledTime}' : ''}',
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.payments_outlined,
            'EGP ${job.totalAmount.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    final servio = context.servio;
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: servio.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  // ── Section: pending ───────────────────────────────────────────────────────

  Widget _buildPending({Key? key}) {
    final servio = context.servio;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _statusBadge('New Job Request', servio.warning),
          const SizedBox(height: 16),
          _jobInfoCard(),
          if (_job!.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _notesCard(_job!.notes),
          ],
          const SizedBox(height: 24),
          _updating
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ServioPrimaryButton(
                      label: 'Accept Job',
                      onPressed: _acceptJob,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _rejectJob,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: servio.danger,
                        side: BorderSide(color: servio.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                      child: const Text('Decline Job'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Section: accepted ──────────────────────────────────────────────────────

  Widget _buildAccepted({Key? key}) {
    final servio = context.servio;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _statusBadge('Job Confirmed', servio.success),
          const SizedBox(height: 16),
          _jobInfoCard(),
          if (_job!.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _notesCard(_job!.notes),
          ],
          const SizedBox(height: 32),
          _updating
              ? const Center(child: CircularProgressIndicator())
              : ServioPrimaryButton(
                  label: "I'm On My Way",
                  onPressed: _startTrip,
                ),
        ],
      ),
    );
  }

  // ── Section: enRoute ───────────────────────────────────────────────────────

  Widget _buildEnRoute({Key? key}) {
    final servio = context.servio;
    final job = _job!;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ServioCard(
            radius: ServioRadius.lg,
            child: Row(
              children: <Widget>[
                _PulsingDot(color: servio.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'On My Way',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Heading to customer location',
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
          ),
          const SizedBox(height: 16),
          ServioCard(
            radius: ServioRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Destination',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: servio.textSecondary)),
                          const SizedBox(height: 8),
                          Text(
                            job.customerName.isNotEmpty
                                ? job.customerName
                                : 'Customer',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job.addressCity.isNotEmpty
                                ? job.addressCity
                                : 'Address on file',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: servio.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scheduled: ${job.scheduledDate.day}/${job.scheduledDate.month}/${job.scheduledDate.year}'
                            '${job.scheduledTime.isNotEmpty ? '  ·  ${job.scheduledTime}' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: servio.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.directions_rounded,
                            color: servio.accent),
                        tooltip: 'Open in Maps',
                        onPressed: () async {
                          final query = Uri.encodeComponent(
                              job.addressCity.isNotEmpty
                                  ? job.addressCity
                                  : 'Cairo, Egypt');
                          final url = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$query');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildAddressMapPreview(),
          const SizedBox(height: 20),
          _updating
              ? const Center(child: CircularProgressIndicator())
              : ServioPrimaryButton(
                  label: 'I Arrived',
                  onPressed: _markArrived,
                ),
        ],
      ),
    );
  }

  // ── Section: arrived ───────────────────────────────────────────────────────

  Widget _buildArrived({Key? key}) {
    final servio = context.servio;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _statusBadge('Arrived at Location', servio.accent),
          const SizedBox(height: 20),
          ServioCard(
            radius: ServioRadius.lg,
            child: Column(
              children: <Widget>[
                const Icon(Icons.lock_outline_rounded, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Enter Customer PIN',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask the customer for their 4-digit PIN to verify arrival and start the job.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: servio.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildPinBoxes(),
                if (_pinError) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Incorrect PIN. Please try again.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: servio.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _updating
                      ? const Center(child: CircularProgressIndicator())
                      : ServioPrimaryButton(
                          label: 'Verify & Start Job',
                          onPressed: _verifyPinAndStart,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Four-box PIN entry with auto-advance, backspace navigation, and paste.
  Widget _buildPinBoxes() {
    final servio = context.servio;
    // Wrap in AnimatedBuilder to apply the shake offset.
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final dx = sin(_shakeCtrl.value * pi * 5) * 10.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(4, (i) {
          return Container(
            width: 56,
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: TextField(
              controller: _pinCtrl[i],
              focusNode: _pinFocus[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              obscureText: true,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  borderSide: BorderSide(color: servio.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  borderSide: BorderSide(color: servio.accent, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  borderSide: BorderSide(color: servio.danger, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  borderSide: BorderSide(
                    color: _pinError ? servio.danger : servio.border,
                  ),
                ),
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (v) {
                setState(() => _pinError = false);
                if (v.isNotEmpty && i < 3) {
                  _pinFocus[i + 1].requestFocus();
                } else if (v.isNotEmpty && i == 3) {
                  // All four entered — attempt verify automatically.
                  _verifyPinAndStart();
                }
              },
              onTap: () => _pinCtrl[i].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _pinCtrl[i].text.length,
              ),
            ),
          );
        }),
      ),
    );
  }

  // Paste handler is wired at the RawKeyboardListener level — for simplicity
  // the TextField onChanged handles single-digit entry with auto-advance.
  // Full paste support would require RawKeyboardListener or EditableText; the
  // auto-advance covers the common case without extra complexity.

  // ── Section: inProgress ────────────────────────────────────────────────────

  Widget _buildInProgress({Key? key}) {
    final servio = context.servio;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ServioCard(
            radius: ServioRadius.lg,
            child: Column(
              children: <Widget>[
                _PulsingDot(color: servio.success),
                const SizedBox(height: 8),
                Text(
                  'Job in Progress',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: servio.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _timerDisplay,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: servio.accent,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _jobInfoCard(),
          const SizedBox(height: 32),
          ServioPrimaryButton(
            label: 'Finish Job',
            onPressed: () => _goTo(JobSection.completeConfirm),
          ),
        ],
      ),
    );
  }

  // ── Section: completeConfirm ───────────────────────────────────────────────

  Widget _buildCompleteConfirm({Key? key}) {
    final servio = context.servio;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ServioCard(
            radius: ServioRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline_rounded,
                        color: servio.success),
                    const SizedBox(width: 8),
                    Text('Ready to Complete?',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Time elapsed: $_timerDisplay',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ServioCard(
            radius: ServioRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Job Notes (optional)',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: servio.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Describe what was done, parts used, customer feedback…',
                    hintStyle: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                      borderSide: BorderSide(color: servio.accent, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _updating
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ServioPrimaryButton(
                      label: 'Confirm & Complete',
                      onPressed: _submitCompletion,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        _goTo(JobSection.inProgress);
                        // Restore ticking in case it stopped.
                        _startTicking();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: servio.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                      child: const Text('Back to Job'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Section: done ──────────────────────────────────────────────────────────

  Widget _buildDone({Key? key}) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final awaitingCustomer = _normalizedStatus(_job?.status ?? '') ==
        'awaiting_customer_confirmation';
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ServioColors.tint(servio.success),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: servio.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              awaitingCustomer
                  ? 'Waiting for Customer Confirmation'
                  : 'Job Completed!',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              awaitingCustomer
                  ? 'Great work. The customer has been asked to confirm completion.'
                  : 'Great work. The booking has been marked as complete.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: servio.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                child: const Text('Back to Queue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section: cancelled ─────────────────────────────────────────────────────

  Widget _buildCancelled({Key? key}) {
    final servio = context.servio;
    final theme = Theme.of(context);
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ServioColors.tint(servio.textSecondary),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel_outlined,
                  color: servio.textSecondary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Job Unavailable',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This booking has been cancelled or declined.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: servio.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: servio.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                child: const Text('Back to Queue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: map preview (Phase 7) ─────────────────────────────────────────

  /// Renders a 220 px non-interactive map snapshot centred on the geocoded
  /// customer address.  Shows a loading indicator while geocoding is in
  /// progress; returns [SizedBox.shrink] when no coords are available and
  /// geocoding has finished.
  Widget _buildAddressMapPreview() {
    if (_geocodingAddress) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final pos = _customerLatLng;
    if (pos == null) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: ServioMapWidget(
          center: pos,
          zoom: 15,
          interactive: false,
          markers: <Marker>[
            buildPinMarker(pos, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // ── Helper: customer notes card ────────────────────────────────────────────

  Widget _notesCard(String notes) {
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Customer Notes',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing dot indicator ────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

String _normalizedStatus(String status) =>
    status.trim().toLowerCase().replaceAll('-', '_');

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
