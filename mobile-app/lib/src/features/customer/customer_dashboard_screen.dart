import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../booking/booking_flow_data.dart';
import '../booking/booking_step_one_screen.dart';
import '../messages/chat_screen.dart';
import 'my_bookings_screen.dart';

enum _DashboardSection { overview, bookings, history, favourites }

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  _DashboardSection _section = _DashboardSection.overview;
  String _bookingFilter = 'All';
  String _historyFilter = 'All';
  List<BookingModel> _bookings = <BookingModel>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookings());
  }

  Future<void> _fetchBookings() async {
    try {
      final client = context.read<ApiClient>();
      final raw = await BookingsApi(client).getMyBookings();
      if (mounted) setState(() => _bookings = raw.map(_toBookingModel).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final bookings = _bookings;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'CUSTOMER DASHBOARD',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: servio.accent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Your SERVIO',
                                  style: theme.textTheme.headlineLarge),
                            ],
                          ),
                        ),
                        _RoundIconButton(
                          icon: Icons.calendar_month_rounded,
                          onTap: () => setState(
                            () => _section = _DashboardSection.bookings,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _DashboardSegmentedControl(
                      current: _section,
                      onChanged: (value) => setState(() => _section = value),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    AnimatedSwitcher(
                      duration: ServioMotion.tabSwitch,
                      switchInCurve: ServioMotion.spring,
                      switchOutCurve: ServioMotion.standard,
                      child: switch (_section) {
                        _DashboardSection.overview => _OverviewSection(
                            key: const ValueKey<String>('overview'),
                            bookings: bookings,
                            onBookService: _openBooking,
                            onViewBookings: () => setState(
                              () => _section = _DashboardSection.bookings,
                            ),
                          ),
                        _DashboardSection.bookings => _BookingsSection(
                            key: const ValueKey<String>('bookings'),
                            bookings: bookings,
                            filter: _bookingFilter,
                            onFilterChanged: (value) =>
                                setState(() => _bookingFilter = value),
                            onViewDetails: _openBookingDetails,
                            onChat: _openChat,
                            onCancel: _cancelBooking,
                          ),
                        _DashboardSection.history => _HistorySection(
                            key: const ValueKey<String>('history'),
                            bookings: bookings,
                            filter: _historyFilter,
                            onFilterChanged: (value) =>
                                setState(() => _historyFilter = value),
                          ),
                        _DashboardSection.favourites => const _FavouritesSection(
                            key: ValueKey<String>('favourites'),
                          ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBooking() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookingStepOneScreen()),
    );
  }

  void _openBookingDetails(BookingModel booking) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailsScreen(data: _flowDataFor(booking)),
      ),
    );
  }

  void _openChat(BookingModel booking) {
    final conversation = context
        .read<MessagesProvider>()
        .findOrCreate(booking.technicianId, booking.technicianName);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          contactName: booking.technicianName,
          conversationId: conversation?.id,
        ),
      ),
    );
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final servio = context.servio;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Cancel booking?', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'This will move ${booking.reference} to cancelled history.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: servio.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: servio.danger),
                  foregroundColor: servio.danger,
                ),
                child: const Text('Cancel Booking'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep Booking'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || confirmed != true) return;
    try {
      final client = context.read<ApiClient>();
      await BookingsApi(client).updateStatus(booking.id, 'cancelled');
      if (mounted) await _fetchBookings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel booking.')),
        );
      }
    }
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.bookings,
    required this.onBookService,
    required this.onViewBookings,
    super.key,
  });

  final List<BookingModel> bookings;
  final VoidCallback onBookService;
  final VoidCallback onViewBookings;

  @override
  Widget build(BuildContext context) {
    final userName =
        context.watch<SessionProvider>().account?.name.split(' ').first ??
            'Mostafa';
    final active = bookings
        .where((b) =>
            b.status == BookingStatus.upcoming ||
            b.status == BookingStatus.inProgress)
        .toList();
    final completed =
        bookings.where((b) => b.status == BookingStatus.completed).toList();
    final totalSpent = completed.fold<int>(
      0,
      (sum, booking) => sum + _amountValue(booking.amount),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _WelcomeCard(userName: userName, onBookService: onBookService),
        const SizedBox(height: 18),
        _StatsGrid(
          totalBookings: bookings.length,
          activeCount: active.length,
          savedTechnicians: 0,
          totalSpent: totalSpent,
        ),
        const SizedBox(height: ServioSpacing.sectionGap),
        ServioSectionHeading(
          title: 'Recent Bookings',
          actionLabel: 'View All',
          onActionTap: onViewBookings,
        ),
        const SizedBox(height: 12),
        ...bookings.take(3).map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RecentBookingRow(booking: booking),
              ),
            ),
        const SizedBox(height: 16),
        _UpcomingScheduleCard(
          bookings: active,
          onBookService: onBookService,
        ),
      ],
    );
  }
}

