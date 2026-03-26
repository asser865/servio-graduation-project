import 'package:flutter/material.dart';

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
  String _paymentMethod = 'Cash on Completion';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    const methods = <String>[
      'Cash on Completion',
      'Credit / Debit Card',
      'Vodafone Cash',
      'InstaPay',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Confirm'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SummaryRow(label: 'Service', value: widget.data.serviceName),
                    _SummaryRow(label: 'Technician', value: widget.data.technicianName),
                    _SummaryRow(label: 'Date & Time', value: '${widget.data.date} • ${widget.data.time}'),
                    _SummaryRow(label: 'Location', value: widget.data.location),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Promo code',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: () {}, child: const Text('Apply')),
                ],
              ),
              const SizedBox(height: 24),
              Text('Payment Method', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ...methods.map((String method) {
                final selected = _paymentMethod == method;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentMethod = method),
                    child: ServioCard(
                      radius: ServioRadius.md,
                      borderColor: selected ? servio.accent : servio.border,
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(method, style: theme.textTheme.bodyMedium)),
                          Icon(
                            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: selected ? servio.accent : servio.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (_paymentMethod == 'Credit / Debit Card') ...<Widget>[
                const SizedBox(height: 4),
                const TextField(decoration: InputDecoration(labelText: 'Card number')),
                const SizedBox(height: 12),
                Row(
                  children: const <Widget>[
                    Expanded(child: TextField(decoration: InputDecoration(labelText: 'Expiry'))),
                    SizedBox(width: 12),
                    Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV'))),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ServioCard(
                child: Column(
                  children: <Widget>[
                    _PriceRow(label: 'Service fee', value: '900 EGP'),
                    _PriceRow(label: 'Platform fee', value: '150 EGP'),
                    _PriceRow(label: 'Promo discount', value: '-0 EGP', valueColor: servio.success),
                    const Divider(height: 24),
                    _PriceRow(
                      label: 'Total',
                      value: widget.data.amount,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ServioColors.tint(servio.info),
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                ),
                child: Text(
                  'Your payment is held securely in escrow until service completion is confirmed.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: servio.info),
                ),
              ),
              const SizedBox(height: 20),
              ServioPrimaryButton(
                label: 'Confirm Booking',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingConfirmationScreen(
                        data: widget.data.copyWith(paymentMethod: _paymentMethod),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
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
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
