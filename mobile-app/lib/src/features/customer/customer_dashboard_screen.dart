import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/notifications_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../booking/booking_flow_data.dart';
import '../messages/chat_screen.dart';
import '../shared/notifications_screen.dart';
import 'ai_finishing_estimator_screen.dart';
import 'customer_profile_screen.dart';
import 'my_bookings_screen.dart';

import 'services_marketplace_screen.dart';

enum _DashboardSection { overview, bookings, history }

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
  bool _isLoading = false;
  String? _fetchError;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookings());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final raw = await BookingsApi(client).getMyBookings();
      if (mounted) {
        setState(() {
          _bookings = raw.map(_toBookingModel).toList();
          _fetchError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _fetchError = 'Could not load your bookings.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bookings = _bookings;

    final userName =
        context.watch<SessionProvider>().account?.name.split(' ').first ??
            'Customer';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          // 1. Dynamic Parallax Background
          AnimatedBuilder(
            animation: _scrollController,
            builder: (BuildContext context, Widget? child) {
              double offset = 0;
              if (_scrollController.hasClients) {
                offset = _scrollController.offset;
                if (offset < 0) offset = 0;
              }
              return Positioned(
                top: -offset * 0.4,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.55,
                child: child!,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient:
                    isDark ? ServioGradients.brandDark : ServioGradients.brand,
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: -40,
                    right: -60,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: -80,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Foreground Scrolling Content
          RefreshIndicator(
            color: ServioColors.accentLight,
            onRefresh: _fetchBookings,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                // Header Section
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Logo & Brand Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(ServioRadius.sm),
                                ),
                                child: const Icon(
                                    Icons.home_repair_service_rounded,
                                    color: Colors.white,
                                    size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'SERVIO',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Spacer(),
                              // Notification Icon
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const NotificationsScreen()),
                                  );
                                },
                                child: Consumer<NotificationsProvider>(
                                  builder: (context, notifProvider, _) {
                                    final unread = notifProvider.unreadCount;
                                    return Stack(
                                      alignment: Alignment.topRight,
                                      children: <Widget>[
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.notifications_none_rounded,
                                              color: Colors.white,
                                              size: 22),
                                        ),
                                        if (unread > 0)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                  minWidth: 14, minHeight: 14),
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: ServioColors.danger,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                unread > 9 ? '9+' : '$unread',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Profile Avatar
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const CustomerProfileScreen()),
                                  );
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : 'C',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Dashboard Title
                          Text(
                            '$userName\'s Dashboard',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Segmented Control inside the hero
                          _DashboardSegmentedControl(
                            current: _section,
                            onChanged: (value) =>
                                setState(() => _section = value),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Layered Sheet Section
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // ── Error Banner ──────────────────────────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return SizeTransition(
                              sizeFactor: CurvedAnimation(
                                parent: animation,
                                curve: ServioMotion.spring,
                              ),
                              axisAlignment: -1,
                              child: FadeTransition(
                                  opacity: animation, child: child),
                            );
                          },
                          child: _fetchError != null
                              ? Padding(
                                  key: const ValueKey<String>('error-banner'),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ServioColors.tint(
                                          ServioColors.danger),
                                      borderRadius: BorderRadius.circular(
                                          ServioRadius.md),
                                      border: Border.all(
                                        color: ServioColors.danger
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.wifi_off_rounded,
                                          color: ServioColors.danger,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _fetchError!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: ServioColors.danger,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _isLoading
                                              ? null
                                              : _fetchBookings,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ServioColors.danger,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      ServioRadius.sm),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Retry',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey<String>('no-error'),
                                ),
                        ),

                        // ── Section Content ───────────────────────────────────
                        AnimatedSwitcher(
                          duration: ServioMotion.tabSwitch,
                          switchInCurve: ServioMotion.spring,
                          switchOutCurve: ServioMotion.standard,
                          layoutBuilder: (Widget? currentChild,
                              List<Widget> previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
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
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBooking() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServicesMarketplaceScreen(),
      ),
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          contactName: booking.technicianName,
          bookingId: booking.id,
          workerId: booking.technicianId,
        ),
      ),
    );
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    // Guard: backend only allows cancellation of pending bookings.
    if (booking.status != BookingStatus.pending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only pending bookings can be cancelled. '
                'This booking is already ${switch (booking.status) {
              BookingStatus.confirmed => 'confirmed',
              BookingStatus.enRoute => 'en route',
              BookingStatus.arrived => 'arrived',
              BookingStatus.inProgress => 'in progress',
              BookingStatus.awaitingCustomerConfirmation =>
                'awaiting your confirmation',
              BookingStatus.completed => 'completed',
              BookingStatus.cancelled => 'cancelled',
              BookingStatus.rejected => 'rejected',
              BookingStatus.disputed => 'disputed',
              BookingStatus.pending => 'pending',
              BookingStatus.pendingAdminReview => 'under review',
            }}.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

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
    final active = bookings.where((b) => b.status.isActive).toList();
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
        const _EstimatorPromptCard(),
        const SizedBox(height: 18),
        _StatsGrid(
          totalBookings: bookings.length,
          activeCount: active.length,
          completedJobs:
              bookings.where((b) => b.status == BookingStatus.completed).length,
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
          'Active' => booking.status.isActive,
          'Pending' => booking.status == BookingStatus.pending,
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
        const SizedBox(height: 24),
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
    'This Month',
    'Cash',
    'Clear All',
  ];

  @override
  Widget build(BuildContext context) {
    final history = _filteredHistory(bookings, filter);
    final completed =
        bookings.where((b) => b.status == BookingStatus.completed).toList();
    final spent = completed.fold<int>(
      0,
      (sum, booking) => sum + _amountValue(booking.amount),
    );
    final topService = _topService(bookings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MiniSummaryCard(
                label: 'All Bookings',
                value: '${bookings.length}',
                icon: Icons.history_rounded,
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
            Expanded(
              child: _MiniSummaryCard(
                label: 'Top Service',
                value: topService,
                icon: Icons.plumbing_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _HorizontalChips(
          items: _filters,
          selected: filter,
          onSelected: (value) => onFilterChanged(
            value == 'Clear All' ? 'All' : value,
          ),
        ),
        const SizedBox(height: 24),
        if (history.isEmpty)
          const _EmptyDashboardState(message: 'No bookings yet.')
        else
          ...List<Widget>.generate(history.length, (int index) {
            final booking = history[index];
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: 360 + index * 70),
              curve: ServioMotion.curve,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 14),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _HistoryBookingTile(booking: booking),
              ),
            );
          }),
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
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _labels.entries.map((entry) {
          final section = entry.key;
          final label = entry.value;
          final active = section == current;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(section),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: ServioMotion.micro,
                curve: ServioMotion.spring,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                  boxShadow: active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: active ? ServioColors.navyDark : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

class _EstimatorPromptCard extends StatelessWidget {
  const _EstimatorPromptCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Icon(
              Icons.calculate_rounded,
              color: servio.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('AI Cost Estimator', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Get a room finishing budget before you book.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Open estimator',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AiFinishingEstimatorScreen(),
              ),
            ),
            icon: Icon(
              Icons.arrow_forward_rounded,
              color: servio.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalBookings,
    required this.activeCount,
    required this.completedJobs,
    required this.totalSpent,
  });

  final int totalBookings;
  final int activeCount;
  final int completedJobs;
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
          footer: const Text('Active jobs'),
        ),
        _KpiCard(
          label: 'Completed Jobs',
          value: '$completedJobs',
          icon: Icons.check_circle_outline_rounded,
          color: context.servio.success,
          footer: const _ProgressDots(count: 5, filled: 4),
        ),
        _KpiCard(
          label: 'Total Spent',
          value: '$totalSpent EGP',
          icon: Icons.account_balance_wallet_outlined,
          color: context.servio.warning,
          footer: const Text('Lifetime total'),
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
              // Only show Cancel for pending bookings — backend rejects
              // cancellation of accepted/in-progress/completed bookings.
              if (booking.status == BookingStatus.pending)
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
                      paymentMethod: _paymentLabelFor(booking),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            ServioStatusChip(
                              label: _statusLabel(booking.status),
                              type: _chipType(booking.status),
                            ),
                            ServioStatusChip(
                              label: _paymentLabelFor(booking),
                              type: ServioStatusChipType.neutral,
                            ),
                          ],
                        ),
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
                          paymentMethod: _paymentLabelFor(booking),
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
      'Arrived',
      'In Progress',
      'Completed'
    ];
    final currentIndex = switch (status) {
      BookingStatus.pending => 0,
      BookingStatus.confirmed => 1,
      BookingStatus.enRoute => 2,
      BookingStatus.arrived => 3,
      BookingStatus.inProgress => 4,
      BookingStatus.awaitingCustomerConfirmation => 4,
      BookingStatus.completed => 5,
      BookingStatus.cancelled => 0,
      BookingStatus.rejected => 0,
      BookingStatus.disputed => 0,
      BookingStatus.pendingAdminReview => 4,
    };

    return Column(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(steps.length, (int index) {
            final isDone = index < currentIndex ||
                (status == BookingStatus.completed && index == currentIndex);
            final isCurrent = index == currentIndex && status.isActive;

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
    required this.paymentMethod,
  });

  final int baseRate;
  final int platformFee;
  final int parts;
  final int total;
  final String paymentMethod;

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
                  'Payment method: $paymentMethod',
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
        border: Border.all(color: servio.success.withValues(alpha: 0.18)),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: servio.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded,
              color: servio.textSecondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: servio.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

BookingFlowData _flowDataFor(BookingModel booking) {
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
    statusLabel: _statusLabel(booking.status),
    statusCode: _statusCodeFromStatus(booking.status),
  );
}