class _BookingsSection extends StatelessWidget {
  const _BookingsSection({
    required this.bookings,
    required this.filter,
    required this.onFilterChanged,
    required this.onViewDetails,
    required this.onChat,
    required this.onCancel,
    super.key,
  });

  final List<BookingModel> bookings;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<BookingModel> onViewDetails;
  final ValueChanged<BookingModel> onChat;
  final ValueChanged<BookingModel> onCancel;

  static const List<String> _filters = <String>[
    'All',
    'Active',
    'Pending',
    'Completed',
  ];

  List<BookingModel> get _filtered => bookings.where((booking) {
        return switch (filter) {
          'Active' => booking.status == BookingStatus.inProgress,
          'Pending' => booking.status == BookingStatus.upcoming,
          'Completed' => booking.status == BookingStatus.completed,
          _ => true,
        };
      }).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HorizontalChips(
          items: _filters,
          selected: filter,
          onSelected: onFilterChanged,
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const _EmptyDashboardState(message: 'No bookings match this filter.')
        else
          ...filtered.map(
            (booking) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _DashboardBookingCard(
                booking: booking,
                onViewDetails: () => onViewDetails(booking),
                onChat: () => onChat(booking),
                onCancel: () => onCancel(booking),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.bookings,
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  final List<BookingModel> bookings;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  static const List<String> _filters = <String>[
    'All',
    'Plumbing',
    'This Month',
    'Cash',
    '5 Star',
    'Clear All',
  ];

  @override
  Widget build(BuildContext context) {
    final completed = bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled)
        .toList();
    final spent = completed.fold<int>(
      0,
      (sum, booking) => sum + _amountValue(booking.amount),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MiniSummaryCard(
                label: 'Completed',
                value: '${completed.length}',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniSummaryCard(
                label: 'Spent',
                value: '$spent EGP',
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _MiniSummaryCard(
                label: 'Top Service',
                value: 'Plumbing',
                icon: Icons.plumbing_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _HorizontalChips(
          items: _filters,
          selected: filter,
          onSelected: (value) => onFilterChanged(
            value == 'Clear All' ? 'All' : value,
          ),
        ),
        const SizedBox(height: 16),
        if (completed.isEmpty)
          const _EmptyDashboardState(message: 'No completed bookings yet.')
        else
          ...completed.map(
            (booking) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryBookingTile(booking: booking),
            ),
          ),
      ],
    );
  }
}

class _FavouritesSection extends StatelessWidget {
  const _FavouritesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ServioSectionHeading(title: 'Saved Technicians'),
        SizedBox(height: 24),
        _EmptyDashboardState(message: 'Save technicians from their profile to see them here.'),
      ],
    );
  }
}

class _DashboardSegmentedControl extends StatelessWidget {
  const _DashboardSegmentedControl({
    required this.current,
    required this.onChanged,
  });

  final _DashboardSection current;
  final ValueChanged<_DashboardSection> onChanged;

  static const Map<_DashboardSection, String> _labels =
      <_DashboardSection, String>{
    _DashboardSection.overview: 'Overview',
    _DashboardSection.bookings: 'Bookings',
    _DashboardSection.history: 'History',
    _DashboardSection.favourites: 'Favourites',
  };

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final section = _labels.keys.elementAt(index);
          final active = section == current;

