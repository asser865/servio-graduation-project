import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/customer_address.dart';
import '../../core/models/user_account.dart';
import '../../core/services/location_service.dart';
import '../../core/state/customer_addresses_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../shared/widgets/servio_map_widget.dart';
import '../customer/create_address_screen.dart';
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
  String _selectedSlot = '';
  String? _selectedAddressId;
  String? _addressError;
  LatLng? _addressLatLng;
  bool _geocoding = false;

  static const List<String> _fallbackSlots = <String>[
    '08:00',
    '09:00',
    '10:00',
    '12:00',
    '13:00',
    '14:00',
    '16:00',
    '17:00',
  ];

  static const String _unavailableMessage =
      'Technician is not available on this day';

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
    _selectedDate = _firstAvailableDate() ?? _days.first;
    _selectedSlot = _firstSlotFor(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CustomerAddressesProvider>().load();
    });
  }

  DateTime? _firstAvailableDate() {
    for (final day in _days) {
      if (_isAvailableDate(day)) return day;
    }
    return null;
  }

  bool _isAvailableDate(DateTime day) {
    if (!widget.data.requiresTechnicianAvailabilityCheck) return true;
    return widget.data.technicianAvailabilityFor(day) != null;
  }

  List<String> _slotsForDate(DateTime day) {
    final slot = widget.data.technicianAvailabilityFor(day);
    if (slot == null) {
      return widget.data.requiresTechnicianAvailabilityCheck
          ? const <String>[]
          : _fallbackSlots;
    }
    return _slotsFromAvailability(slot);
  }

  String _firstSlotFor(DateTime day) {
    final slots = _slotsForDate(day);
    return slots.isEmpty ? '' : slots.first;
  }

  void _selectDate(DateTime day) {
    if (!_isAvailableDate(day)) return;
    setState(() {
      _selectedDate = day;
      _selectedSlot = _firstSlotFor(day);
    });
  }

  void _continue() {
    if (!_isAvailableDate(_selectedDate) || _selectedSlot.isEmpty) return;
    final address = _selectedAddress(
      context.read<CustomerAddressesProvider>().addresses,
    );
    if (address == null) {
      setState(() => _addressError = 'Select a saved address to continue.');
      return;
    }

    final selectedHour = int.tryParse(_selectedSlot.split(':').first) ?? 10;
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      selectedHour,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingStepThreeScreen(
          data: widget.data.copyWith(
            date: DateFormat('dd/MM/yyyy').format(_selectedDate),
            time: _slotLabel(_selectedSlot),
            scheduledDateTime: scheduledDateTime,
            location: address.formattedSingleLine,
            addressCity: address.city.isNotEmpty
                ? address.city
                : widget.data.addressCity,
            addressStreet: address.street,
          ),
        ),
      ),
    );
  }

  Future<void> _addAddress() async {
    final saved = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute<CustomerAddress>(
        builder: (_) => const CreateAddressScreen(),
      ),
    );
    if (!mounted || saved == null) return;
    setState(() {
      _selectedAddressId = saved.id;
      _addressError = null;
    });
    await _onAddressSelected(saved);
  }

  Future<void> _onAddressSelected(CustomerAddress address) async {
    if (address.lat != null && address.lng != null) {
      setState(() => _addressLatLng = LatLng(address.lat!, address.lng!));
      return;
    }
    setState(() {
      _addressLatLng = null;
      _geocoding = true;
    });
    final latLng = await LocationService()
        .geocodeAddress('${address.street}, ${address.city}');
    if (mounted) {
      setState(() {
        _addressLatLng = latLng;
        _geocoding = false;
      });
    }
  }

  CustomerAddress? _selectedAddress(List<CustomerAddress> addresses) {
    if (addresses.isEmpty) return null;
    if (_selectedAddressId != null) {
      for (final address in addresses) {
        if (address.id == _selectedAddressId) return address;
      }
    }
    if (widget.data.addressStreet.isNotEmpty) {
      for (final address in addresses) {
        if (address.street == widget.data.addressStreet) return address;
      }
    }
    return addresses.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final selectedDateAvailable = _isAvailableDate(_selectedDate);
    final slots =
        selectedDateAvailable ? _slotsForDate(_selectedDate) : const <String>[];
    final addressProvider = context.watch<CustomerAddressesProvider>();
    final selectedAddress = _selectedAddress(addressProvider.addresses);
    final canContinue = selectedDateAvailable &&
        _selectedSlot.isNotEmpty &&
        selectedAddress != null &&
        !addressProvider.loading;

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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _days.map((DateTime day) {
                    final available = _isAvailableDate(day);
                    final selected =
                        available && _isSameDate(day, _selectedDate);
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Semantics(
                        button: true,
                        enabled: available,
                        selected: selected,
                        label:
                            '${DateFormat('EEE, MMM d').format(day)}${available ? '' : ' unavailable'}',
                        child: GestureDetector(
                          onTap: available ? () => _selectDate(day) : null,
                          child: Container(
                            key: ValueKey<String>(
                              'booking-date-${_dateKey(day)}-'
                              '${available ? 'available' : 'unavailable'}',
                            ),
                            width: 46,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: selected ? ServioGradients.brand : null,
                              color: selected
                                  ? null
                                  : available
                                      ? Theme.of(context).colorScheme.surface
                                      : servio.backgroundSoft,
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.full),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: available
                                          ? servio.border
                                          : servio.border
                                              .withValues(alpha: 0.45),
                                    ),
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
                                          : available
                                              ? servio.textSecondary
                                              : servio.textSecondary
                                                  .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${day.day}',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : available
                                              ? theme.colorScheme.onSurface
                                              : servio.textSecondary
                                                  .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    available ? '' : 'Off',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: servio.textSecondary
                                          .withValues(alpha: 0.5),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Text('Time Slots', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (!selectedDateAvailable || slots.isEmpty)
                _AvailabilityNotice(message: _unavailableMessage)
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: slots.map((String slot) {
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
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                          border: Border.all(
                            color: selected ? servio.accent : servio.border,
                          ),
                        ),
                        child: Text(
                          _slotLabel(slot),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color:
                                selected ? Colors.white : servio.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              Text('Service Address', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _AddressSelector(
                addresses: addressProvider.addresses,
                selectedAddress: selectedAddress,
                loading: addressProvider.loading,
                error: addressProvider.error,
                addressError: _addressError,
                onRetry: () => context.read<CustomerAddressesProvider>().load(),
                onAdd: _addAddress,
                onSelect: (address) {
                  setState(() {
                    _selectedAddressId = address.id;
                    _addressError = null;
                  });
                  _onAddressSelected(address);
                },
              ),
              if (_geocoding)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_addressLatLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ServioMapWidget(
                        center: _addressLatLng!,
                        zoom: 15,
                        interactive: false,
                        markers: [buildPinMarker(_addressLatLng!)],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ServioPrimaryButton(
                label: 'Continue',
                onPressed: canContinue ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressSelector extends StatelessWidget {
  const _AddressSelector({
    required this.addresses,
    required this.selectedAddress,
    required this.loading,
    required this.onRetry,
    required this.onAdd,
    required this.onSelect,
    this.error,
    this.addressError,
  });

  final List<CustomerAddress> addresses;
  final CustomerAddress? selectedAddress;
  final bool loading;
  final String? error;
  final String? addressError;
  final VoidCallback onRetry;
  final VoidCallback onAdd;
  final ValueChanged<CustomerAddress> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    if (loading && addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _boxDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _boxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: servio.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add New Address'),
            ),
          ],
        ),
      );
    }

    if (addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _boxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'No saved addresses yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add an address to continue with this booking.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: servio.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey<String>('booking-add-address-button'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add New Address'),
            ),
            if (addressError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                addressError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: servio.danger),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final address in addresses) ...<Widget>[
          _SelectableAddressCard(
            address: address,
            selected: selectedAddress?.id == address.id,
            onTap: () => onSelect(address),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          key: const ValueKey<String>('booking-add-address-button'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add New Address'),
        ),
        if (addressError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            addressError!,
            style: TextStyle(color: servio.danger),
          ),
        ],
      ],
    );
  }

  BoxDecoration _boxDecoration(BuildContext context) {
    final servio = context.servio;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(ServioRadius.md),
      border: Border.all(color: servio.border),
    );
  }
}

class _SelectableAddressCard extends StatelessWidget {
  const _SelectableAddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final CustomerAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return InkWell(
      key: ValueKey<String>('booking-address-${address.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(ServioRadius.md),
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? ServioColors.tint(servio.accent)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(
            color: selected ? servio.accent : servio.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? servio.accent : servio.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    address.displayLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.formattedSingleLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: servio.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityNotice extends StatelessWidget {
  const _AvailabilityNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.warning),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.event_busy_rounded, color: servio.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: servio.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _slotLabel(String value) {
  final hour = int.tryParse(value.split(':').first) ?? 0;
  final nextHour = hour + 1;
  return '${_hourLabel(hour)} - ${_hourLabel(nextHour)}';
}

String _hourLabel(int hour) {
  final normalizedHour = hour % 24;
  final suffix = normalizedHour >= 12 ? 'PM' : 'AM';
  final displayHour = normalizedHour == 0
      ? 12
      : (normalizedHour > 12 ? normalizedHour - 12 : normalizedHour);
  return '$displayHour:00 $suffix';
}

List<String> _slotsFromAvailability(AvailabilitySlot slot) {
  final fromHour = _hourValue(slot.from);
  final toHour = _hourValue(slot.to);
  if (fromHour == null ||
      toHour == null ||
      fromHour < 0 ||
      fromHour > 23 ||
      toHour > 24 ||
      toHour <= fromHour) {
    return const <String>[];
  }

  return <String>[
    for (var hour = fromHour; hour < toHour; hour += 1)
      '${hour.toString().padLeft(2, '0')}:00',
  ];
}

int? _hourValue(String value) {
  final match = RegExp(r'^\s*(\d{1,2})').firstMatch(value);
  final hour = int.tryParse(match?.group(1) ?? '');
  if (hour == null || hour < 0 || hour > 24) return null;
  return hour;
}

String _dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
