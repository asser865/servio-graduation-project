import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/booking_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../booking/booking_flow_data.dart';
import '../messages/chat_screen.dart';
import 'write_review_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late int _tabIndex;
  List<BookingModel> _bookings = <BookingModel>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookings());
  }

  Future<void> _fetchBookings() async {
    try {
      final client = context.read<ApiClient>();
      final raw = await BookingsApi(client).getMyBookings();
      _bookings = raw.map(_toBookingModel).toList();
    } catch (_) {
      _error = 'Could not load bookings.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    const tabs = <String>['Active', 'History', 'Favourites'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
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
                children: List<Widget>.generate(tabs.length, (int index) {
                  final active = index == _tabIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = index),
                      child: AnimatedContainer(
                        duration: ServioMotion.micro,
                        curve: ServioMotion.curve,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.surface
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                        ),
                        child: Text(
                          tabs[index],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color:
                                active ? servio.accent : servio.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    switch (_tabIndex) {
      case 0:
        final active = _bookings
            .where((b) =>
                b.status == BookingStatus.upcoming ||
                b.status == BookingStatus.inProgress)
            .toList();
        if (active.isEmpty) {
          return const _EmptyState(message: 'No active bookings yet.');
        }
        return ListView.separated(
          itemCount: active.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (BuildContext context, int index) {
            final booking = active[index];
            return _LiveBookingCard(
              booking: booking,
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(
                      data: BookingFlowData(
                        serviceName: booking.serviceName,
                        technicianName: booking.technicianName,
                        date: booking.date,
                        time: booking.time,
                        location: booking.location,
                        amount: booking.amount,
                        reference: booking.reference,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      case 1:
        final past = _bookings
            .where((b) =>
                b.status == BookingStatus.completed ||
                b.status == BookingStatus.cancelled)
            .toList();
        if (past.isEmpty) {
          return const _EmptyState(message: 'No booking history yet.');
        }
        return ListView.separated(
          itemCount: past.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (BuildContext context, int index) {
            final booking = past[index];
            return _LiveBookingCard(
              booking: booking,
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(
                      data: BookingFlowData(
                        serviceName: booking.serviceName,
                        technicianName: booking.technicianName,
                        date: booking.date,
                        time: booking.time,
                        location: booking.location,
                        amount: booking.amount,
                        reference: booking.reference,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      default:
        return ListView(
          children: const <Widget>[
            _FavouriteTechnicianCard(
                name: 'Khaled Mohamed', specialty: 'Plumbing'),
            SizedBox(height: 16),
            _FavouriteTechnicianCard(
                name: 'Mahmoud Ibrahim', specialty: 'Electrical'),
          ],
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Center(
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: servio.textSecondary),
      ),
    );
  }
}

class _LiveBookingCard extends StatelessWidget {
  const _LiveBookingCard({
    required this.booking,
    required this.onViewDetails,
  });

  final BookingModel booking;
  final VoidCallback onViewDetails;

  static ServioStatusChipType _chipType(BookingStatus status) =>
      switch (status) {
        BookingStatus.upcoming => ServioStatusChipType.warning,
        BookingStatus.inProgress => ServioStatusChipType.info,
        BookingStatus.completed => ServioStatusChipType.success,
        BookingStatus.cancelled => ServioStatusChipType.danger,
      };

  static String _chipLabel(BookingStatus status) => switch (status) {
        BookingStatus.upcoming => 'Upcoming',
        BookingStatus.inProgress => 'In Progress',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isActive = booking.status == BookingStatus.upcoming ||
        booking.status == BookingStatus.inProgress;

    return ServioCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 120,
            decoration: BoxDecoration(
              color: isActive ? servio.info : servio.success,
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(booking.serviceName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '${booking.technicianName} • ${booking.date}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
                const SizedBox(height: 10),
                ServioStatusChip(
                  label: _chipLabel(booking.status),
                  type: _chipType(booking.status),
                ),
                const SizedBox(height: 14),
                isActive
                    ? ServioPrimaryButton(
                        label: 'View Details', onPressed: onViewDetails)
                    : Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Re-book'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onViewDetails,
                              child: const Text('View Details'),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({
    super.key,
    this.data = const BookingFlowData(),
  });

  final BookingFlowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return PopScope<Object?>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _leaveDetails(context);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to bookings',
            onPressed: () => _leaveDetails(context),
          ),
          title: const Text('Booking Details'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: ServioStatusChip(
                  label: 'In Progress',
                  type: ServioStatusChipType.info,
                ),
              ),
              const SizedBox(height: 20),
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    _TimelineRow(
                        label: 'Booking Placed',
                        complete: true,
                        meta: '25/03/2026 05:30 PM'),
                    _TimelineRow(
                        label: 'Payment Confirmed',
                        complete: true,
                        meta: 'Held in Escrow'),
                    _TimelineRow(
                        label: 'Technician En Route',
                        complete: true,
                        meta: 'Arriving soon'),
                    _TimelineRow(
                        label: 'In Progress',
                        active: true,
                        meta: 'Current stage'),
                    _TimelineRow(label: 'Completed', meta: 'Upcoming'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ServioCard(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: ServioGradients.warm,
                            shape: BoxShape.circle,
                            border: Border.all(color: servio.accent, width: 2),
                          ),
                          child: const Center(child: Text('AN')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(data.technicianName,
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                '4.9 rating',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: servio.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatScreen(
                                      contactName: data.technicianName),
                                ),
                              );
                            },
                            child: const Text('Message'),
                          ),
                        ),
                        Expanded(
                            child: TextButton(
                                onPressed: () {}, child: const Text('Call'))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ServioCard(
                child: Column(
                  children: <Widget>[
                    _DetailsPair(label: 'Service', value: data.serviceName),
                    _DetailsPair(label: 'Date', value: data.date),
                    _DetailsPair(label: 'Time', value: data.time),
                    _DetailsPair(label: 'Location', value: data.location),
                    _DetailsPair(
                        label: 'Total', value: data.amount, highlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WriteReviewScreen(
                        technicianName: data.technicianName,
                        jobSummary: data.serviceName,
                      ),
                    ),
                  );
                },
                child: const Text('Write a Review'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: servio.danger),
                  foregroundColor: servio.danger,
                ),
                child: const Text('Cancel Booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _leaveDetails(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MyBookingsScreen(),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    this.complete = false,
    this.active = false,
    required this.meta,
  });

  final String label;
  final bool complete;
  final bool active;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = complete
        ? servio.success
        : active
            ? servio.info
            : servio.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            complete
                ? Icons.check_circle_rounded
                : active
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label),
                const SizedBox(height: 2),
                Text(
                  meta,
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
    );
  }
}

class _DetailsPair extends StatelessWidget {
  const _DetailsPair({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: highlight ? servio.accent : servio.textSecondary,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                ),
          ),
        ],
      ),
    );
  }
}

BookingModel _toBookingModel(BackendBooking b) {
  return BookingModel(
    id: b.id,
    reference:
        '#${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id.toUpperCase()}',
    serviceName: b.serviceName.isNotEmpty ? b.serviceName : 'Service',
    technicianName: b.workerName.isNotEmpty ? b.workerName : 'Technician',
    technicianId: b.workerId,
    date: DateFormat('MMM d, y').format(b.scheduledDate),
    time: b.scheduledTime.isNotEmpty
        ? _displayScheduledTime(b.scheduledTime)
        : DateFormat('h:mm a').format(b.scheduledDate),
    location: b.addressCity.isNotEmpty ? b.addressCity : 'Cairo',
    amount: 'EGP ${b.totalAmount.toStringAsFixed(0)}',
    status: _parseBookingStatus(b.status),
    pin: '0000',
    notes: b.notes,
  );
}

BookingStatus _parseBookingStatus(String s) => switch (s) {
      'confirmed' || 'pending' || 'accepted' => BookingStatus.upcoming,
      'in_progress' || 'inProgress' => BookingStatus.inProgress,
      'completed' => BookingStatus.completed,
      _ => BookingStatus.cancelled,
    };

String _displayScheduledTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:00 $suffix';
}

class _FavouriteTechnicianCard extends StatelessWidget {
  const _FavouriteTechnicianCard({
    required this.name,
    required this.specialty,
  });

  final String name;
  final String specialty;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
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
            child: Center(child: Text(name[0])),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  specialty,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.favorite_rounded, color: servio.accent),
        ],
      ),
    );
  }
}
