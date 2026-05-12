import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
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
      _bookings = raw.map(BookingModel.fromBackend).toList();
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
        final active = _bookings.where((b) => b.status.isActive).toList();
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
                      data: _flowDataFromBooking(booking),
                    ),
                  ),
                );
              },
            );
          },
        );
      case 1:
        final history = _bookings;
        if (history.isEmpty) {
          return const _EmptyState(message: 'No bookings yet.');
        }
        return ListView.separated(
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (BuildContext context, int index) {
            final booking = history[index];
            return _LiveBookingCard(
              booking: booking,
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(
                      data: _flowDataFromBooking(booking),
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
        BookingStatus.pending => ServioStatusChipType.warning,
        BookingStatus.confirmed => ServioStatusChipType.success,
        BookingStatus.enRoute => ServioStatusChipType.info,
        BookingStatus.arrived => ServioStatusChipType.info,
        BookingStatus.inProgress => ServioStatusChipType.info,
        BookingStatus.completed => ServioStatusChipType.success,
        BookingStatus.cancelled => ServioStatusChipType.danger,
        BookingStatus.rejected => ServioStatusChipType.danger,
        BookingStatus.disputed => ServioStatusChipType.warning,
      };

  static String _chipLabel(BookingStatus status) => switch (status) {
        BookingStatus.pending => 'Pending',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.enRoute => 'En Route',
        BookingStatus.arrived => 'Arrived',
        BookingStatus.inProgress => 'In Progress',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.disputed => 'Disputed',
      };

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isActive = booking.status.isActive;

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
              Align(
                alignment: Alignment.centerLeft,
                child: ServioStatusChip(
                  label: data.statusLabel,
                  type: _chipTypeForStatusCode(data.statusCode),
                ),
              ),
              const SizedBox(height: 20),
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildTimeline(data),
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
                          child: Center(
                              child: Text(_initials(data.technicianName))),
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
                                    contactName: data.technicianName,
                                    bookingId: data.backendId,
                                    workerId: data.technicianId,
                                  ),
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
                    _DetailsPair(label: 'Payment', value: data.paymentMethod),
                    if (data.savedCardLabel.isNotEmpty)
                      _DetailsPair(label: 'Card', value: data.savedCardLabel),
                    if (data.pin.isNotEmpty)
                      _DetailsPair(label: 'Arrival PIN', value: data.pin),
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

  List<Widget> _buildTimeline(BookingFlowData data) {
    final level = switch (data.statusCode) {
      'pending' => 0,
      'confirmed' || 'accepted' => 1,
      'en_route' || 'arrived' => 2,
      'in_progress' => 3,
      'completed' => 4,
      _ => -1,
    };

    if (level == -1) {
      return <Widget>[
        _TimelineRow(
          label: 'Booking Placed',
          complete: true,
          meta: '${data.date} ${data.time.split('-').first.trim()}',
        ),
        _TimelineRow(
          label: data.statusLabel,
          complete: false,
          active: true,
          meta: 'This booking was ${data.statusCode}.',
        ),
      ];
    }

    final isCash = data.paymentMethodCode != 'card';
    final paymentMeta = isCash ? 'Cash payment upon completion' : 'Held in Escrow';

    return <Widget>[
      _TimelineRow(
        label: 'Booking Placed',
        complete: true,
        active: false,
        meta: '${data.date} ${data.time.split('-').first.trim()}',
      ),
      _TimelineRow(
        label: 'Technician Confirmed',
        complete: level >= 1,
        active: level == 0,
        meta: level == 0 ? 'Waiting for technician to confirm' : 'Technician has accepted the booking',
      ),
      _TimelineRow(
        label: isCash ? 'Payment Method (Cash)' : 'Payment Authorized',
        complete: isCash ? level >= 4 : level >= 0,
        active: isCash ? level < 4 : false,
        meta: isCash ? 'Cash payment due upon completion' : 'Card payment confirmed via Escrow',
      ),
      _TimelineRow(
        label: 'In Progress',
        complete: level >= 4,
        active: level == 3 || level == 2,
        meta: level < 2 ? 'Upcoming' : (level < 4 ? 'Technician is working on your service' : 'Finished'),
      ),
      _TimelineRow(
        label: 'Completed',
        complete: level == 4,
        active: false,
        meta: level == 4 ? 'Job done' : 'Upcoming',
      ),
    ];
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

BookingFlowData _flowDataFromBooking(BookingModel booking) {
  return BookingFlowData(
    backendId: booking.id,
    serviceName: booking.serviceName,
    technicianName: booking.technicianName,
    technicianId: booking.technicianId,
    date: booking.date,
    time: booking.time,
    location: booking.location,
    amount: booking.amount,
    reference: booking.reference,
    pin: booking.pin,
    paymentMethod: booking.paymentMethod,
    paymentMethodCode:
        booking.paymentMethod.toLowerCase().contains('card') ? 'card' : 'cash',
    savedCardLabel: _cardLabelFor(booking),
    savedCardLast4: booking.paymentCardLast4,
    statusLabel: _LiveBookingCard._chipLabel(booking.status),
    statusCode: _statusCodeFromStatus(booking.status),
  );
}

String _cardLabelFor(BookingModel booking) {
  if (booking.paymentCardLabel.isNotEmpty) return booking.paymentCardLabel;
  if (booking.paymentCardLast4.isNotEmpty) {
    return 'Card ending ${booking.paymentCardLast4}';
  }
  return '';
}

String _statusCodeFromStatus(BookingStatus status) => switch (status) {
      BookingStatus.pending => 'pending',
      BookingStatus.confirmed => 'confirmed',
      BookingStatus.enRoute => 'en_route',
      BookingStatus.arrived => 'arrived',
      BookingStatus.inProgress => 'in_progress',
      BookingStatus.completed => 'completed',
      BookingStatus.cancelled => 'cancelled',
      BookingStatus.rejected => 'rejected',
      BookingStatus.disputed => 'disputed',
    };

ServioStatusChipType _chipTypeForStatusCode(String statusCode) {
  return switch (statusCode.toLowerCase()) {
    'confirmed' || 'completed' || 'done' => ServioStatusChipType.success,
    'en_route' ||
    'enroute' ||
    'arrived' ||
    'in_progress' ||
    'inprogress' =>
      ServioStatusChipType.info,
    'cancelled' || 'canceled' || 'rejected' => ServioStatusChipType.danger,
    'disputed' => ServioStatusChipType.warning,
    _ => ServioStatusChipType.warning,
  };
}

String _initials(String name) {
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
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
