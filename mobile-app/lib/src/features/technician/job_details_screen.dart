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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = context.read<ApiClient>();
    try {
      final jobs = await BookingsApi(client).getWorkerBookings();
      if (!mounted) return;
      final job = jobs.where((j) => j.id == widget.jobId).firstOrNull;
      setState(() {
        _job = job;
        _loading = false;
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _updating = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    final client = context.read<ApiClient>();
    setState(() => _updating = true);
    try {
      await BookingsApi(client).updateStatus(widget.jobId, status);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
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
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: Center(child: Text(_error!)),
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