          return GestureDetector(
            onTap: () => onChanged(section),
            child: AnimatedContainer(
              duration: ServioMotion.micro,
              curve: ServioMotion.spring,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? servio.accent : servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.full),
                border: Border.all(
                  color: active ? servio.accent : servio.border,
                ),
              ),
              child: Text(
                _labels[section]!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active ? Colors.white : servio.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.userName,
    required this.onBookService,
  });

  final String userName;
  final VoidCallback onBookService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _timeGreeting();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ServioGradients.brand,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  greeting.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ServioColors.accentLight,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.waving_hand_outlined,
                  color: ServioColors.accentLight),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Welcome back, $userName',
            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your bookings, invoices, saved technicians, and upcoming schedule from one calm workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ServioPrimaryButton(
              label: 'Book a Service', onPressed: onBookService),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalBookings,
    required this.activeCount,
    required this.savedTechnicians,
    required this.totalSpent,
  });

  final int totalBookings;
  final int activeCount;
  final int savedTechnicians;
  final int totalSpent;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        _KpiCard(
          label: 'Total Bookings',
          value: '$totalBookings',
          icon: Icons.receipt_long_outlined,
          color: context.servio.accent,
          footer: const _ProgressBar(value: 0.72),
        ),
        _KpiCard(
          label: 'In Progress',
          value: '$activeCount',
          icon: Icons.engineering_outlined,
          color: context.servio.info,
          footer: const Text('1 confirmed  |  1 awaiting'),
        ),
        _KpiCard(
          label: 'Saved Technicians',
          value: '$savedTechnicians',
          icon: Icons.favorite_outline_rounded,
          color: context.servio.success,
          footer: const _ProgressDots(count: 5, filled: 4),
        ),
        _KpiCard(
          label: 'Total Spent',
          value: '$totalSpent EGP',
          icon: Icons.account_balance_wallet_outlined,
          color: context.servio.warning,
          footer: const Text('Monthly budget 5,000 EGP'),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.footer,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const Spacer(),
              Icon(Icons.more_horiz_rounded, color: servio.textSecondary),
            ],
          ),
          const Spacer(),
          Text(value, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          DefaultTextStyle(
            style: theme.textTheme.labelSmall!.copyWith(
              color: servio.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: footer,
          ),
        ],
      ),
    );
  }
}

class _RecentBookingRow extends StatelessWidget {
  const _RecentBookingRow({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Row(
        children: <Widget>[
          _ServiceIcon(serviceName: booking.serviceName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(booking.serviceName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${booking.date}  |  ${booking.technicianName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ServioStatusChip(
            label: _statusLabel(booking.status),
            type: _chipType(booking.status),
          ),
        ],
      ),
    );
  }
}

class _UpcomingScheduleCard extends StatelessWidget {
  const _UpcomingScheduleCard({
    required this.bookings,
    required this.onBookService,
  });

  final List<BookingModel> bookings;
  final VoidCallback onBookService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final next = bookings.isEmpty ? null : bookings.first;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Upcoming Schedule', style: theme.textTheme.titleMedium),
              const Spacer(),
              Icon(Icons.timeline_rounded, color: servio.accent),
            ],
          ),
          const SizedBox(height: 16),
          if (next == null)
            Text(
              'No upcoming appointments yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: servio.textSecondary,
              ),
            )
          else ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.md),
                border:
                    Border.all(color: servio.accent.withValues(alpha: 0.24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ServioStatusChip(
                    label: 'Next Appointment',
                    type: ServioStatusChipType.warning,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _ServiceIcon(serviceName: next.serviceName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(next.serviceName,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 3),
                            Text(
                              '${next.technicianName}  |  ${next.date}, ${next.time}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: servio.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _ProgressBar(value: 0.45),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...bookings.skip(1).take(3).map(
                  (booking) => _TimelineAppointment(booking: booking),
                ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onBookService,
            child: const Text('Book New Service'),
          ),
        ],
      ),
    );
  }
}

class _DashboardBookingCard extends StatefulWidget {
  const _DashboardBookingCard({
    required this.booking,
    required this.onViewDetails,
    required this.onChat,
    required this.onCancel,
  });

  final BookingModel booking;
  final VoidCallback onViewDetails;
  final VoidCallback onChat;
  final VoidCallback onCancel;

  @override
  State<_DashboardBookingCard> createState() => _DashboardBookingCardState();
}

