// mobile-app/lib/src/features/booking/booking_step_two_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/customer_address.dart';
import '../../core/models/user_account.dart';
import '../../core/services/location_service.dart';
import '../../core/state/customer_addresses_state.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/create_address_screen.dart';
import 'booking_flow_data.dart';
import 'booking_step_three_screen.dart';
import 'booking_strings.dart';
import 'widgets/address_selector_section.dart';
import 'widgets/booking_progress_indicator.dart';
import 'widgets/date_carousel.dart';
import 'widgets/time_slot_grid.dart';

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
  int _weekOffset = 0;
  late List<DateTime> _days;
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

  @override
  void initState() {
    super.initState();
    _days = _buildDays(0);
    _selectedDate = _firstAvailableDate(_days) ?? _days.first;
    _selectedSlot = _firstSlotFor(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CustomerAddressesProvider>().load();
    });
  }

  List<DateTime> _buildDays(int weekOffset) {
    final base =
        DateTime.now().add(Duration(days: 1 + weekOffset * 7));
    final normalized = DateTime(base.year, base.month, base.day);
    return List<DateTime>.generate(
        7, (int i) => normalized.add(Duration(days: i)));
  }

  DateTime? _firstAvailableDate(List<DateTime> days) {
    for (final DateTime day in days) {
      if (_isAvailableDate(day)) return day;
    }
    return null;
  }

  bool _isAvailableDate(DateTime day) {
    if (!widget.data.requiresTechnicianAvailabilityCheck) return true;
    return widget.data.technicianAvailabilityFor(day) != null;
  }

  List<String> _slotsForDate(DateTime day) {
    final AvailabilitySlot? slot =
        widget.data.technicianAvailabilityFor(day);
    if (slot == null) {
      return widget.data.requiresTechnicianAvailabilityCheck
          ? const <String>[]
          : _fallbackSlots;
    }
    return _slotsFromAvailability(slot);
  }

  String _firstSlotFor(DateTime day) {
    final List<String> slots = _slotsForDate(day);
    return slots.isEmpty ? '' : slots.first;
  }

  void _selectDate(DateTime day) {
    if (!_isAvailableDate(day)) return;
    setState(() {
      _selectedDate = day;
      _selectedSlot = _firstSlotFor(day);
    });
  }

  void _prevWeek() {
    if (_weekOffset <= 0) return;
    setState(() {
      _weekOffset--;
      _days = _buildDays(_weekOffset);
      _selectedDate = _firstAvailableDate(_days) ?? _days.first;
      _selectedSlot = _firstSlotFor(_selectedDate);
    });
  }

  void _nextWeek() {
    setState(() {
      _weekOffset++;
      _days = _buildDays(_weekOffset);
      _selectedDate = _firstAvailableDate(_days) ?? _days.first;
      _selectedSlot = _firstSlotFor(_selectedDate);
    });
  }

  void _continue() {
    if (!_isAvailableDate(_selectedDate) || _selectedSlot.isEmpty) return;
    final CustomerAddress? address = _selectedAddress(
        context.read<CustomerAddressesProvider>().addresses);
    if (address == null) {
      setState(
          () => _addressError = BookingStrings.selectAddressError);
      return;
    }

    final int selectedHour =
        int.tryParse(_selectedSlot.split(':').first) ?? 10;
    final DateTime scheduledDateTime = DateTime(
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
    final CustomerAddress? saved =
        await Navigator.of(context).push<CustomerAddress>(
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
      setState(
          () => _addressLatLng = LatLng(address.lat!, address.lng!));
      return;
    }
    setState(() {
      _addressLatLng = null;
      _geocoding = true;
    });
    final LatLng? latLng = await LocationService()
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
      for (final CustomerAddress address in addresses) {
        if (address.id == _selectedAddressId) return address;
      }
    }
    if (widget.data.addressStreet.isNotEmpty) {
      for (final CustomerAddress address in addresses) {
        if (address.street == widget.data.addressStreet) return address;
      }
    }
    return addresses.first;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    final Color navyAnchor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.backgroundDark;
    final bool selectedDateAvailable = _isAvailableDate(_selectedDate);
    final List<String> slots = selectedDateAvailable
        ? _slotsForDate(_selectedDate)
        : const <String>[];
    final CustomerAddressesProvider addressProvider =
        context.watch<CustomerAddressesProvider>();
    final CustomerAddress? selectedAddress =
        _selectedAddress(addressProvider.addresses);
    final bool canContinue = selectedDateAvailable &&
        _selectedSlot.isNotEmpty &&
        selectedAddress != null &&
        !addressProvider.loading;

    return Scaffold(
      backgroundColor: isDark
          ? ServioColors.backgroundDark
          : const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: isDark
            ? ServioColors.backgroundDark.withValues(alpha: 0.95)
            : const Color(0xFFFBF9F6).withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: navyAnchor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          BookingStrings.pickDateAndTime,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: navyAnchor,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: navyAnchor),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
          ),
        ),
      ),
      bottomNavigationBar: _BottomContinueBar(
        onPressed: canContinue ? _continue : null,
      ),
      body: Column(
        children: <Widget>[
          BookingProgressIndicator(
            currentStep: 2,
            totalSteps: 3,
            stepLabels: BookingStrings.stepLabels,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                8,
                ServioSpacing.screenPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DateCarousel(
                    days: _days,
                    selectedDate: _selectedDate,
                    onDateSelected: _selectDate,
                    isAvailable: _isAvailableDate,
                    monthLabel:
                        DateFormat('MMMM y').format(_days.first),
                    onPrevWeek: _prevWeek,
                    onNextWeek: _nextWeek,
                    canGoPrevWeek: _weekOffset > 0,
                  ),
                  const SizedBox(height: 32),
                  TimeSlotGrid(
                    slots: slots,
                    selectedSlot: _selectedSlot,
                    onSlotSelected: (String slot) =>
                        setState(() => _selectedSlot = slot),
                    isDateAvailable: selectedDateAvailable,
                  ),
                  const SizedBox(height: 32),
                  AddressSelectorSection(
                    addresses: addressProvider.addresses,
                    selectedAddress: selectedAddress,
                    loading: addressProvider.loading,
                    geocoding: _geocoding,
                    addressLatLng: _addressLatLng,
                    error: addressProvider.error,
                    addressError: _addressError,
                    onRetry: () =>
                        context.read<CustomerAddressesProvider>().load(),
                    onAdd: _addAddress,
                    onSelect: (CustomerAddress address) {
                      setState(() {
                        _selectedAddressId = address.id;
                        _addressError = null;
                      });
                      _onAddressSelected(address);
                    },
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

class _BottomContinueBar extends StatelessWidget {
  const _BottomContinueBar({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    final double bottomPadding =
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? ServioColors.backgroundDark.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF9A8C73).withValues(alpha: 0.12),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        ServioSpacing.screenPadding,
        12,
        ServioSpacing.screenPadding,
        12 + bottomPadding,
      ),
      child: ServioPrimaryButton(
        label: BookingStrings.continueLabel,
        onPressed: onPressed,
      ),
    );
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

String _slotLabel(String value) {
  final int hour = int.tryParse(value.split(':').first) ?? 0;
  final int nextHour = hour + 1;
  return '${_hourLabel(hour)} - ${_hourLabel(nextHour)}';
}

String _hourLabel(int hour) {
  final int normalizedHour = hour % 24;
  final String suffix = normalizedHour >= 12 ? 'PM' : 'AM';
  final int displayHour = normalizedHour == 0
      ? 12
      : (normalizedHour > 12 ? normalizedHour - 12 : normalizedHour);
  return '$displayHour:00 $suffix';
}

List<String> _slotsFromAvailability(AvailabilitySlot slot) {
  final int? fromHour = _hourValue(slot.from);
  final int? toHour = _hourValue(slot.to);
  if (fromHour == null ||
      toHour == null ||
      fromHour < 0 ||
      fromHour > 23 ||
      toHour > 24 ||
      toHour <= fromHour) {
    return const <String>[];
  }
  return <String>[
    for (int hour = fromHour; hour < toHour; hour += 1)
      '${hour.toString().padLeft(2, '0')}:00',
  ];
}

int? _hourValue(String value) {
  final RegExpMatch? match =
      RegExp(r'^\s*(\d{1,2})').firstMatch(value);
  final int? hour = int.tryParse(match?.group(1) ?? '');
  if (hour == null || hour < 0 || hour > 24) return null;
  return hour;
}
