import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  late final List<DateTime> _days;
  late DateTime _selectedDate;
  final TextEditingController _addressController = TextEditingController();
  String _selectedSlot = '10:00';

  static const List<String> _slots = <String>[
    '08:00',
    '09:00',
    '10:00',
    '12:00',
    '13:00',
    '14:00',
    '16:00',
    '17:00',
  ];

  @override
  void initState() {
    super.initState();
    final firstDay = DateTime.now().add(const Duration(days: 1));
    final normalizedFirstDay =
        DateTime(firstDay.year, firstDay.month, firstDay.day);
    _days = List<DateTime>.generate(
      7,
      (index) => normalizedFirstDay.add(Duration(days: index)),
    );
    _selectedDate = _days.first;
    _addressController.text = widget.data.addressStreet;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

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
              Text(
                DateFormat('MMMM y').format(_selectedDate),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _days.map((DateTime day) {
                  final selected = _isSameDate(day, _selectedDate);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      width: 42,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: selected ? ServioGradients.brand : null,
                        color: selected
                            ? null
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                        border:
                            selected ? null : Border.all(color: servio.border),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              DateFormat('E').format(day),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : servio.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${day.day}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: selected ? Colors.white : null,
                              ),
                            ),
                          ],
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
                children: _slots.map((String slot) {
                  final selected = slot == _selectedSlot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? servio.accent
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                        border: Border.all(
                            color: selected ? servio.accent : servio.border),
                      ),
                      child: Text(
                        _slotLabel(slot),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected ? Colors.white : servio.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Service address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () {},
                    child: const Text('Use current location')),
              ),
              const SizedBox(height: 12),
              ServioPrimaryButton(
                label: 'Continue',
                onPressed: () {
                  final selectedHour =
                      int.tryParse(_selectedSlot.split(':').first) ?? 10;
                  final scheduledDateTime = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    selectedHour,
                  );
                  final address = _addressController.text.trim();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingStepThreeScreen(
                        data: widget.data.copyWith(
                          date: DateFormat('dd/MM/yyyy').format(_selectedDate),
                          time: _slotLabel(_selectedSlot),
                          scheduledDateTime: scheduledDateTime,
                          location: address.isNotEmpty
                              ? address
                              : widget.data.location,
                          addressCity: widget.data.addressCity.isNotEmpty
                              ? widget.data.addressCity
                              : 'Cairo',
                          addressStreet: address,
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

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _slotLabel(String value) {
  final hour = int.tryParse(value.split(':').first) ?? 0;
  final nextHour = (hour + 1).clamp(0, 23).toInt();
  return '${_hourLabel(hour)} - ${_hourLabel(nextHour)}';
}

String _hourLabel(int hour) {
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:00 $suffix';
}
