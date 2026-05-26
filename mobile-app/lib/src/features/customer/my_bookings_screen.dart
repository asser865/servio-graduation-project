import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/users_api.dart';
import '../../core/models/booking_model.dart';
import '../../core/state/disputes_provider.dart';
import '../../core/state/notifications_provider.dart';
import 'raise_dispute_screen.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
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
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
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

  Future<void> _cancelBooking(BookingModel booking) async {
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
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
                    Text(
                      'Cancel Booking',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please tell us why you are cancelling.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    ...reasons.map((reason) => RadioListTile<String>(
                          title: Text(reason),
                          value: reason,
                          groupValue: selectedReason,
                          onChanged: (val) {
                            if (val != null) {
                              setSheet(() => selectedReason = val);
                            }
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

    setState(() => _loading = true);
    final client = context.read<ApiClient>();
    try {
      await BookingsApi(client).updateStatus(
        booking.id,
        'cancelled',
        reason: selectedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully.')),
      );
      _fetchBookings();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel booking. Please try again.'),
        ),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const tabs = <String>['Active', 'History'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        actions: const <Widget>[],
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
        ),
      ),
      body: RefreshIndicator(
        color: servio.accent,
        onRefresh: _pullRefresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: servio.border.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: List<Widget>.generate(tabs.length, (int index) {
                    final active = index == _tabIndex;
                    final activeColor = isDark ? servio.neutralWarm : const Color(0xFF1A1D23);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tabIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: active ? activeColor : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            tabs[index],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontFamily: 'Inter',
                              fontWeight: active ? FontWeight.bold : FontWeight.w500,
                              color: active ? activeColor : servio.textSecondary,
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
              onCancel: () => _cancelBooking(booking),
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(
                      data: bookingFlowDataFromModel(booking),
                    ),
                  ),
                );
              },
              onRaiseDispute: booking.status == BookingStatus.awaitingCustomerConfirmation
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RaiseDisputeScreen(booking: booking),
                        ),
                      )
                  : null,
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
              onCancel: () => _cancelBooking(booking),
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(
                      data: bookingFlowDataFromModel(booking),
                    ),
                  ),
                );
              },
              onRaiseDispute: booking.status == BookingStatus.awaitingCustomerConfirmation
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RaiseDisputeScreen(booking: booking),
                        ),
                      )
                  : null,
            );
          },
        );
      default:
        return const SizedBox.shrink();
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
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: servio.textSecondary,
                  ),
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
    required this.onCancel,
    this.onRaiseDispute,
  });

  final BookingModel booking;
  final VoidCallback onViewDetails;
  final VoidCallback onRebook;
  final VoidCallback onCancel;
  final VoidCallback? onRaiseDispute;

  static String _chipLabel(BookingStatus status) => switch (status) {
        BookingStatus.pending => 'Pending',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.enRoute => 'En Route',
        BookingStatus.arrived => 'Arrived',
        BookingStatus.inProgress => 'In Progress',
        BookingStatus.awaitingCustomerConfirmation => 'Awaiting Confirmation',
        BookingStatus.pendingAdminReview => 'Under Review',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.disputed => 'Disputed',
        BookingStatus.cancelledNoShow => 'Cancelled (No-Show)',
        BookingStatus.customerNoShow => 'Customer No-Show',
        BookingStatus.workerNoShow => 'Worker No-Show',
      };

  Color _statusBgColor(BookingStatus status, bool isDark) {
    if (isDark) {
      return switch (status) {
        BookingStatus.pending => const Color(0xFF343A40),
        BookingStatus.confirmed || BookingStatus.completed => const Color(0xFF0F5132).withValues(alpha: 0.3),
        BookingStatus.cancelled || BookingStatus.rejected || BookingStatus.cancelledNoShow || BookingStatus.workerNoShow || BookingStatus.customerNoShow => const Color(0xFF842029).withValues(alpha: 0.3),
        BookingStatus.disputed || BookingStatus.awaitingCustomerConfirmation || BookingStatus.pendingAdminReview => const Color(0xFF664D03).withValues(alpha: 0.3),
        _ => const Color(0xFFF2E0C4).withValues(alpha: 0.2),
      };
    } else {
      return switch (status) {
        BookingStatus.pending => const Color(0xFFE4E2DF),
        BookingStatus.confirmed || BookingStatus.completed => const Color(0xFFD1E7DD),
        BookingStatus.cancelled || BookingStatus.rejected || BookingStatus.cancelledNoShow || BookingStatus.workerNoShow || BookingStatus.customerNoShow => const Color(0xFFF8D7DA),
        BookingStatus.disputed || BookingStatus.awaitingCustomerConfirmation || BookingStatus.pendingAdminReview => const Color(0xFFFFF3CD),
        _ => const Color(0xFFF2E0C4),
      };
    }
  }

  Color _statusTextColor(BookingStatus status, bool isDark) {
    if (isDark) {
      return switch (status) {
        BookingStatus.pending => const Color(0xFFE3D5CA),
        BookingStatus.confirmed || BookingStatus.completed => const Color(0xFF75B798),
        BookingStatus.cancelled || BookingStatus.rejected || BookingStatus.cancelledNoShow || BookingStatus.workerNoShow || BookingStatus.customerNoShow => const Color(0xFFEA868F),
        BookingStatus.disputed || BookingStatus.awaitingCustomerConfirmation || BookingStatus.pendingAdminReview => const Color(0xFFFFDA6A),
        _ => const Color(0xFFBFB09A),
      };
    } else {
      return switch (status) {
        BookingStatus.pending => const Color(0xFF45474B),
        BookingStatus.confirmed || BookingStatus.completed => const Color(0xFF0F5132),
        BookingStatus.cancelled || BookingStatus.rejected || BookingStatus.cancelledNoShow || BookingStatus.workerNoShow || BookingStatus.customerNoShow => const Color(0xFF842029),
        BookingStatus.disputed || BookingStatus.awaitingCustomerConfirmation || BookingStatus.pendingAdminReview => const Color(0xFF664D03),
        _ => const Color(0xFF9A8C73),
      };
    }
  }

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('plumbing')) return Icons.plumbing_rounded;
    if (lower.contains('electrical') || lower.contains('electricity')) return Icons.electrical_services_rounded;
    if (lower.contains('cleaning') || lower.contains('clean')) return Icons.cleaning_services_rounded;
    if (lower.contains('ac') || lower.contains('air conditioning') || lower.contains('hvac')) return Icons.ac_unit_rounded;
    if (lower.contains('painting') || lower.contains('paint')) return Icons.format_paint_rounded;
    if (lower.contains('carpentry') || lower.contains('wood')) return Icons.carpenter_rounded;
    if (lower.contains('appliance') || lower.contains('washing')) return Icons.kitchen_rounded;
    return Icons.handyman_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    final secondButton = _secondButton(context, isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(26, 29, 37, 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D23) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(26, 29, 37, 0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _categoryIcon(booking.serviceCategory),
                  size: 22,
                  color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF343A40) : const Color(0xFFE4E2DF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            booking.serviceCategory.isNotEmpty ? booking.serviceCategory : booking.serviceName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF262B34),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusBgColor(booking.status, isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _statusTextColor(booking.status, isDark),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _chipLabel(booking.status),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusTextColor(booking.status, isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      booking.serviceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'with ${booking.technicianName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'Inter',
                        color: servio.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: servio.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          booking.date,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: servio.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.schedule_rounded, size: 14, color: servio.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: servio.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                    foregroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (secondButton != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: secondButton.onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                      side: BorderSide(
                        color: isDark ? const Color(0xFFE3D5CA).withValues(alpha: 0.5) : const Color(0xFF9A8C73),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      secondButton.label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  _SecondButtonData? _secondButton(BuildContext context, bool isDark) {
    if (booking.status == BookingStatus.pending) {
      return _SecondButtonData(
        label: 'Cancel',
        onPressed: onCancel,
      );
    }
    if (booking.status.isActive) {
      return _SecondButtonData(
        label: 'Chat',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                contactName: booking.technicianName,
                bookingId: booking.id,
                workerId: booking.technicianId,
              ),
            ),
          );
        },
      );
    }
    if (booking.status.isPast) {
      return _SecondButtonData(
        label: 'Re-book',
        onPressed: onRebook,
      );
    }
    if (booking.status == BookingStatus.awaitingCustomerConfirmation && onRaiseDispute != null) {
      return _SecondButtonData(
        label: 'Report Problem',
        onPressed: onRaiseDispute!,
      );
    }
    return null;
  }
}

