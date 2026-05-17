import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/users_api.dart';
import '../../core/models/booking_model.dart';
import '../../core/state/notifications_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_skeleton.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../booking/booking_flow_data.dart';
import '../booking/booking_step_one_screen.dart';
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
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookings());
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    try {
      final client = context.read<ApiClient>();
      final raw = await BookingsApi(client).getMyBookings();
      if (mounted) {
        setState(() {
          _bookings = raw.map(BookingModel.fromBackend).toList();
        });
      }
    } catch (_) {}
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

  Future<void> _pullRefresh() async {
    setState(() => _loading = true);
    await Future.wait(<Future<void>>[
      _fetchBookings(),
      _refreshNotifications(),
    ]);
  }

  Future<void> _refreshNotifications() async {
    try {
      await context.read<NotificationsProvider>().refresh();
    } catch (_) {
      // Non-critical — booking refresh still succeeds.
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
      body: RefreshIndicator(
        color: context.servio.accent,
        onRefresh: _pullRefresh,
        child: Padding(
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
      ),
    );
  }

  Widget _buildTabContent() {
    if (_loading) {
      return ListView.separated(
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => const ServioSkeleton(height: 140, radius: 16),
      );
    }
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
              onRebook: () => _rebook(context, booking),
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
        final history = _bookings.where((b) => b.status.isPast).toList();
        if (history.isEmpty) {
          return const _EmptyState(message: 'No completed bookings yet.');
        }
        return ListView.separated(
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (BuildContext context, int index) {
            final booking = history[index];
            return _LiveBookingCard(
              booking: booking,
              onRebook: () => _rebook(context, booking),
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
        return _EmptyState(
          icon: Icons.favorite_border_rounded,
          message: 'Your favourite technicians will appear here\n'
              'after you complete a booking and write a review.',
        );
    }
  }

  Future<void> _rebook(BuildContext context, BookingModel booking) async {
    var data = _rebookFlowDataFromBooking(booking);
    if (data.technicianId.trim().isNotEmpty &&
        data.technicianAvailability.isEmpty) {
      try {
        final client = context.read<ApiClient>();
        final worker = await UsersApi(client).getWorkerById(data.technicianId);
        data = data.copyWith(
          technicianAvailability: worker.availability,
          technicianName: worker.displayName,
          hourlyRate: worker.hourlyRate > 0
              ? '${worker.hourlyRate} EGP/hr'
              : data.hourlyRate,
        );
      } catch (_) {
        // The booking flow can still open; final booking validation remains
        // enforced by the backend if availability cannot be refreshed here.
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingStepOneScreen(
          data: data,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 40, color: servio.textSecondary),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: servio.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBookingCard extends StatelessWidget {
  const _LiveBookingCard({
    required this.booking,
    required this.onViewDetails,
    required this.onRebook,
  });

  final BookingModel booking;
  final VoidCallback onViewDetails;
  final VoidCallback onRebook;

  static ServioStatusChipType _chipType(BookingStatus status) =>
      switch (status) {
        BookingStatus.pending => ServioStatusChipType.warning,
        BookingStatus.confirmed => ServioStatusChipType.success,
        BookingStatus.enRoute => ServioStatusChipType.info,
        BookingStatus.arrived => ServioStatusChipType.info,
        BookingStatus.inProgress => ServioStatusChipType.info,
        BookingStatus.awaitingCustomerConfirmation =>
          ServioStatusChipType.warning,
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
        BookingStatus.awaitingCustomerConfirmation => 'Awaiting Your Confirmation',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.disputed => 'Disputed',
      };

  Color _accentColor(ServioThemeExtension servio) => switch (booking.status) {
        BookingStatus.cancelled ||
        BookingStatus.rejected ||
        BookingStatus.disputed =>
          servio.danger,
        BookingStatus.completed => servio.success,
        _ => servio.info,
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
            height: 110,
            decoration: BoxDecoration(
              color: _accentColor(servio),
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
                              onPressed: onRebook,
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

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    this.data = const BookingFlowData(),
  });

  final BookingFlowData data;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _cancelling = false;
  bool _confirming = false;

  Future<void> _confirmCompletion() async {
    if (_confirming) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Job Completion'),
        content: const Text(
          'By confirming, you acknowledge the job is done and release payment to the technician.\n\nThis action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, Confirm',
              style: TextStyle(color: context.servio.accent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client)
          .updateStatus(widget.data.backendId, 'completed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job confirmed! Payment has been released. Thank you.'),
        ),
      );
      _leaveDetails(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not confirm completion. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  /// Shows a bottom sheet asking for a cancellation reason, then cancels
  /// the booking with that reason sent to the backend.
  Future<void> _cancelBooking() async {
    if (_cancelling) return;

    // ── Step 1: collect a reason ───────────────────────────────────────────
    final reasons = <String>[
      'Change of plans',
      'Found another provider',
      'Technician did not respond',
      'Scheduled time is no longer suitable',
      'Other',
    ];
    String selectedReason = reasons.first;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final servio = ctx.servio;
            final theme = Theme.of(ctx);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: servio.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('Cancel Booking',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Please tell us why you are cancelling.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    ...reasons.map((reason) => RadioListTile<String>(
                          title: Text(reason),
                          value: reason,
                          groupValue: selectedReason,
                          onChanged: (val) {
                            if (val != null) setSheet(() => selectedReason = val);
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Keep Booking'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: servio.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Confirm Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // ── Step 2: send cancellation with reason ──────────────────────────────
    setState(() => _cancelling = true);
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client).updateStatus(
        widget.data.backendId,
        'cancelled',
        reason: selectedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully.')),
      );
      _leaveDetails(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel booking. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
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
                          child: Text(data.technicianName,
                              style: theme.textTheme.titleMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
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
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 16),
                        label: const Text('Message Technician'),
                      ),
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
              // ── Map / Address deep link (HIGH-05) ─────────────────────────────
              if (data.location.trim().isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    final query = Uri.encodeComponent(data.location.trim());
                    final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$query');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.lg),
                      border: Border.all(color: servio.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.location_on_outlined,
                            color: servio.accent, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            data.location.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.accent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.open_in_new_rounded,
                            size: 16, color: servio.textSecondary),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Write a Review — only available once the job is completed.
              if (data.statusCode == 'completed')
                OutlinedButton(
                  onPressed: () {
                    if (data.backendId.trim().isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WriteReviewScreen(
                            technicianName: data.technicianName,
                            jobSummary: data.serviceName,
                            bookingId: data.backendId,
                          ),
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Booking details are still loading. Please try again.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Write a Review'),
                ),
              // ── Confirm Completion — awaiting customer confirmation ──
              if (data.statusCode == 'awaiting_customer_confirmation') ...<Widget>[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.accent),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    border: Border.all(
                        color: servio.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.check_circle_outline_rounded,
                              color: servio.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Job Complete — Please Confirm',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: servio.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your technician has finished the job. '  
                        'Confirm completion to release payment.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      _confirming
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _confirmCompletion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: servio.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(ServioRadius.md),
                                ),
                              ),
                              icon: const Icon(
                                  Icons.verified_rounded, size: 18),
                              label: const Text('Confirm Job Complete'),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),
              // Cancel is only available for pending bookings.
              if (data.statusCode == 'pending')
                _cancelling
                    ? const Center(child: CircularProgressIndicator())
                    : OutlinedButton(
                        onPressed: _cancelBooking,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: servio.danger),
                          foregroundColor: servio.danger,
                        ),
                        child: const Text('Cancel Booking'),
                      )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: servio.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Cancellation unavailable — booking is ${data.statusLabel.toLowerCase()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      'awaiting_customer_confirmation' => 4,
      'completed' => 5,
      _ => -1,
    };

    if (level == -1) {
      // ── Terminal / edge states ────────────────────────────────────────────────
      final (terminalLabel, terminalMeta) = switch (data.statusCode) {
        'cancelled' || 'canceled' => (
          'Booking Cancelled',
          'This booking was cancelled. You can re-book anytime.',
        ),
        'rejected' => (
          'Booking Declined',
          'The technician was unable to accept this booking.',
        ),
        'disputed' => (
          'Under Review',
          'This booking has been flagged for admin review. '
              'Our team will reach out within 24–8 hours.',
        ),
        'pending_admin_review' => (
          'Pending Admin Review',
          'Our support team is reviewing this booking.',
        ),
        _ => (
          data.statusLabel,
          'This booking is currently ${data.statusLabel.toLowerCase()}.',
        ),
      };
      return <Widget>[
        _TimelineRow(
          label: 'Booking Placed',
          complete: true,
          meta: '${data.date} ${data.time.split('-').first.trim()}',
        ),
        _TimelineRow(
          label: terminalLabel,
          complete: false,
          active: data.statusCode == 'disputed' ||
              data.statusCode == 'pending_admin_review',
          meta: terminalMeta,
        ),
      ];
    }

    final isCash = data.paymentMethodCode != 'card';

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
        meta: level == 0
            ? 'Waiting for technician to confirm'
            : 'Technician has accepted the booking',
      ),
      _TimelineRow(
        label: isCash ? 'Payment Method (Cash)' : 'Payment Authorized',
        complete: isCash ? level >= 5 : level >= 0,
        active: isCash ? level < 5 : false,
        meta: isCash
            ? 'Cash payment due upon completion'
            : 'Card payment confirmed via Escrow',
      ),
      _TimelineRow(
        label: 'In Progress',
        complete: level >= 4,
        active: level == 3 || level == 2,
        meta: level < 2
            ? 'Upcoming'
            : (level < 4
                ? 'Technician is working on your service'
                : 'Finished'),
      ),
      _TimelineRow(
        label: 'Awaiting Your Confirmation',
        complete: level >= 5,
        active: level == 4,
        meta: level == 4
            ? 'Technician finished — please confirm to release payment'
            : (level >= 5 ? 'Confirmed' : 'Upcoming'),
      ),
      _TimelineRow(
        label: 'Completed',
        complete: level == 5,
        active: false,
        meta: level == 5 ? 'Job done' : 'Upcoming',
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
    serviceId: booking.serviceId,
    category: booking.serviceCategory,
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

BookingFlowData _rebookFlowDataFromBooking(BookingModel booking) {
  return BookingFlowData(
    serviceName: booking.serviceName,
    serviceId: booking.serviceId,
    category: booking.serviceCategory,
    technicianName: booking.technicianName,
    technicianId: booking.technicianId,
    specialty: booking.serviceName,
    priceLabel: booking.amount,
    hourlyRate: booking.amount,
    notes: booking.notes,
    paymentMethod: booking.paymentMethod,
    paymentMethodCode:
        booking.paymentMethod.toLowerCase().contains('card') ? 'card' : 'cash',
    savedCardLabel: _cardLabelFor(booking),
    savedCardLast4: booking.paymentCardLast4,
    technicianAvailability: booking.technicianAvailability,
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
      BookingStatus.awaitingCustomerConfirmation =>
        'awaiting_customer_confirmation',
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
    'awaiting_customer_confirmation' ||
    'awaitingcustomerconfirmation' =>
      ServioStatusChipType.warning,
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
