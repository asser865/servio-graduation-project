import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_shell.dart';
import '../customer/my_bookings_screen.dart'
    show BookingDetailsScreen, MyBookingsScreen;
import '../messages/chat_screen.dart';
import 'booking_flow_data.dart';

const _kFinalStatuses = {
  'completed',
  'done',
  'cancelled',
  'canceled',
  'rejected',
  'disputed',
};

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({
    required this.data,
    super.key,
  });

  final BookingFlowData data;

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;

  Timer? _pollTimer;
  Timer? _countdownTimer;

  late BookingFlowData _data;
  late ApiClient _apiClient;

  bool _pollingStarted = false;
  bool _refCopied = false;
  bool _pinRevealed = false;
  bool _confirmLoading = false;
  bool _disputeLoading = false;
  String? _actionError;
  Duration? _confirmationWindowRemaining;

  @override
  void initState() {
    super.initState();
    _data = widget.data;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<BookingsProvider>().refresh();
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiClient = context.read<ApiClient>();
    if (!_pollingStarted &&
        !_kFinalStatuses.contains(_data.statusCode.toLowerCase())) {
      _pollingStarted = true;
      _startPolling();
      if (_data.statusCode.toLowerCase() == 'pending') _startCountdown();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── polling ───────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || _data.backendId.isEmpty) return;
    try {
      final backend = await BookingsApi(_apiClient).getBooking(_data.backendId);
      if (!mounted) return;
      setState(() {
        _data = _data.copyWith(
          statusCode: backend.status,
          statusLabel: _labelForCode(backend.status),
          pin: backend.pin,
        );
      });
      if (_kFinalStatuses.contains(backend.status.toLowerCase())) {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
      }
    } catch (_) {}
  }

  // ── countdown ─────────────────────────────────────────────────────────────

  void _startCountdown() {
    final createdAt = _data.createdAt;
    if (createdAt == null) return;
    final deadline = createdAt.add(const Duration(minutes: 30));

    void tick() {
      if (!mounted) return;
      final remaining = deadline.difference(DateTime.now());
      setState(() => _confirmationWindowRemaining =
          remaining.isNegative ? Duration.zero : remaining);
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _copyReference() async {
    await Clipboard.setData(ClipboardData(text: _data.reference));
    setState(() => _refCopied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _refCopied = false);
  }

  Future<void> _confirmCompletion() async {
    setState(() {
      _confirmLoading = true;
      _actionError = null;
    });
    try {
      await BookingsApi(_apiClient).confirmCompletion(_data.backendId);
      if (!mounted) return;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _data =
            _data.copyWith(statusCode: 'completed', statusLabel: 'Completed');
        _confirmLoading = false;
      });
      try {
        context.read<BookingsProvider>().refresh();
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _confirmLoading = false;
        _actionError = 'Failed to confirm. Please try again.';
      });
    }
  }

  Future<void> _reportDispute() async {
    final reason = await _showDisputeDialog();
    if (reason == null) return;
    setState(() {
      _disputeLoading = true;
      _actionError = null;
    });
    try {
      await BookingsApi(_apiClient)
          .reportDispute(_data.backendId, reason: reason);
      if (!mounted) return;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _data = _data.copyWith(statusCode: 'disputed', statusLabel: 'Disputed');
        _disputeLoading = false;
      });
      try {
        context.read<BookingsProvider>().refresh();
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _disputeLoading = false;
        _actionError = 'Failed to file dispute. Please try again.';
      });
    }
  }

  Future<String?> _showDisputeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report an Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Describe the issue with this service.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter details…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showCancelSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(ServioRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        final theme = Theme.of(ctx);
        final servio = ctx.servio;
        return Padding(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
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
                'Cancel Booking?',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone. Free cancellation is available up to 2 hours before the appointment.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: servio.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ServioColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context
                      .read<BookingsProvider>()
                      .updateStatus(_data.backendId, BookingStatus.cancelled);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                        builder: (_) => const CustomerShell()),
                    (route) => false,
                  );
                },
                child: const Text('Yes, Cancel Booking'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                child: const Text('Keep Booking'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final statusCode = _data.statusCode.toLowerCase();
    final baseRate = _moneyValue(_data.amount);
    final platformFee = (baseRate * 0.05).round();
    final estimatedTotal = baseRate + platformFee;
    final estimatedTotalLabel = _moneyLabel(estimatedTotal);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 12),

              // ── Status-aware hero ─────────────────────────────────────────
              AnimatedSwitcher(
                duration: ServioMotion.normal,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale:
                        Tween<double>(begin: 0.92, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: _HeroSection(
                  key: ValueKey<String>(statusCode),
                  statusCode: statusCode,
                ),
              ),
              const SizedBox(height: 16),

              // ── Reference chip ────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _copyReference,
                  child: AnimatedContainer(
                    duration: ServioMotion.normal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: servio.surfaceAlt,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                      border: Border.all(color: servio.accent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _data.reference,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: servio.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: ServioMotion.fast,
                          child: _refCopied
                              ? const Icon(Icons.check_rounded,
                                  size: 16,
                                  color: ServioColors.success,
                                  key: ValueKey<String>('ok'))
                              : Icon(Icons.copy_rounded,
                                  size: 16,
                                  color: servio.accent,
                                  key: const ValueKey<String>('copy')),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _refCopied ? 'Copied!' : 'Tap to copy',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Pending confirmation countdown ────────────────────────────
              if (statusCode == 'pending' &&
                  _confirmationWindowRemaining != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildConfirmationWindow(theme, servio),
              ],

              const SizedBox(height: 20),

              // ── Status tracker ────────────────────────────────────────────
              _StatusTracker(
                pulse: _pulseController,
                statusCode: _data.statusCode,
                statusLabel: _data.statusLabel,
              ),

              // ── Awaiting confirmation card ────────────────────────────────
              if (statusCode == 'awaiting_customer_confirmation') ...<Widget>[
                const SizedBox(height: 16),
                _AwaitingConfirmationCard(
                  onConfirm: _confirmCompletion,
                  onDispute: _reportDispute,
                  confirmLoading: _confirmLoading,
                  disputeLoading: _disputeLoading,
                  error: _actionError,
                ),
              ],

              // ── Admin review banner ───────────────────────────────────────
              if (statusCode == 'pending_admin_review') ...<Widget>[
                const SizedBox(height: 16),
                ServioCard(
                  radius: ServioRadius.lg,
                  backgroundColor: ServioColors.tint(ServioColors.info),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.admin_panel_settings_rounded,
                          color: ServioColors.info, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Under Admin Review',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Our team is reviewing this case. You will be notified once a decision is made.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: servio.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── PIN card ──────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: KeyedSubtree(
                  key: ValueKey<String>(statusCode),
                  child: _buildPinSection(theme, servio),
                ),
              ),

              const SizedBox(height: 16),

              // ── Payment Summary ───────────────────────────────────────────
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Payment Summary',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    _ConfirmDetailRow(
                        label: 'Method', value: _data.paymentMethod),
                    if (_data.paymentMethodCode == 'card' &&
                        _data.savedCardLabel.isNotEmpty)
                      _ConfirmDetailRow(
                          label: 'Card', value: _data.savedCardLabel),
                    _ConfirmDetailRow(
                        label: 'Base Rate', value: '$baseRate EGP'),
                    _ConfirmDetailRow(
                        label: 'Platform Fee', value: '$platformFee EGP'),
                    const Divider(height: 20),
                    _ConfirmDetailRow(
                      label: 'Total',
                      value: estimatedTotalLabel,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Confirmation Details ──────────────────────────────────────
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Confirmation Details',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: ServioGradients.warm,
                            shape: BoxShape.circle,
                            border: Border.all(color: servio.accent, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              _data.technicianName
                                  .trim()
                                  .split(' ')
                                  .take(2)
                                  .map((w) => w[0])
                                  .join()
                                  .toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: ServioColors.deepBrown,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _data.technicianName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _data.specialty,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: servio.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ServioColors.tint(ServioColors.success),
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Text(
                            'Verified',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ServioColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _ConfirmDetailRow(
                        label: 'Service',
                        value: _data.serviceName,
                        icon: Icons.build_outlined),
                    _ConfirmDetailRow(
                        label: 'Date',
                        value: _data.date,
                        icon: Icons.calendar_today_outlined),
                    _ConfirmDetailRow(
                        label: 'Time Slot',
                        value: _data.time,
                        icon: Icons.access_time_rounded),
                    _ConfirmDetailRow(
                        label: 'Address',
                        value: _data.location,
                        icon: Icons.location_on_outlined),
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _ConfirmDetailRow(
                        label: 'Method',
                        value: _data.paymentMethod,
                        icon: Icons.payments_outlined),
                    if (_data.paymentMethodCode == 'card' &&
                        _data.savedCardLabel.isNotEmpty)
                      _ConfirmDetailRow(
                          label: 'Card',
                          value: _data.savedCardLabel,
                          icon: Icons.credit_card_rounded),
                    _ConfirmDetailRow(
                        label: 'Base Rate', value: '$baseRate EGP'),
                    _ConfirmDetailRow(
                        label: 'Platform Fee', value: '$platformFee EGP'),
                    _ConfirmDetailRow(
                      label: 'Est. Total',
                      value: estimatedTotalLabel,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────────────────
              ServioPrimaryButton(
                label: 'View Booking Details',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(data: _data),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Message Technician'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      contactName: _data.technicianName,
                      bookingId: _data.backendId,
                      workerId: _data.technicianId,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                ),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                      builder: (_) => const CustomerShell()),
                  (route) => false,
                ),
                child: const Text('Go to Dashboard'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyBookingsScreen(initialTabIndex: 1),
                  ),
                  (route) => false,
                ),
                child: Text(
                  'View Booking History',
                  style: TextStyle(color: servio.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                      builder: (_) => const CustomerShell()),
                  (route) => false,
                ),
                child: Text(
                  'Back to Home',
                  style: TextStyle(color: servio.textSecondary),
                ),
              ),
              if (statusCode == 'pending')
                TextButton(
                  onPressed: _showCancelSheet,
                  child: const Text(
                    'Cancel Booking',
                    style: TextStyle(color: ServioColors.danger),
                  ),
                )
              else if (!_kFinalStatuses.contains(statusCode))
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.lock_outline_rounded,
                          size: 14, color: servio.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Cancellation unavailable — booking is ${_data.statusLabel.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: servio.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ── Help card ─────────────────────────────────────────────────
              ServioCard(
                radius: ServioRadius.lg,
                backgroundColor: ServioColors.tint(ServioColors.info),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.support_agent_rounded,
                        color: ServioColors.info, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Need help?',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Our support team is available 24/7 to assist you with your booking.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'support@servio.app',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: ServioColors.info,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── helper widgets ────────────────────────────────────────────────────────

  Widget _buildConfirmationWindow(
      ThemeData theme, ServioThemeExtension servio) {
    final remaining = _confirmationWindowRemaining!;
    final isExpired = remaining == Duration.zero;
    final color = isExpired ? servio.textSecondary : ServioColors.warning;

    return AnimatedSwitcher(
      duration: ServioMotion.fast,
      child: Container(
        key: ValueKey<bool>(isExpired),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isExpired
              ? servio.surfaceAlt
              : ServioColors.tint(ServioColors.warning),
          borderRadius: BorderRadius.circular(ServioRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isExpired
                    ? 'Confirmation window passed — booking will auto-confirm shortly'
                    : 'Technician has ${_formatDuration(remaining)} to confirm',
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinSection(ThemeData theme, ServioThemeExtension servio) {
    final status = _data.statusCode.toLowerCase();
    final rawPin = _data.pin.trim();
    final pinDisplay = rawPin.isEmpty ? '----' : rawPin.split('').join('  ');

    // Locked before arrived
    if (status == 'pending' ||
        status == 'confirmed' ||
        status == 'accepted' ||
        status == 'scheduled' ||
        status == 'en_route' ||
        status == 'enroute') {
      return _PinCard(
        child: Column(
          children: <Widget>[
            _pinRowHeader(theme,
                icon: Icons.lock_outline_rounded,
                label: 'Arrival PIN',
                color: servio.accent),
            const SizedBox(height: 14),
            _pinBox(theme, servio, '● ● ● ●'),
            const SizedBox(height: 10),
            Text(
              'PIN will be revealed when your technician arrives.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    // Arrived — reveal toggle
    if (status == 'arrived') {
      return _PinCard(
        child: Column(
          children: <Widget>[
            _pinRowHeader(theme,
                icon: Icons.lock_open_rounded,
                label: 'Arrival PIN',
                color: ServioColors.warning),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: ServioMotion.normal,
              child: _pinRevealed
                  ? _pinBox(theme, servio, pinDisplay,
                      key: const ValueKey<String>('vis'))
                  : SizedBox(
                      key: const ValueKey<String>('btn'),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Reveal PIN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: servio.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    // In progress
    if (status == 'in_progress' || status == 'inprogress') {
      return _PinCard(
        child: Column(
          children: <Widget>[
            _pinRowHeader(theme,
                icon: Icons.verified_rounded,
                label: 'PIN Verified',
                color: ServioColors.success),
            const SizedBox(height: 14),
            _pinBox(theme, servio, pinDisplay),
            const SizedBox(height: 10),
            Text(
              'Service is in progress.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    // Completed
    if (status == 'completed' || status == 'done') {
      return _PinCard(
        child: Column(
          children: <Widget>[
            _pinRowHeader(theme,
                icon: Icons.verified_user_rounded,
                label: 'Verification Complete',
                color: ServioColors.success),
            const SizedBox(height: 10),
            Text(
              'Service was completed successfully.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _pinRowHeader(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _pinBox(
    ThemeData theme,
    ServioThemeExtension servio,
    String text, {
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: servio.surfaceAlt,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.accent),
      ),
      child: Text(
        text,
        style: theme.textTheme.displaySmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
        ),
      ),
    );
  }
}

// ── _HeroSection ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({super.key, required this.statusCode});

  final String statusCode;

  ({String title, String subtitle, IconData icon, Color color}) get _copy =>
      switch (statusCode) {
        'pending' => (
            title: 'Booking Submitted!',
            subtitle: 'Waiting for your technician to confirm.',
            icon: Icons.hourglass_empty_rounded,
            color: ServioColors.warning,
          ),
        'confirmed' || 'accepted' || 'scheduled' => (
            title: 'Booking Confirmed!',
            subtitle: 'Your technician has confirmed and will arrive soon.',
            icon: Icons.check_circle_rounded,
            color: ServioColors.success,
          ),
        'en_route' || 'enroute' => (
            title: 'Technician En Route!',
            subtitle: 'Your technician is on the way. Get ready!',
            icon: Icons.directions_car_rounded,
            color: ServioColors.info,
          ),
        'arrived' => (
            title: 'Technician Arrived!',
            subtitle: 'Share your PIN to start the service.',
            icon: Icons.location_on_rounded,
            color: ServioColors.success,
          ),
        'in_progress' || 'inprogress' => (
            title: 'Service In Progress',
            subtitle: 'Your technician is working on your service.',
            icon: Icons.build_rounded,
            color: ServioColors.info,
          ),
        'awaiting_customer_confirmation' => (
            title: 'Service Complete?',
            subtitle: 'Your technician has marked the job done.',
            icon: Icons.task_alt_rounded,
            color: ServioColors.warning,
          ),
        'pending_admin_review' => (
            title: 'Under Admin Review',
            subtitle: 'Our team is reviewing your case.',
            icon: Icons.admin_panel_settings_rounded,
            color: ServioColors.warning,
          ),
        'completed' || 'done' => (
            title: 'Service Completed!',
            subtitle: 'Thank you for choosing Servio.',
            icon: Icons.verified_rounded,
            color: ServioColors.success,
          ),
        'cancelled' || 'canceled' => (
            title: 'Booking Cancelled',
            subtitle: 'This booking has been cancelled.',
            icon: Icons.cancel_rounded,
            color: ServioColors.danger,
          ),
        'rejected' => (
            title: 'Booking Rejected',
            subtitle: 'The technician was unable to accept your booking.',
            icon: Icons.cancel_rounded,
            color: ServioColors.danger,
          ),
        'disputed' => (
            title: 'Dispute Filed',
            subtitle: 'Admin is reviewing your dispute.',
            icon: Icons.report_problem_rounded,
            color: ServioColors.warning,
          ),
        _ => (
            title: 'Booking Confirmed!',
            subtitle: 'Your technician has been notified.',
            icon: Icons.check_rounded,
            color: ServioColors.success,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final c = _copy;

    return Column(
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: ServioColors.tint(c.color),
            shape: BoxShape.circle,
            border: Border.all(color: c.color.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(c.icon, color: c.color, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          c.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          c.subtitle,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

// ── _PinCard ──────────────────────────────────────────────────────────────────

class _PinCard extends StatelessWidget {
  const _PinCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ServioCard(radius: ServioRadius.lg, child: child);
}

// ── _AwaitingConfirmationCard ─────────────────────────────────────────────────

class _AwaitingConfirmationCard extends StatelessWidget {
  const _AwaitingConfirmationCard({
    required this.onConfirm,
    required this.onDispute,
    required this.confirmLoading,
    required this.disputeLoading,
    this.error,
  });

  final VoidCallback onConfirm;
  final VoidCallback onDispute;
  final bool confirmLoading;
  final bool disputeLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final busy = confirmLoading || disputeLoading;

    return ServioCard(
      radius: ServioRadius.lg,
      backgroundColor: ServioColors.tint(ServioColors.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.task_alt_rounded,
                  color: ServioColors.warning, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Service Complete?',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your technician has marked the job as done. Please confirm or report an issue.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: ServioColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ServioColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.md),
              ),
            ),
            onPressed: busy ? null : onConfirm,
            child: confirmLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm Service Complete'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: ServioColors.danger,
              side: const BorderSide(color: ServioColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.md),
              ),
            ),
            onPressed: busy ? null : onDispute,
            child: disputeLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ServioColors.danger),
                  )
                : const Text('Report an Issue'),
          ),
        ],
      ),
    );
  }
}

// ── Status Tracker ────────────────────────────────────────────────────────────

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({
    required this.pulse,
    required this.statusCode,
    required this.statusLabel,
  });

  final Animation<double> pulse;
  final String statusCode;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    const steps = <String>[
      'Booked',
      'Confirms',
      'En Route',
      'Arrived',
      'In Progress',
      'Complete',
    ];
    final currentStep = _trackerIndex(statusCode);
    final isCompleted = statusCode.toLowerCase() == 'completed' ||
        statusCode.toLowerCase() == 'done';
    final completedUpTo =
        isCompleted ? currentStep : (currentStep > 0 ? currentStep - 1 : 0);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ServioColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: Text(
                  statusLabel,
                  key: ValueKey<String>(statusLabel),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ServioColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List<Widget>.generate(steps.length * 2 - 1, (int index) {
              if (index.isOdd) {
                final connectorIndex = index ~/ 2;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: connectorIndex < currentStep
                        ? ServioColors.success
                        : servio.border,
                  ),
                );
              }
              final stepIndex = index ~/ 2;
              final isDone = stepIndex <= completedUpTo;
              final isCurrent = !isCompleted && stepIndex == currentStep;
              return _TrackerDot(
                  done: isDone, current: isCurrent, pulse: pulse);
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(steps.length, (int i) {
              final isDone = i <= completedUpTo;
              final isCurrent = i == currentStep;
              return Expanded(
                child: Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDone || isCurrent
                        ? theme.colorScheme.onSurface
                        : servio.textSecondary,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 9,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

int _trackerIndex(String statusCode) {
  return switch (statusCode.toLowerCase()) {
    'confirmed' || 'accepted' || 'scheduled' => 1,
    'en_route' || 'enroute' => 2,
    'arrived' => 3,
    'in_progress' || 'inprogress' => 4,
    'awaiting_customer_confirmation' => 4,
    'completed' || 'done' => 5,
    _ => 0,
  };
}

class _TrackerDot extends StatelessWidget {
  const _TrackerDot({
    required this.done,
    required this.current,
    required this.pulse,
  });

  final bool done;
  final bool current;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = done
        ? ServioColors.success
        : current
            ? ServioColors.warning
            : servio.border;

    Widget dot = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done
            ? ServioColors.tint(ServioColors.success)
            : current
                ? ServioColors.tint(ServioColors.warning)
                : servio.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: done
          ? const Icon(Icons.check_rounded,
              size: 13, color: ServioColors.success)
          : current
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ServioColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
    );

    if (current) {
      dot = AnimatedBuilder(
        animation: pulse,
        builder: (BuildContext context, Widget? child) =>
            Transform.scale(scale: 1 + (pulse.value * 0.16), child: child),
        child: dot,
      );
    }

    return dot;
  }
}

// ── _ConfirmDetailRow ─────────────────────────────────────────────────────────

class _ConfirmDetailRow extends StatelessWidget {
  const _ConfirmDetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: servio.textSecondary),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

int _moneyValue(String value) {
  final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(numeric) ?? 0;
}

String _moneyLabel(int value) => '$value EGP';

String _labelForCode(String code) => switch (code.toLowerCase()) {
      'pending' => 'Pending',
      'confirmed' || 'accepted' || 'scheduled' => 'Confirmed',
      'en_route' || 'enroute' => 'En Route',
      'arrived' => 'Arrived',
      'in_progress' || 'inprogress' => 'In Progress',
      'awaiting_customer_confirmation' => 'Awaiting Confirmation',
      'pending_admin_review' => 'Under Review',
      'completed' || 'done' => 'Completed',
      'cancelled' || 'canceled' => 'Cancelled',
      'rejected' => 'Rejected',
      'disputed' => 'Disputed',
      _ => code,
    };

String _formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return m > 0 ? '${m}m ${s}s' : '${s}s';
}