class _DashboardBookingCardState extends State<_DashboardBookingCard>
    with TickerProviderStateMixin {
  bool _invoiceExpanded = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final theme = Theme.of(context);
    final servio = context.servio;
    final amount = _amountValue(booking.amount);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ServiceIcon(serviceName: booking.serviceName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(booking.serviceName,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        _Avatar(
                            initials: _initials(booking.technicianName),
                            size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking.technicianName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: servio.textSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onViewDetails,
                          child: const Text('View Profile'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ServioStatusChip(
                label: _statusLabel(booking.status),
                type: _chipType(booking.status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailGrid(booking: booking),
          const SizedBox(height: 16),
          _BookingProgressTracker(status: booking.status),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _InfoBox(
                  label: 'Arrival PIN',
                  value: booking.pin,
                  icon: Icons.pin_outlined,
                  accent: servio.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBox(
                  label: 'Total Amount',
                  value: booking.amount,
                  icon: Icons.payments_outlined,
                  accent: servio.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _SmallActionButton(
                label: 'View Details',
                icon: Icons.open_in_new_rounded,
                onTap: widget.onViewDetails,
              ),
              _SmallActionButton(
                label: 'View Invoice',
                icon: Icons.receipt_long_outlined,
                onTap: () =>
                    setState(() => _invoiceExpanded = !_invoiceExpanded),
              ),
              _SmallActionButton(
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: widget.onChat,
              ),
              _SmallActionButton(
                label: 'Cancel',
                icon: Icons.cancel_outlined,
                danger: true,
                onTap: widget.onCancel,
              ),
            ],
          ),
          AnimatedSize(
            duration: ServioMotion.normal,
            curve: ServioMotion.spring,
            child: _invoiceExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _InvoicePanel(
                      baseRate: amount - 75,
                      platformFee: 75,
                      parts: 0,
                      total: amount,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HistoryBookingTile extends StatefulWidget {
  const _HistoryBookingTile({required this.booking});

  final BookingModel booking;

  @override
  State<_HistoryBookingTile> createState() => _HistoryBookingTileState();
}

class _HistoryBookingTileState extends State<_HistoryBookingTile>
    with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final theme = Theme.of(context);
    final servio = context.servio;
    final amount = _amountValue(booking.amount);

    return ServioCard(
      radius: ServioRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  _ServiceIcon(serviceName: booking.serviceName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${booking.serviceName}  ${booking.reference}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${booking.technicianName}  |  ${booking.date}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const ServioStatusChip(label: 'Cash on Completion'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        booking.amount,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: servio.accent,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: ServioMotion.normal,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: servio.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: ServioMotion.normal,
            curve: ServioMotion.spring,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: <Widget>[
                        _InvoicePanel(
                          baseRate: amount - 75,
                          platformFee: 75,
                          parts: 0,
                          total: amount,
                        ),
                        const SizedBox(height: 12),
                        _VerificationBox(reference: booking.reference),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MetaTile(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: booking.date,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetaTile(
                icon: Icons.schedule_outlined,
                label: 'Time Slot',
                value: booking.time,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MetaTile(
          icon: Icons.location_on_outlined,
          label: 'Address',
          value: booking.location,
        ),
      ],
    );
  }
}

class _BookingProgressTracker extends StatelessWidget {
  const _BookingProgressTracker({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = const <String>[
      'Booked',
      'Confirmed',
      'En Route',
      'Completed'
    ];
    final currentIndex = switch (status) {
      BookingStatus.upcoming => 1,
      BookingStatus.inProgress => 2,
      BookingStatus.completed => 3,
      BookingStatus.cancelled => 0,
    };

    return Column(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(steps.length, (int index) {
            final isDone = index < currentIndex ||
                (status == BookingStatus.completed && index == currentIndex);
            final isCurrent = index == currentIndex &&
                status != BookingStatus.completed &&
                status != BookingStatus.cancelled;

            return Expanded(
              child: Row(
                children: <Widget>[
                  _StepDot(done: isDone, current: isCurrent),
                  if (index != steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index < currentIndex
                            ? context.servio.success
                            : context.servio.border,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: steps
              .map(
                (step) => Expanded(
                  child: Text(
                    step,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.servio.textSecondary,
                        ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.done,
    required this.current,
  });

  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = done
        ? servio.success
        : current
            ? servio.warning
            : servio.border;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _InvoicePanel extends StatelessWidget {
  const _InvoicePanel({
    required this.baseRate,
    required this.platformFee,
    required this.parts,
    required this.total,
  });

  final int baseRate;
  final int platformFee;
  final int parts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: <Widget>[
          _InvoiceRow(label: 'Base rate', value: '$baseRate EGP'),
          _InvoiceRow(label: 'Platform fee', value: '$platformFee EGP'),
          _InvoiceRow(label: 'Parts', value: '$parts EGP'),
          Divider(color: servio.border),
          _InvoiceRow(label: 'Total', value: '$total EGP', highlight: true),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.credit_card_rounded, color: servio.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment method: Cash on Completion',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: highlight ? servio.accent : null,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalChips extends StatelessWidget {
  const _HorizontalChips({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final item = items[index];
          final active = item == selected;

          return GestureDetector(
            onTap: () => onSelected(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? servio.accent : servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Text(
                item,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active ? Colors.white : servio.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.md,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Icon(icon, color: servio.accent),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: servio.surfaceAlt,
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: servio.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: servio.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = danger ? servio.danger : servio.accent;

    return SizedBox(
      width: 140,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(color: color),
          foregroundColor: color,
        ),
      ),
    );
  }
}

class _VerificationBox extends StatelessWidget {
  const _VerificationBox({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.success),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.verified_rounded, color: servio.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Transaction verified for $reference',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAppointment extends StatelessWidget {
  const _TimelineAppointment({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: servio.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${booking.serviceName}  |  ${booking.date}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          ServioStatusChip(
            label: _statusLabel(booking.status),
            type: _chipType(booking.status),
          ),
        ],
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.serviceName});

  final String serviceName;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForService(serviceName);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: ServioGradients.warm,
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Icon(icon, color: ServioColors.deepBrown, size: 24),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.size,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ServioGradients.warm,
        shape: BoxShape.circle,
        border: Border.all(color: servio.accent, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ServioColors.deepBrown,
              ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: servio.border),
          boxShadow: ServioShadows.rest,
        ),
        child: Icon(icon, color: servio.accent),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ServioRadius.full),
      child: LinearProgressIndicator(
        minHeight: 6,
        value: value,
        backgroundColor: servio.border,
        valueColor: AlwaysStoppedAnimation<Color>(servio.accent),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.filled,
  });

  final int count;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Row(
      children: List<Widget>.generate(
        count,
        (int index) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: index < filled ? servio.accent : servio.border,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: servio.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
            ),
      ),
    );
  }
}

BookingFlowData _flowDataFor(BookingModel booking) {
  return BookingFlowData(
    serviceName: booking.serviceName,
    technicianName: booking.technicianName,
    date: booking.date,
    time: booking.time,
    location: booking.location,
    amount: booking.amount,
    reference: booking.reference,
  );
}

String _statusLabel(BookingStatus status) {
  return switch (status) {
    BookingStatus.upcoming => 'Pending',
    BookingStatus.inProgress => 'En Route',
    BookingStatus.completed => 'Completed',
    BookingStatus.cancelled => 'Cancelled',
  };
}

ServioStatusChipType _chipType(BookingStatus status) {
  return switch (status) {
    BookingStatus.upcoming => ServioStatusChipType.warning,
    BookingStatus.inProgress => ServioStatusChipType.info,
    BookingStatus.completed => ServioStatusChipType.success,
    BookingStatus.cancelled => ServioStatusChipType.danger,
  };
}

IconData _iconForService(String serviceName) {
  final lower = serviceName.toLowerCase();
  if (lower.contains('plumb')) return Icons.plumbing_rounded;
  if (lower.contains('electric')) return Icons.electrical_services_rounded;
  if (lower.contains('paint')) return Icons.format_paint_rounded;
  if (lower.contains('ac') || lower.contains('hvac')) {
    return Icons.ac_unit_rounded;
  }
  if (lower.contains('carp')) return Icons.handyman_rounded;
  return Icons.home_repair_service_rounded;
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

String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

int _amountValue(String amount) {
  final numeric = amount.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(numeric) ?? 0;
}

BookingModel _toBookingModel(BackendBooking b) {
  final date = DateFormat('dd/MM/yyyy').format(b.scheduledDate);
  final time = DateFormat('hh:mm a').format(b.scheduledDate);
  final shortId = b.id.length >= 6 ? b.id.substring(b.id.length - 6).toUpperCase() : b.id.toUpperCase();
  final location = [b.addressStreet, b.addressCity].where((s) => s.isNotEmpty).join(', ');
  return BookingModel(
    id: b.id,
    reference: '#SRV-$shortId',
    serviceName: b.serviceName.isNotEmpty ? b.serviceName : 'Service',
    technicianName: b.workerName.isNotEmpty ? b.workerName : 'Technician',
    technicianId: b.workerId,
    date: date,
    time: time,
    location: location.isNotEmpty ? location : 'N/A',
    amount: '${b.totalAmount.toStringAsFixed(0)} EGP',
    status: _parseBookingStatus(b.status),
    pin: b.id.length >= 4 ? b.id.substring(b.id.length - 4) : b.id,
    notes: b.notes,
  );
}

BookingStatus _parseBookingStatus(String status) {
  return switch (status.toLowerCase()) {
    'in_progress' || 'inprogress' || 'active' => BookingStatus.inProgress,
    'completed' || 'done' => BookingStatus.completed,
    'cancelled' || 'canceled' => BookingStatus.cancelled,
    _ => BookingStatus.upcoming,
  };
}
