import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'booking_flow_data.dart';
import 'booking_step_two_screen.dart';

class BookingStepOneScreen extends StatefulWidget {
  const BookingStepOneScreen({
    super.key,
    this.data = const BookingFlowData(),
  });

  final BookingFlowData data;

  @override
  State<BookingStepOneScreen> createState() => _BookingStepOneScreenState();
}

class _BookingStepOneScreenState extends State<BookingStepOneScreen> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.data.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: servio.backgroundSoft,
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.sm),
                            ),
                            child: Text(
                              widget.data.category,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: servio.accent),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(widget.data.serviceName,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            widget.data.priceLabel,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.accent),
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
                      child: Center(
                        child: Text(
                          widget.data.technicianName.isNotEmpty
                              ? widget.data.technicianName.trim()[0].toUpperCase()
                              : '?',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(widget.data.technicianName,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            widget.data.specialty,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.data.hourlyRate,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Change')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Describe your job (optional)',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
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
                      builder: (_) => BookingStepTwoScreen(
                        data: widget.data.copyWith(
                          notes: _notesController.text.trim(),
                        ),
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
