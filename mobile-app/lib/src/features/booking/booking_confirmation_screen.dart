import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/payments_api.dart';
import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/disputes_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
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

// Stitch design tokens
const _kNavy = ServioColors.backgroundDark;        // #1A1D23
const _kSurfaceWarm = ServioColors.backgroundSoftLight; // #F3EDE7
const _kTaupe = ServioColors.accent;               // #9A8C73
const _kTextMuted = Color(0xFF6B6560);
const _kOutlineVariant = Color(0xFFC6C6CB);
const _kSurfaceContainer = Color(0xFFEFEEEB);
const _kPrimaryFixedDim = Color(0xFFC4C6CE);

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
      final backend =
          await BookingsApi(_apiClient).getBooking(_data.backendId);
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
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => tick());
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
      await PaymentsApi(_apiClient).confirmEscrow(_data.backendId);
      if (!mounted) return;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _data = _data.copyWith(
          statusCode: 'pending_admin_review',
          statusLabel: 'Under Review',
        );
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
    final disputes = context.read<DisputesProvider>();
    final reason = await _showDisputeDialog();
    if (reason == null) return;
    setState(() {
      _disputeLoading = true;
      _actionError = null;
    });
    try {
      String paymentId = _data.paymentId;
      if (paymentId.isEmpty) {
        try {
          final pd = await PaymentsApi(_apiClient)
              .getPaymentByBooking(_data.backendId);
          paymentId = pd['_id'] as String? ?? '';
        } catch (_) {}
      }
      await disputes.openDispute(
        bookingId: _data.backendId,
        paymentId: paymentId,
        reason: reason,
        category: 'other',
      );
      if (!mounted) return;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _data =
            _data.copyWith(statusCode: 'disputed', statusLabel: 'Disputed');
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
      builder: (ctx) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Builder(
          builder: (innerCtx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(innerCtx).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Report an Issue',
                    style: Theme.of(innerCtx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
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
    final platformFee = (baseRate * 0.10).round();
    final estimatedTotal = baseRate + platformFee;
    final estimatedTotalLabel = _moneyLabel(estimatedTotal);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: ServioSpacing.screenPadding, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── Hero ──────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: ServioMotion.normal,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0)
                        .animate(animation),
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
                      color: _kSurfaceWarm,
                      borderRadius:
                          BorderRadius.circular(ServioRadius.full),
                      border: Border.all(
                          color: _kTaupe.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _data.reference,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _kNavy,
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
                                  color: _kTaupe,
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

              // ── Pending countdown ─────────────────────────────────────────
              if (statusCode == 'pending' &&
                  _confirmationWindowRemaining != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildConfirmationWindow(theme, servio),
              ],

              const SizedBox(height: 20),

              // ── PIN card ──────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: KeyedSubtree(
                  key: ValueKey<String>(statusCode),
                  child: _buildPinSection(theme),
                ),
              ),

              const SizedBox(height: 16),

              // ── Vertical status tracker ───────────────────────────────────
              _StitchVerticalTracker(statusCode: statusCode),

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
                _StitchInfoBanner(
                  icon: Icons.admin_panel_settings_rounded,
                  color: ServioColors.info,
                  title: 'Under Admin Review',
                  body:
                      'Our team is reviewing this case. You will be notified once a decision is made.',
                ),
              ],

              const SizedBox(height: 16),

              // ── Confirmation Details ──────────────────────────────────────
              _ConfirmationDetailsCard(data: _data),

              const SizedBox(height: 16),

              // ── Payment Summary ───────────────────────────────────────────
              _PaymentSummaryCard(
                paymentMethod: _data.paymentMethod,
                paymentMethodCode: _data.paymentMethodCode,
                savedCardLabel: _data.savedCardLabel,
                baseRate: baseRate,
                platformFee: platformFee,
                estimatedTotalLabel: estimatedTotalLabel,
              ),

              const SizedBox(height: 24),

              // ── Primary: View Booking Details ─────────────────────────────
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingDetailsScreen(data: _data),
                    ),
                  ),
                  child: const Text('View Booking Details'),
                ),
              ),
              const SizedBox(height: 12),

              // ── Secondary: Message + Go Home row ─────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kNavy,
                        backgroundColor: _kSurfaceWarm,
                        side: BorderSide(
                            color: _kTaupe.withValues(alpha: 0.5),
                            width: 2),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md),
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kNavy,
                        side: BorderSide(
                            color: _kTaupe.withValues(alpha: 0.5),
                            width: 2),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                            builder: (_) => const CustomerShell()),
                        (route) => false,
                      ),
                      child: const Text('Go to Dashboard'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Tertiary links ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const MyBookingsScreen(initialTabIndex: 1),
                      ),
                      (route) => false,
                    ),
                    child: Text(
                      'View Booking History',
                      style:
                          TextStyle(color: servio.textSecondary),
                    ),
                  ),
                  Text('·',
                      style:
                          TextStyle(color: servio.textSecondary)),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                          builder: (_) => const CustomerShell()),
                      (route) => false,
                    ),
                    child: Text(
                      'Back to Home',
                      style:
                          TextStyle(color: servio.textSecondary),
                    ),
                  ),
                ],
              ),

              // ── Cancel / lock ─────────────────────────────────────────────
              if (statusCode == 'pending')
                Center(
                  child: TextButton(
                    onPressed: _showCancelSheet,
                    child: const Text(
                      'Cancel Booking',
                      style: TextStyle(color: ServioColors.danger),
                    ),
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
                      Flexible(
                        child: Text(
                          'Cancellation unavailable — booking is ${_data.statusLabel.toLowerCase()}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Help card ─────────────────────────────────────────────────
              _StitchInfoBanner(
                icon: Icons.support_agent_rounded,
                color: ServioColors.info,
                title: 'Need help?',
                body:
                    'Our support team is available 24/7 to assist you with your booking.',
                footnote: 'support@servio.app',
              ),
              const SizedBox(height: 24),
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

  Widget _buildPinSection(ThemeData theme) {
    final status = _data.statusCode.toLowerCase();
    final rawPin = _data.pin.trim();
    final pinDisplay =
        rawPin.isEmpty ? '----' : rawPin.split('').join('  ');

    if (status == 'pending' ||
        status == 'confirmed' ||
        status == 'accepted' ||
        status == 'scheduled' ||
        status == 'en_route' ||
        status == 'enroute') {
      return const _StitchPinCard(
        label: 'ARRIVAL PIN',
        pinText: '●  ●  ●  ●',
        subtitle: 'PIN will be revealed when your technician arrives.',
      );
    }

    if (status == 'arrived') {
      return _StitchPinCard(
        label: 'ARRIVAL PIN',
        pinText: _pinRevealed ? pinDisplay : null,
        subtitle: _pinRevealed
            ? 'Share this PIN with your technician to start the service.'
            : null,
        onReveal:
            _pinRevealed ? null : () => setState(() => _pinRevealed = true),
      );
    }

    if (status == 'in_progress' || status == 'inprogress') {
      return _StitchPinCard(
        label: 'PIN VERIFIED',
        pinText: pinDisplay,
        subtitle: 'Service is in progress.',
      );
    }

    if (status == 'completed' || status == 'done') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kNavy,
          borderRadius: BorderRadius.circular(ServioRadius.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.verified_user_rounded, color: _kTaupe, size: 22),
            const SizedBox(width: 10),
            Text(
              'Verification Complete',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── _HeroSection ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({super.key, required this.statusCode});

  final String statusCode;

  ({
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    Color bgColor,
  }) get _copy => switch (statusCode) {
        'pending' => (
            title: 'Booking Submitted!',
            subtitle: 'Waiting for your technician to confirm.',
            icon: Icons.hourglass_empty_rounded,
            iconColor: ServioColors.warning,
            bgColor: ServioColors.tint(ServioColors.warning),
          ),
        'confirmed' || 'accepted' || 'scheduled' => (
            title: 'Booking Confirmed!',
            subtitle: 'Your artisan is scheduled and ready.',
            icon: Icons.check_circle_rounded,
            iconColor: _kNavy,
            bgColor: _kSurfaceWarm,
          ),
        'en_route' || 'enroute' => (
            title: 'Technician En Route!',
            subtitle: 'Your technician is on the way. Get ready!',
            icon: Icons.directions_car_rounded,
            iconColor: ServioColors.info,
            bgColor: ServioColors.tint(ServioColors.info),
          ),
        'arrived' => (
            title: 'Technician Arrived!',
            subtitle: 'Share your PIN to start the service.',
            icon: Icons.location_on_rounded,
            iconColor: _kNavy,
            bgColor: _kSurfaceWarm,
          ),
        'in_progress' || 'inprogress' => (
            title: 'Service In Progress',
            subtitle: 'Your technician is working on your service.',
            icon: Icons.build_rounded,
            iconColor: ServioColors.info,
            bgColor: ServioColors.tint(ServioColors.info),
          ),
        'awaiting_customer_confirmation' => (
            title: 'Service Complete?',
            subtitle: 'Your technician has marked the job done.',
            icon: Icons.task_alt_rounded,
            iconColor: ServioColors.warning,
            bgColor: ServioColors.tint(ServioColors.warning),
          ),
        'pending_admin_review' => (
            title: 'Under Admin Review',
            subtitle: 'Our team is reviewing your case.',
            icon: Icons.admin_panel_settings_rounded,
            iconColor: ServioColors.warning,
            bgColor: ServioColors.tint(ServioColors.warning),
          ),
        'completed' || 'done' => (
            title: 'Service Completed!',
            subtitle: 'Thank you for choosing Servio.',
            icon: Icons.verified_rounded,
            iconColor: _kNavy,
            bgColor: _kSurfaceWarm,
          ),
        'cancelled' || 'canceled' => (
            title: 'Booking Cancelled',
            subtitle: 'This booking has been cancelled.',
            icon: Icons.cancel_rounded,
            iconColor: ServioColors.danger,
            bgColor: ServioColors.tint(ServioColors.danger),
          ),
        'rejected' => (
            title: 'Booking Rejected',
            subtitle:
                'The technician was unable to accept your booking.',
            icon: Icons.cancel_rounded,
            iconColor: ServioColors.danger,
            bgColor: ServioColors.tint(ServioColors.danger),
          ),
        'disputed' => (
            title: 'Dispute Filed',
            subtitle: 'Admin is reviewing your dispute.',
            icon: Icons.report_problem_rounded,
            iconColor: ServioColors.warning,
            bgColor: ServioColors.tint(ServioColors.warning),
          ),
        _ => (
            title: 'Booking Confirmed!',
            subtitle: 'Your artisan has been notified.',
            icon: Icons.check_circle_rounded,
            iconColor: _kNavy,
            bgColor: _kSurfaceWarm,
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
            color: c.bgColor,
            shape: BoxShape.circle,
            border: Border.all(
                color: c.iconColor.withValues(alpha: 0.2), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _kNavy.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(c.icon, color: c.iconColor, size: 48),
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
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

// ── _StitchPinCard ────────────────────────────────────────────────────────────

class _StitchPinCard extends StatelessWidget {
  const _StitchPinCard({
    required this.label,
    this.pinText,
    this.subtitle,
    this.onReveal,
  });

  final String label;
  final String? pinText;
  final String? subtitle;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(painter: _DotPatternPainter()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 28),
              child: Column(
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _kTaupe,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (onReveal != null) ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_open_rounded,
                            size: 18),
                        label: const Text('Reveal PIN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTaupe,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ServioRadius.md),
                          ),
                        ),
                        onPressed: onReveal,
                      ),
                    ),
                  ] else ...<Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        pinText ?? '●  ●  ●  ●',
                        maxLines: 1,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 10,
                        ),
                      ),
                    ),
                  ],
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: _kPrimaryFixedDim),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) => false;
}

