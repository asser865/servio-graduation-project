import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'availability_manager_screen.dart';
import 'earnings_screen.dart';
import 'job_details_screen.dart';
import 'technician_dashboard_screen.dart';
import 'technician_profile_screen.dart';

class JobQueueScreen extends StatefulWidget {
  const JobQueueScreen({super.key});

  @override
  State<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends State<JobQueueScreen> {
  int _tabIndex = 0;
  static const List<String> _tabs = <String>['Pending', 'Confirmed', 'In Progress', 'Completed'];

  List<BackendBooking> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchJobs());
  }

  Future<void> _fetchJobs() async {
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
      1: 'confirmed',
      2: 'in_progress',
      3: 'completed',
    };
    final status = statusMap[tab] ?? '';
    return _jobs.where((j) => j.status == status).toList();
  }

  Future<void> _updateJobStatus(String jobId, String status) async {
    final client = context.read<ApiClient>();
    await BookingsApi(client).updateStatus(jobId, status);
    await _fetchJobs();
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
          ServioBottomNavItem(icon: Icons.work_outline_rounded, label: 'Jobs'),
          ServioBottomNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earnings'),
          ServioBottomNavItem(icon: Icons.schedule_rounded, label: 'Availability'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 1,
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TechnicianDashboardScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EarningsScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AvailabilityManagerScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TechnicianSettingsProfileScreen(),
              ),
            );
          }
        },
      ),
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
                          color: active ? Theme.of(context).colorScheme.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              _tabs[index],
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: active ? servio.accent : servio.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ServioColors.tint(
                                  index == 0
                                      ? servio.warning
                                      : index == 3
                                          ? servio.success
                                          : servio.info,
                                ),
                                borderRadius: BorderRadius.circular(ServioRadius.full),
                              ),
                              child: Text(
                                count,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                      ? Center(child: Text(_error!))
                      : Builder(
                          builder: (context) {
                            final filteredJobs = _jobsForTab(_tabIndex);
                            return ListView.separated(
                              itemCount: filteredJobs.length,
                              separatorBuilder: (BuildContext context, int index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (BuildContext context, int index) {
                                final job = filteredJobs[index];
                                return _JobCard(
                                  job: job,
                                  onOpen: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => JobDetailsScreen(jobId: job.id),
                                      ),
                                    );
                                  },
                                  onAccept: _tabIndex == 0
                                      ? () => _updateJobStatus(job.id, 'confirmed')
                                      : null,
                                  onDecline: _tabIndex == 0
                                      ? () => _updateJobStatus(job.id, 'cancelled')
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
      case 'confirmed':
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
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
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
                    job.serviceName.isNotEmpty ? job.serviceName[0].toUpperCase() : '?',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(job.serviceName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      job.addressCity,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
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
