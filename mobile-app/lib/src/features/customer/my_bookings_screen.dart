import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../booking/booking_flow_data.dart';
import '../messages/chat_screen.dart';
import 'ai_smart_match_screen.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';
import 'services_marketplace_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    const tabs = <String>['Active', 'History', 'Favourites'];

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
          ServioBottomNavItem(icon: Icons.grid_view_rounded, label: 'Services'),
          ServioBottomNavItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Smart Match',
              highlighted: true),
          ServioBottomNavItem(
              icon: Icons.calendar_month_rounded, label: 'Bookings'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 3,
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerHomeScreen(),
              ),
            );
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServicesMarketplaceScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AiSmartMatchScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerProfileScreen(),
              ),
            );
          }
        },
      ),
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
    final bookingsProvider = context.watch<BookingsProvider>();

    switch (_tabIndex) {
      case 0:
        final active = bookingsProvider.upcoming;
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
        final past = bookingsProvider.past;
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

    return Scaffold(
      appBar: AppBar(
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
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: servio.danger),
                foregroundColor: servio.danger,
              ),
              child: const Text('Cancel Booking'),
            ),
          ],
        ),
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
