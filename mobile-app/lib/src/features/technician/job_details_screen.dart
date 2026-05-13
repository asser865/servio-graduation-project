import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../messages/chat_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  const JobDetailsScreen({
    required this.jobId,
    super.key,
  });

  final String jobId;

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  BackendBooking? _job;
  bool _loading = true;
  String? _error;
  bool _updating = false;
  Timer? _timeoutTimer;

  static const Duration _kTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timeoutTimer?.cancel();
    // Start a 12-second timeout — if the API hasn't responded by then,
    // the user sees the error card instead of an infinite spinner.
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
      setState(() {
        _job = job;
        _loading = false;
        _error = null;
        _updating = false;
      });
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _error = 'Could not load job details. Please try again.';
        _loading = false;
        _updating = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
      _job = null;
    });
    await _load();
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_job == null) return;

    // ── Optimistic update ────────────────────────────────────────────────────
    // Immediately show the new status so the action button updates at once.
    final previousJob = _job!;
    setState(() {
      _job = previousJob.copyWith(status: newStatus);
      _updating = true;
    });

    // ── API call ─────────────────────────────────────────────────────────────
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client).updateStatus(widget.jobId, newStatus);
      if (!mounted) return;
      setState(() => _updating = false);
      // Refresh silently in the background to get server-populated fields.
      await _load();
    } catch (e) {
      // ── Rollback on failure ───────────────────────────────────────────────
      if (!mounted) return;
      setState(() {
        _job = previousJob;
        _updating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update status. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      final theme = Theme.of(context);
      final servio = context.servio;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Details'),
          backgroundColor: theme.scaffoldBackgroundColor,
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
                    Icons.cloud_off_rounded,
                    color: ServioColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Could Not Load Job',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
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
                    onPressed: _retry,
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
                  child: Text(
                    'Go Back',
                    style: TextStyle(color: servio.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final job = _job!;
    final servio = context.servio;
    final theme = Theme.of(context);

    final String actionLabel;
    final VoidCallback? onPressed;

    if (_updating) {
      actionLabel = 'Updating...';
      onPressed = null;
    } else {
      switch (job.status) {
        case 'pending':
          actionLabel = 'Accept Job';
          onPressed = () => _updateStatus('accepted');
        case 'accepted':
        case 'confirmed':
        case 'scheduled':
          actionLabel = 'Start Job - Mark In Progress';
          onPressed = () => _updateStatus('in_progress');
        case 'in_progress':
          actionLabel = 'Complete Job - Mark as Done';
          onPressed = () => _updateStatus('completed');
        default:
          actionLabel = 'Job Completed';
          onPressed = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ServioCard(
              radius: ServioRadius.lg,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
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
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Previous rating: 5.0',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                            contactName: job.customerName.isNotEmpty
                                ? job.customerName
                                : 'Customer',
                            bookingId: job.id,
                            customerId: job.customerId,
                          ),
                        ),
                      );
                    },
                    child: const Text('Message'),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Call')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(job.serviceName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    job.notes.isNotEmpty ? job.notes : 'No additional notes.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          width: 120,
                          decoration: BoxDecoration(
                            gradient: index.isEven
                                ? ServioGradients.brand
                                : ServioGradients.warm,
                            borderRadius:
                                BorderRadius.circular(ServioRadius.md),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    job.addressCity,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      borderRadius: BorderRadius.circular(ServioRadius.lg),
                    ),
                    child: Center(
                      child: Text(
                        'Map Preview',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: servio.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scheduled: ${job.scheduledDate.day}/${job.scheduledDate.month}/${job.scheduledDate.year}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Offered: EGP ${job.totalAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: servio.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ServioPrimaryButton(
              label: actionLabel,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}
