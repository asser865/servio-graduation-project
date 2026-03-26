import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'booking_flow_data.dart';
import 'booking_step_three_screen.dart';

class BookingStepTwoScreen extends StatefulWidget {
  const BookingStepTwoScreen({
    required this.data,
    super.key,
  });

  final BookingFlowData data;

  @override
  State<BookingStepTwoScreen> createState() => _BookingStepTwoScreenState();
}

class _BookingStepTwoScreenState extends State<BookingStepTwoScreen> {
  int _selectedDay = 26;
  String _selectedSlot = '10AM-11AM';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    const days = <int>[24, 25, 26, 27, 28, 29, 30];
    const slots = <String>[
      '8AM-9AM',
      '9AM-10AM',
      '10AM-11AM',
      '12PM-1PM',
      '1PM-2PM',
      '2PM-3PM',
      '4PM-5PM',
      '5PM-6PM',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Date & Time'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('March 2026', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: days.map((int day) {
                  final selected = day == _selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      width: 42,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: selected ? ServioGradients.brand : null,
                        color: selected ? null : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                        border: selected ? null : Border.all(color: servio.border),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Time Slots', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: slots.map((String slot) {
                  final selected = slot == _selectedSlot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? servio.accent : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                        border: Border.all(color: selected ? servio.accent : servio.border),
                      ),
                      child: Text(
                        slot,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected ? Colors.white : servio.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Service address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: const Text('Use current location')),
              ),
              const SizedBox(height: 12),
              ServioPrimaryButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingStepThreeScreen(
                        data: widget.data.copyWith(
                          date: '$_selectedDay/03/2026',
                          time: _selectedSlot.replaceAll('-', ' - '),
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