String _statusLabel(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => 'Pending',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.enRoute => 'En Route',
    BookingStatus.arrived => 'Arrived',
    BookingStatus.inProgress => 'In Progress',
    BookingStatus.awaitingCustomerConfirmation => 'Awaiting Your Confirmation',
    BookingStatus.completed => 'Completed',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.rejected => 'Rejected',
    BookingStatus.disputed => 'Disputed',
    BookingStatus.pendingAdminReview => 'Under Review',
  };
}

ServioStatusChipType _chipType(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => ServioStatusChipType.warning,
    BookingStatus.confirmed => ServioStatusChipType.success,
    BookingStatus.enRoute => ServioStatusChipType.info,
    BookingStatus.arrived => ServioStatusChipType.info,
    BookingStatus.inProgress => ServioStatusChipType.info,
    BookingStatus.awaitingCustomerConfirmation => ServioStatusChipType.warning,
    BookingStatus.completed => ServioStatusChipType.success,
    BookingStatus.cancelled => ServioStatusChipType.danger,
    BookingStatus.rejected => ServioStatusChipType.danger,
    BookingStatus.disputed => ServioStatusChipType.warning,
    BookingStatus.pendingAdminReview => ServioStatusChipType.warning,
  };
}

String _statusCodeFromStatus(BookingStatus status) => switch (status) {
      BookingStatus.pending => 'pending',
      BookingStatus.confirmed => 'confirmed',
      BookingStatus.enRoute => 'en_route',
      BookingStatus.arrived => 'arrived',
      BookingStatus.inProgress => 'in_progress',
      BookingStatus.awaitingCustomerConfirmation =>
        'awaiting_customer_confirmation',
      BookingStatus.completed => 'completed',
      BookingStatus.cancelled => 'cancelled',
      BookingStatus.rejected => 'rejected',
      BookingStatus.disputed => 'disputed',
      BookingStatus.pendingAdminReview => 'pending_admin_review',
    };

