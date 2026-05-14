import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  late final AnimationController _checkController;
  late final AnimationController _pulseController;
  late final Animation<double> _checkScale;

  // Server-generated 4-digit arrival PIN returned by booking creation.
  late final String _pin;

  bool _refCopied = false;

  @override
  void initState() {
    super.initState();

    _pin = widget.data.pin.trim().isNotEmpty ? widget.data.pin.trim() : '----';

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: ServioMotion.spring,
    );
    _checkController.forward();

    // Refresh provider after first frame so home screen shows real backend data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<BookingsProvider>().refresh();
      } catch (_) {
        // Standalone preview/tests may mount this screen without app providers.
      }
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  Future<void> _copyReference() async {
    await Clipboard.setData(ClipboardData(text: widget.data.reference));
    setState(() => _refCopied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _refCopied = false);
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
                  context.read<BookingsProvider>().updateStatus(
                      widget.data.backendId, BookingStatus.cancelled);
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

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final total = _moneyValue(widget.data.amount);
    final platformFee = (total * 0.05).round();
    final baseRate = total - platformFee;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 12),

              // ── Animated success icon ────────────────────────────────────────
              Center(
                child: ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: ServioColors.tint(ServioColors.success),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: ServioColors.success.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: ServioColors.success,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Booking Confirmed!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Your technician has been notified and will confirm shortly.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 16),

              // ── Booking reference chip ────────────────────────────────────────
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
                          widget.data.reference,
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
                                  key: ValueKey('ok'))
                              : Icon(Icons.copy_rounded,
                                  size: 16,
                                  color: servio.accent,
                                  key: const ValueKey('copy')),
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
              const SizedBox(height: 24),

              // ── 6-step status tracker ────────────────────────────────────────
              _StatusTracker(
                pulse: _pulseController,
                statusCode: widget.data.statusCode,
                statusLabel: widget.data.statusLabel,
              ),
              const SizedBox(height: 20),

              // ── Arrival PIN card ─────────────────────────────────────────────
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.lock_outline_rounded,
                            color: servio.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Arrival PIN',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        color: servio.surfaceAlt,
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                        border: Border.all(color: servio.accent),
                      ),
                      child: Text(
                        _pin == '----' ? _pin : _pin.split('').join('  '),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Share this PIN with your technician upon arrival to confirm the service has started.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Payment Summary card ─────────────────────────────────────────
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
                      label: 'Method',
                      value: widget.data.paymentMethod,
                    ),
                    if (widget.data.paymentMethodCode == 'card' &&
                        widget.data.savedCardLabel.isNotEmpty)
                      _ConfirmDetailRow(
                        label: 'Card',
                        value: widget.data.savedCardLabel,
                      ),
                    _ConfirmDetailRow(
                        label: 'Base Rate', value: '$baseRate EGP'),
                    _ConfirmDetailRow(
                        label: 'Platform Fee', value: '$platformFee EGP'),
                    const Divider(height: 20),
                    _ConfirmDetailRow(
                      label: 'Total',
                      value: widget.data.amount,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Confirmation Details card ─────────────────────────────────────
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

                    // Technician section
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
                              widget.data.technicianName
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
                                widget.data.technicianName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                widget.data.specialty,
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

                    // Service details
                    _ConfirmDetailRow(
                      label: 'Service',
                      value: widget.data.serviceName,
                      icon: Icons.build_outlined,
                    ),
                    _ConfirmDetailRow(
                      label: 'Date',
                      value: widget.data.date,
                      icon: Icons.calendar_today_outlined,
                    ),
                    _ConfirmDetailRow(
                      label: 'Time Slot',
                      value: widget.data.time,
                      icon: Icons.access_time_rounded,
                    ),
                    _ConfirmDetailRow(
                      label: 'Address',
                      value: widget.data.location,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _ConfirmDetailRow(
                      label: 'Method',
                      value: widget.data.paymentMethod,
                      icon: Icons.payments_outlined,
                    ),
                    if (widget.data.paymentMethodCode == 'card' &&
                        widget.data.savedCardLabel.isNotEmpty)
                      _ConfirmDetailRow(
                        label: 'Card',
                        value: widget.data.savedCardLabel,
                        icon: Icons.credit_card_rounded,
                      ),
                    _ConfirmDetailRow(
                      label: 'Base Rate',
                      value: '$baseRate EGP',
                    ),
                    _ConfirmDetailRow(
                      label: 'Platform Fee',
                      value: '$platformFee EGP',
                    ),
                    _ConfirmDetailRow(
                      label: 'Est. Total',
                      value: widget.data.amount,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Action stack ─────────────────────────────────────────────────
              ServioPrimaryButton(
                label: 'View Booking Details',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(data: widget.data),
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
                      contactName: widget.data.technicianName,
                      bookingId: widget.data.backendId,
                      workerId: widget.data.technicianId,
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
                    builder: (_) => const CustomerShell(),
                  ),
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
                    builder: (_) => const CustomerShell(),
                  ),
                  (route) => false,
                ),
                child: Text(
                  'Back to Home',
                  style: TextStyle(color: servio.textSecondary),
                ),
              ),
              // Cancel is only available for pending bookings.
              // Backend rejects cancellation of any other status.
              if (widget.data.statusCode == 'pending')
                TextButton(
                  onPressed: _showCancelSheet,
                  child: const Text(
                    'Cancel Booking',
                    style: TextStyle(color: ServioColors.danger),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: servio.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cancellation unavailable — booking is ${widget.data.statusLabel.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: servio.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ── Help card ────────────────────────────────────────────────────
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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
}

// ── Status Tracker ─────────────────────────────────────────────────────────────

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
                done: isDone,
                current: isCurrent,
                pulse: pulse,
              );
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
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(
            scale: 1 + (pulse.value * 0.16),
            child: child,
          );
        },
        child: dot,
      );
    }

    return dot;
  }
}

// ── _ConfirmDetailRow ──────────────────────────────────────────────────────────

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

int _moneyValue(String value) {
  final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(numeric) ?? 0;
}
