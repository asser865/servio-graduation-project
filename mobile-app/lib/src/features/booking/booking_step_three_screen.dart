import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'booking_confirmation_screen.dart';
import 'booking_flow_data.dart';

class BookingStepThreeScreen extends StatefulWidget {
  const BookingStepThreeScreen({
    required this.data,
    super.key,
  });

  final BookingFlowData data;

  @override
  State<BookingStepThreeScreen> createState() => _BookingStepThreeScreenState();
}

class _BookingStepThreeScreenState extends State<BookingStepThreeScreen> {
  bool _termsAccepted = false;
  bool _loading = false;
  String? _error;

  // ── helpers ──────────────────────────────────────────────────────────────────

  /// Navigate back to step 2 (date / payment).
  void _editPayment() {
    Navigator.of(context).pop();
  }

  void _editServiceDetails() {
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  void _showLegalNotice(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will open from the legal center.')),
    );
  }

  Future<void> _confirmBooking() async {
    if (!_termsAccepted) return;

    final data = widget.data;
    final canCreateBackendBooking = data.technicianId.isNotEmpty &&
        (data.serviceId.isNotEmpty || data.category.isNotEmpty);
    var confirmationData = data;

    if (canCreateBackendBooking) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final client = context.read<ApiClient>();
        final booking = await BookingsApi(client).createBooking(
          workerId: data.technicianId,
          serviceId: data.serviceId,
          serviceCategory: data.category,
          serviceName: data.serviceName,
          scheduledDate: data.scheduledDateTime ??
              DateTime.now().add(const Duration(days: 1)),
          scheduledTime: _backendSlotFromLabel(data.time),
          address: data.location,
          addressCity: data.addressCity.isNotEmpty ? data.addressCity : 'Cairo',
          addressStreet:
              data.addressStreet.isNotEmpty ? data.addressStreet : '',
          notes: data.notes,
        );
        confirmationData = _confirmationDataFromBackend(data, booking);
        if (!mounted) return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.message;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Booking failed. Please try again.';
        });
        return;
      }
      setState(() => _loading = false);
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingConfirmationScreen(data: confirmationData),
      ),
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

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to step 2',
        ),
        title: const Text('Review & Confirm'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── Step indicator ───────────────────────────────────────────────
              _StepIndicator(currentStep: 3),
              const SizedBox(height: 24),

              // ── Service Details review ───────────────────────────────────────
              _SectionCard(
                title: 'Service Details',
                onEdit: _editServiceDetails,
                children: <Widget>[
                  _ReviewRow(
                      label: 'Technician', value: widget.data.technicianName),
                  _ReviewRow(label: 'Service', value: widget.data.serviceName),
                  _ReviewRow(label: 'Date', value: widget.data.date),
                  _ReviewRow(label: 'Time', value: widget.data.time),
                  _ReviewRow(
                      label: 'Address',
                      value: widget.data.location,
                      isLast: true),
                ],
              ),
              const SizedBox(height: 16),

              // ── Payment review ───────────────────────────────────────────────
              _SectionCard(
                title: 'Payment',
                onEdit: _editPayment,
                children: <Widget>[
                  _ReviewRow(label: 'Method', value: widget.data.paymentMethod),
                  _ReviewRow(label: 'Base Rate', value: '$baseRate EGP'),
                  _ReviewRow(
                      label: 'Platform Fee', value: '$platformFee EGP (5%)'),
                  _ReviewRow(
                    label: 'Est. Total',
                    value: widget.data.amount,
                    valueColor: servio.accent,
                    isBold: true,
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Order Summary card ───────────────────────────────────────────
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Order Summary',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    // Technician mini-profile
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
                        // Star rating
                        Row(
                          children: <Widget>[
                            Icon(Icons.star_rounded,
                                color: servio.accent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '4.9',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              ' (128)',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: servio.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    // Pricing rows
                    _PriceLine(
                        label: 'Base rate (1 hr min)', value: '$baseRate EGP'),
                    const SizedBox(height: 8),
                    _PriceLine(
                        label: 'Platform fee (5%)', value: '$platformFee EGP'),
                    const SizedBox(height: 8),
                    _PriceLine(label: 'Parts & materials', value: 'As quoted'),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _PriceLine(
                      label: 'Estimated Total',
                      value: widget.data.amount,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                    const SizedBox(height: 20),
                    // Trust signals
                    ...<_TrustItem>[
                      const _TrustItem(
                          'Free cancellation up to 2 hours before'),
                      const _TrustItem('SERVIO Service Guarantee'),
                      const _TrustItem('Identity & licence verified'),
                      const _TrustItem('No hidden fees'),
                    ].map((_TrustItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color:
                                      ServioColors.tint(ServioColors.success),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: ServioColors.success, size: 12),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: servio.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Error banner ────────────────────────────────────────────────
              if (_error != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(ServioColors.danger),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.error_outline_rounded,
                          color: ServioColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: ServioColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Terms & Conditions consent ────────────────────────────────────
              ServioCard(
                radius: ServioRadius.md,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _termsAccepted,
                        onChanged: (bool? v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: servio.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
                          children: <InlineSpan>[
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              recognizer: TapGestureRecognizer()
                                ..onTap =
                                    () => _showLegalNotice('Terms of Service'),
                              style: TextStyle(
                                color: servio.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              recognizer: TapGestureRecognizer()
                                ..onTap =
                                    () => _showLegalNotice('Privacy Policy'),
                              style: TextStyle(
                                color: servio.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '. By confirming this booking you authorise the escrow hold.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Bottom action row ────────────────────────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: servio.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Opacity(
                      opacity: _termsAccepted ? 1.0 : 0.5,
                      child: ServioPrimaryButton(
                        label: _loading ? 'Confirming…' : 'Confirm Booking',
                        onPressed: (_termsAccepted && !_loading)
                            ? _confirmBooking
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    const labels = <String>['Details', 'Date & Time', 'Confirm'];

    return Row(
      children: List<Widget>.generate(3, (int i) {
        final step = i + 1;
        final isDone = step < currentStep;
        final isActive = step == currentStep;

        return Expanded(
          child: Row(
            children: <Widget>[
              // Circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: isActive || isDone ? ServioGradients.brand : null,
                  color: isActive || isDone ? null : servio.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isActive || isDone ? Colors.transparent : servio.border,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : Text(
                          '$step',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isActive
                                        ? Colors.white
                                        : servio.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      labels[i],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? Theme.of(context).colorScheme.onSurface
                                : servio.textSecondary,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w400,
                          ),
                    ),
                    if (i < 2)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: isDone ? ServioGradients.accent : null,
                          color: isDone ? null : servio.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.onEdit,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onEdit;

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
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    'Edit',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: servio.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
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

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _TrustItem {
  const _TrustItem(this.text);
  final String text;
}

BookingFlowData _confirmationDataFromBackend(
  BookingFlowData original,
  BackendBooking booking,
) {
  final shortId = booking.id.length >= 6
      ? booking.id.substring(booking.id.length - 6).toUpperCase()
      : booking.id.toUpperCase();
  return original.copyWith(
    reference: '#SRV-$shortId',
    amount: booking.totalAmount > 0
        ? '${booking.totalAmount.toStringAsFixed(0)} EGP'
        : original.amount,
  );
}

String _backendSlotFromLabel(String label) {
  final match = RegExp(r'(\d{1,2})(?::\d{2})?\s*(AM|PM)?', caseSensitive: false)
      .firstMatch(label);
  if (match == null) return '10:00';

  var hour = int.tryParse(match.group(1) ?? '') ?? 10;
  final meridiem = match.group(2)?.toUpperCase();
  if (meridiem == 'PM' && hour < 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;
  hour = hour.clamp(0, 23).toInt();
  return '${hour.toString().padLeft(2, '0')}:00';
}

int _moneyValue(String value) {
  final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(numeric) ?? 0;
}