// ── _StitchVerticalTracker ────────────────────────────────────────────────────

class _StitchVerticalTracker extends StatelessWidget {
  const _StitchVerticalTracker({required this.statusCode});

  final String statusCode;

  int get _currentStep => switch (statusCode) {
        'pending' => 0,
        'confirmed' ||
        'accepted' ||
        'scheduled' ||
        'en_route' ||
        'enroute' ||
        'arrived' ||
        'in_progress' ||
        'inprogress' ||
        'awaiting_customer_confirmation' =>
          1,
        'completed' || 'done' => 2,
        _ => 0,
      };

  bool get _isCancelled =>
      statusCode == 'cancelled' ||
      statusCode == 'canceled' ||
      statusCode == 'rejected' ||
      statusCode == 'disputed';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const steps = <({String title, String subtitle})>[
      (
        title: 'Awaiting Confirmation',
        subtitle: 'Artisan has received your request.',
      ),
      (
        title: 'Job In Progress',
        subtitle: 'Artisan is en route or working.',
      ),
      (
        title: 'Completed',
        subtitle: 'Service finished successfully.',
      ),
    ];

    final current = _currentStep;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurfaceWarm.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Status',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _kNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ...List<Widget>.generate(steps.length, (i) {
            final isDone = _isCancelled ? false : i < current;
            final isCurrent = _isCancelled ? false : i == current;
            return _StitchTrackerStep(
              title: steps[i].title,
              subtitle: steps[i].subtitle,
              isDone: isDone,
              isCurrent: isCurrent,
              isLast: i == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _StitchTrackerStep extends StatelessWidget {
  const _StitchTrackerStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final String title;
  final String subtitle;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor =
        isDone || isCurrent ? _kNavy : _kTextMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                _StepDot(isDone: isDone, isCurrent: isCurrent),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: _kTaupe.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: _kTextMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.isDone, required this.isCurrent});

  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _kNavy,
          shape: BoxShape.circle,
          border: Border.all(color: _kSurfaceWarm, width: 2),
        ),
        child: const Icon(Icons.check_rounded,
            color: Colors.white, size: 13),
      );
    }
    if (isCurrent) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _kSurfaceWarm,
          shape: BoxShape.circle,
          border: Border.all(color: _kTaupe, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _kTaupe,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _kSurfaceContainer,
        shape: BoxShape.circle,
        border: Border.all(color: _kOutlineVariant, width: 2),
      ),
    );
  }
}

