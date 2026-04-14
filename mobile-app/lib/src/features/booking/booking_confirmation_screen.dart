import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_home_screen.dart';
import '../customer/my_bookings_screen.dart';
import '../messages/chat_screen.dart';
import 'booking_flow_data.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({
    required this.data,
    super.key,
  });

  final BookingFlowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(ServioColors.success),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: ServioColors.success,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Booking Confirmed!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                data.reference,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(color: servio.accent),
              ),
              const SizedBox(height: 24),
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _DetailLine(label: 'Service', value: data.serviceName),
                    _DetailLine(label: 'Technician', value: data.technicianName),
                    _DetailLine(label: 'Date & Time', value: '${data.date} - ${data.time}'),
                    _DetailLine(label: 'Location', value: data.location),
                    _DetailLine(label: 'Amount', value: data.amount),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: 'View Booking Details',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingDetailsScreen(data: data),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(contactName: data.technicianName),
                    ),
                  );
                },
                child: const Text('Message Technician'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyBookingsScreen(initialTabIndex: 0),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text('Track Status'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text(
                  'Back to Home',
                  style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
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
        ],
      ),
    );
  }
}