String _paymentLabelFor(BookingModel booking) {
  if (booking.paymentMethod.toLowerCase().contains('card')) {
    final card = _cardLabelFor(booking);
    return card.isEmpty ? 'Credit Card' : 'Credit Card - $card';
  }
  return booking.paymentMethod.trim().isEmpty ? 'Cash' : booking.paymentMethod;
}

String _cardLabelFor(BookingModel booking) {
  if (booking.paymentCardLabel.isNotEmpty) return booking.paymentCardLabel;
  if (booking.paymentCardLast4.isNotEmpty) {
    return 'Card ending ${booking.paymentCardLast4}';
  }
  return '';
}

List<BookingModel> _filteredHistory(
    List<BookingModel> bookings, String filter) {
  final now = DateTime.now();
  return bookings.where((booking) {
    return switch (filter) {
      'This Month' => _bookingIsThisMonth(booking.date, now),
      'Cash' => booking.paymentMethod.toLowerCase().contains('cash'),
      _ => true, // 'All' and 'Clear All' resets
    };
  }).toList();
}

/// Parses `booking.date` (formats: 'dd/MM/yyyy', 'MMMM d, yyyy', ISO) and
/// returns true if the booking falls in the current month + year.
bool _bookingIsThisMonth(String dateStr, DateTime now) {
  // Try dd/MM/yyyy (most common in Servio UI)
  final slashParts = dateStr.split('/');
  if (slashParts.length == 3) {
    final day = int.tryParse(slashParts[0]);
    final month = int.tryParse(slashParts[1]);
    final year = int.tryParse(slashParts[2]);
    if (day != null && month != null && year != null) {
      return month == now.month && year == now.year;
    }
  }
  // Try ISO or any parseable format
  final parsed = DateTime.tryParse(dateStr);
  if (parsed != null) {
    return parsed.month == now.month && parsed.year == now.year;
  }
  return true; // Cannot parse — include rather than silently exclude
}