// ── _ConfirmationDetailsCard ──────────────────────────────────────────────────

class _ConfirmationDetailsCard extends StatelessWidget {
  const _ConfirmationDetailsCard({required this.data});

  final BookingFlowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final initials = data.technicianName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F6),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Confirmation Details',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _kNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Technician row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kSurfaceWarm,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kTaupe, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      initials,
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
                        data.technicianName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        data.specialty,
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
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: _kTaupe.withValues(alpha: 0.1)),
          _DetailRow(
              label: 'Service',
              value: data.serviceName,
              icon: Icons.build_outlined),
          _DetailRow(
              label: 'Date',
              value: data.date,
              icon: Icons.calendar_today_outlined),
          _DetailRow(
              label: 'Time Slot',
              value: data.time,
              icon: Icons.access_time_rounded),
          _DetailRow(
              label: 'Address',
              value: data.location,
              icon: Icons.location_on_outlined),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _kTaupe.withValues(alpha: 0.06)),
        ),
      ),
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
                color: _kNavy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PaymentSummaryCard ───────────────────────────────────────────────────────

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.paymentMethod,
    required this.paymentMethodCode,
    required this.savedCardLabel,
    required this.baseRate,
    required this.platformFee,
    required this.estimatedTotalLabel,
  });

  final String paymentMethod;
  final String paymentMethodCode;
  final String savedCardLabel;
  final int baseRate;
  final int platformFee;
  final String estimatedTotalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F6),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Payment Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _kNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Divider(height: 1, color: _kTaupe.withValues(alpha: 0.1)),
          _DetailRow(label: 'Method', value: paymentMethod),
          if (paymentMethodCode == 'card' && savedCardLabel.isNotEmpty)
            _DetailRow(label: 'Card', value: savedCardLabel),
          _DetailRow(label: 'Base Rate', value: '$baseRate EGP'),
          _DetailRow(label: 'Platform Fee', value: '$platformFee EGP'),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Total Paid',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: servio.textSecondary),
                ),
                Text(
                  estimatedTotalLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _kNavy,
                    fontWeight: FontWeight.w700,
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

// ── _StitchInfoBanner ─────────────────────────────────────────────────────────

class _StitchInfoBanner extends StatelessWidget {
  const _StitchInfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.footnote,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      backgroundColor: ServioColors.tint(color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
                if (footnote != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    footnote!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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
