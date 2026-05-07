import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'job_details_screen.dart';

class JobQueueScreen extends StatefulWidget {
  const JobQueueScreen({super.key});

  @override
  State<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends State<JobQueueScreen> {
  int _tabIndex = 0;
  static const List<String> _tabs = <String>[
    'Pending',
    'Confirmed',
    'In Progress',
    'Completed'
  ];

  List<BackendBooking> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchJobs());
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = context.read<ApiClient>();
    try {
      final jobs = await BookingsApi(client).getWorkerBookings();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<BackendBooking> _jobsForTab(int tab) {
    const statusMap = <int, String>{
      0: 'pending',
      1: 'accepted',
      2: 'in_progress',
      3: 'completed',
    };
    final status = statusMap[tab] ?? '';
    return _jobs.where((j) => j.status == status).toList();
  }

  Future<void> _updateJobStatus(String jobId, String status) async {
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client).updateStatus(jobId, status);
      if (!mounted) return;
      await _fetchJobs();
    } catch (_) {}
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
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Row(
                children: List<Widget>.generate(_tabs.length, (int index) {
                  final active = index == _tabIndex;
                  final count = _jobsForTab(index).length.toString();

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = index),
                      child: AnimatedContainer(
                        duration: ServioMotion.micro,
                        curve: ServioMotion.curve,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.surface
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              _tabs[index],
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: active
                                        ? servio.accent
                                        : servio.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ServioColors.tint(
                                  index == 0
                                      ? servio.warning
                                      : index == 3
                                          ? servio.success
                                          : servio.info,
                                ),
                                borderRadius:
                                    BorderRadius.circular(ServioRadius.full),
                              ),
                              child: Text(
                                count,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: index == 0
                                          ? servio.warning
                                          : index == 3
                                              ? servio.success
                                              : servio.info,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
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
                                  'No jobs in this category',
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
                                      ? () =>
                                          _updateJobStatus(job.id, 'accepted')
                                      : null,
                                  onDecline: _tabIndex == 0
                                      ? () =>
                                          _updateJobStatus(job.id, 'cancelled')
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
    switch (status) {
      case 'pending':
        return ServioStatusChipType.warning;
      case 'accepted':
        return ServioStatusChipType.info;
      case 'in_progress':
        return ServioStatusChipType.info;
      case 'completed':
        return ServioStatusChipType.success;
      default:
        return ServioStatusChipType.warning;
    }
  }

  String _chipLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
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
    );
  }
}