String _topService(List<BookingModel> bookings) {
  if (bookings.isEmpty) return 'None';
  final counts = <String, int>{};
  for (final booking in bookings) {
    counts.update(booking.serviceName, (value) => value + 1, ifAbsent: () => 1);
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
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
  final time = b.scheduledTime.isNotEmpty
      ? _displayScheduledTime(b.scheduledTime)
      : DateFormat('hh:mm a').format(b.scheduledDate);
  final shortId = b.id.length >= 6
      ? b.id.substring(b.id.length - 6).toUpperCase()
      : b.id.toUpperCase();
  final location =
      [b.addressStreet, b.addressCity].where((s) => s.isNotEmpty).join(', ');
  return BookingModel(
    id: b.id,
    reference: '#SRV-$shortId',
    serviceName: b.serviceName.isNotEmpty ? b.serviceName : 'Service',
    serviceId: b.serviceId,
    serviceCategory: b.serviceCategory,
    technicianName: b.workerName.isNotEmpty ? b.workerName : 'Technician',
    technicianId: b.workerId,
    date: date,
    time: time,
    location: location.isNotEmpty ? location : 'N/A',
    amount: '${b.totalAmount.toStringAsFixed(0)} EGP',
    status: _parseBookingStatus(b.status),
    pin: b.pin,
    paymentMethod: _paymentMethodLabel(b.paymentMethod),
    paymentCardLabel: b.paymentCardLabel,
    paymentCardLast4: b.paymentCardLast4,
    notes: b.notes,
  );
}

String _displayScheduledTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:00 $suffix';
}

BookingStatus _parseBookingStatus(String status) {
  return switch (status.toLowerCase()) {
    'pending' => BookingStatus.pending,
    'confirmed' || 'accepted' || 'scheduled' => BookingStatus.confirmed,
    'en_route' || 'enroute' => BookingStatus.enRoute,
    'arrived' => BookingStatus.arrived,
    'in_progress' || 'inprogress' || 'active' => BookingStatus.inProgress,
    'completed' || 'done' => BookingStatus.completed,
    'cancelled' || 'canceled' => BookingStatus.cancelled,
    'rejected' => BookingStatus.rejected,
    'disputed' => BookingStatus.disputed,
    _ => BookingStatus.pending,
  };
}

String _paymentMethodLabel(String value) {
  return switch (value.toLowerCase()) {
    'card' || 'online' => 'Credit Card',
    'cash' => 'Cash',
    _ => value.trim().isEmpty ? 'Cash' : value,
  };
}