class _SecondButtonData {
  _SecondButtonData({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
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
  bool _disputeLoading = false;
  bool _pinRevealed = false;

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

  Future<void> _reportDispute() async {
    final controller = TextEditingController();
    final disputes = context.read<DisputesProvider>();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Builder(
          builder: (innerCtx) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(innerCtx).bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Report an Issue',
                      style: Theme.of(innerCtx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text('Describe the issue with this service.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter details…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          Navigator.of(ctx).pop(text);
                        },
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _disputeLoading = true);
    try {
      await disputes.openDispute(
        bookingId: widget.data.backendId,
        paymentId: '',
        reason: reason,
        category: 'other',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute filed. Our team will review it.')),
      );
      _leaveDetails(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to file dispute. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _disputeLoading = false);
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
                            if (val != null) {
                              setSheet(() => selectedReason = val);
                            }
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
              _buildPinSection(data, theme, servio),
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
              if (data.statusCode ==
                  'awaiting_customer_confirmation') ...<Widget>[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.accent),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    border:
                        Border.all(color: servio.accent.withValues(alpha: 0.3)),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(ServioRadius.md),
                                ),
                              ),
                              icon:
                                  const Icon(Icons.verified_rounded, size: 18),
                              label: const Text('Confirm Job Complete'),
                            ),
                      const SizedBox(height: 10),
                      _disputeLoading
                          ? const Center(child: CircularProgressIndicator())
                          : OutlinedButton.icon(
                              onPressed: _reportDispute,
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: const Text('Report a Problem'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ServioColors.danger,
                                side: const BorderSide(
                                    color: ServioColors.danger),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(ServioRadius.md),
                                ),
                              ),
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

  Widget _buildPinSection(
    BookingFlowData data,
    ThemeData theme,
    ServioThemeExtension servio,
  ) {
    final status = data.statusCode.toLowerCase();
    final rawPin = data.pin.trim();

    // Before technician arrives — locked
    if (status == 'pending' ||
        status == 'confirmed' ||
        status == 'accepted' ||
        status == 'scheduled' ||
        status == 'en_route' ||
        status == 'enroute') {
      return ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(Icons.lock_outline_rounded, color: servio.accent, size: 18),
              const SizedBox(width: 8),
              Text('Arrival PIN',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: servio.surfaceAlt,
                borderRadius: BorderRadius.circular(ServioRadius.md),
                border: Border.all(color: servio.border),
              ),
              child: Text(
                '● ● ● ●',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: servio.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'PIN will be revealed when your technician arrives.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    // Technician arrived — show reveal button
    if (status == 'arrived') {
      final pinDisplay =
          rawPin.isEmpty ? '----' : rawPin.split('').join('  ');
      return ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(Icons.lock_open_rounded,
                  color: ServioColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('Arrival PIN',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _pinRevealed
                  ? Container(
                      key: const ValueKey<String>('vis'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        color: servio.surfaceAlt,
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                        border: Border.all(color: servio.accent),
                      ),
                      child: Text(
                        pinDisplay,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey<String>('btn'),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Reveal PIN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: servio.accent,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ServioRadius.md),
                          ),
                        ),
                        onPressed: () => setState(() => _pinRevealed = true),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              'Share this PIN with your technician to start the service.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    // In progress — PIN already verified
    if (status == 'in_progress' || status == 'inprogress') {
      final pinDisplay =
          rawPin.isEmpty ? '----' : rawPin.split('').join('  ');
      return ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(Icons.verified_rounded,
                  color: ServioColors.success, size: 18),
              const SizedBox(width: 8),
              Text('PIN Verified',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: servio.surfaceAlt,
                borderRadius: BorderRadius.circular(ServioRadius.md),
                border: Border.all(color: servio.accent),
              ),
              child: Text(
                pinDisplay,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Service is in progress.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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

BookingFlowData bookingFlowDataFromModel(BookingModel booking) {
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
      BookingStatus.pendingAdminReview => 'pending_admin_review',
      BookingStatus.completed => 'completed',
      BookingStatus.cancelled => 'cancelled',
      BookingStatus.rejected => 'rejected',
      BookingStatus.disputed => 'disputed',
      BookingStatus.cancelledNoShow => 'cancelled_no_show',
      BookingStatus.customerNoShow => 'customer_no_show',
      BookingStatus.workerNoShow => 'worker_no_show',
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
    'awaitingcustomerconfirmation' ||
    'pending_admin_review' ||
    'disputed' =>
      ServioStatusChipType.warning,
    'cancelled' || 'canceled' || 'rejected' => ServioStatusChipType.danger,
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
