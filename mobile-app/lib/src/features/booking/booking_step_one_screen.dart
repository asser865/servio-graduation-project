import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'booking_flow_data.dart';
import 'booking_step_two_screen.dart';

class BookingStepOneScreen extends StatelessWidget {
  const BookingStepOneScreen({
    super.key,
    this.data = const BookingFlowData(),
  });

  final BookingFlowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Your Booking'),
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
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: ServioGradients.brand,
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                      child: Icon(
                        Icons.plumbing_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: servio.backgroundSoft,
                              borderRadius: BorderRadius.circular(ServioRadius.sm),
                            ),
                            child: Text(
                              data.category,
                              style: theme.textTheme.labelSmall?.copyWith(color: servio.accent),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(data.serviceName, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            data.priceLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(color: servio.accent),
                          ),
                          const SizedBox(height: 8),
                          const ServioStatusChip(label: 'AI Estimate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ServioCard(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: ServioGradients.warm,
                        shape: BoxShape.circle,
                        border: Border.all(color: servio.accent, width: 2),
                      ),
                      child: const Center(child: Text('AN')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(data.technicianName, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            data.specialty,
                            style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '4.9 rating • ${data.hourlyRate}',
                            style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Change')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Describe your job (optional)',
                style: theme.textTheme.labelLarge?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 10),
              const TextField(
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'e.g., Repaint living room walls, 3 coats...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingStepTwoScreen(data: data),
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
