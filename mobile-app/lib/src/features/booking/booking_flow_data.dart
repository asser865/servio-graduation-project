import '../../core/models/user_account.dart';

class BookingFlowData {
  const BookingFlowData({
    this.serviceName = '',
    this.category = '',
    this.technicianName = '',
    this.technicianId = '',
    this.serviceId = '',
    this.backendId = '',
    this.specialty = '',
    this.priceLabel = '',
    this.hourlyRate = '',
    this.technicianAvailability = const <AvailabilitySlot>[],
    this.date = '',
    this.time = '',
    this.scheduledDateTime,
    this.location = '',
    this.addressCity = '',
    this.addressStreet = '',
    this.notes = '',
    this.paymentMethod = 'Cash',
    this.paymentMethodCode = 'cash',
    this.savedCardId = '',
    this.savedCardLabel = '',
    this.savedCardLast4 = '',
    this.statusLabel = 'Pending',
    this.statusCode = 'pending',
    this.reference = '',
    this.amount = '0 EGP',
    this.pin = '',
    this.createdAt,
    this.paymentId = '',
  });

  final String serviceName;
  final String category;
  final String technicianName;
  final String technicianId;
  final String serviceId;
  final String backendId;
  final String specialty;
  final String priceLabel;
  final String hourlyRate;
  final List<AvailabilitySlot> technicianAvailability;
  final String date;
  final String time;
  final DateTime? scheduledDateTime;
  final String location;
  final String addressCity;
  final String addressStreet;
  final String notes;
  final String paymentMethod;
  final String paymentMethodCode;
  final String savedCardId;
  final String savedCardLabel;
  final String savedCardLast4;
  final String statusLabel;
  final String statusCode;
  final String reference;
  final String amount;
  final String pin;
  final DateTime? createdAt;
  final String paymentId;

  BookingFlowData copyWith({
    String? serviceName,
    String? category,
    String? technicianName,
    String? technicianId,
    String? serviceId,
    String? backendId,
    String? specialty,
    String? priceLabel,
    String? hourlyRate,
    List<AvailabilitySlot>? technicianAvailability,
    String? date,
    String? time,
    DateTime? scheduledDateTime,
    String? location,
    String? addressCity,
    String? addressStreet,
    String? notes,
    String? paymentMethod,
    String? paymentMethodCode,
    String? savedCardId,
    String? savedCardLabel,
    String? savedCardLast4,
    String? statusLabel,
    String? statusCode,
    String? reference,
    String? amount,
    String? pin,
    DateTime? createdAt,
    String? paymentId,
  }) {
    return BookingFlowData(
      serviceName: serviceName ?? this.serviceName,
      category: category ?? this.category,
      technicianName: technicianName ?? this.technicianName,
      technicianId: technicianId ?? this.technicianId,
      serviceId: serviceId ?? this.serviceId,
      backendId: backendId ?? this.backendId,
      specialty: specialty ?? this.specialty,
      priceLabel: priceLabel ?? this.priceLabel,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      technicianAvailability:
          technicianAvailability ?? this.technicianAvailability,
      date: date ?? this.date,
      time: time ?? this.time,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      location: location ?? this.location,
      addressCity: addressCity ?? this.addressCity,
      addressStreet: addressStreet ?? this.addressStreet,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodCode: paymentMethodCode ?? this.paymentMethodCode,
      savedCardId: savedCardId ?? this.savedCardId,
      savedCardLabel: savedCardLabel ?? this.savedCardLabel,
      savedCardLast4: savedCardLast4 ?? this.savedCardLast4,
      statusLabel: statusLabel ?? this.statusLabel,
      statusCode: statusCode ?? this.statusCode,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
      pin: pin ?? this.pin,
      createdAt: createdAt ?? this.createdAt,
      paymentId: paymentId ?? this.paymentId,
    );
  }

  bool get requiresTechnicianAvailabilityCheck =>
      technicianId.trim().isNotEmpty || technicianAvailability.isNotEmpty;

  AvailabilitySlot? technicianAvailabilityFor(DateTime date) {
    final day = _weekdayKey(date);
    for (final slot in technicianAvailability) {
      if (_normalizeDay(slot.day) == day && _hasWorkingHours(slot)) {
        return slot;
      }
    }
    return null;
  }

  bool isTechnicianAvailableOn(DateTime date) {
    if (!requiresTechnicianAvailabilityCheck) return true;
    return technicianAvailabilityFor(date) != null;
  }

  bool get isScheduledDateAvailable {
    final scheduled = scheduledDateTime;
    if (scheduled == null) return !requiresTechnicianAvailabilityCheck;
    return isTechnicianAvailableOn(scheduled);
  }
}

const List<String> _weekdayKeys = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

String _weekdayKey(DateTime date) => _weekdayKeys[date.weekday - 1];

String _normalizeDay(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

bool _hasWorkingHours(AvailabilitySlot slot) {
  final from = _hourValue(slot.from);
  final to = _hourValue(slot.to);
  return from != null && to != null && from < to;
}

int? _hourValue(String value) {
  final match = RegExp(r'^\s*(\d{1,2})').firstMatch(value);
  final hour = int.tryParse(match?.group(1) ?? '');
  if (hour == null || hour < 0 || hour > 24) return null;
  return hour;
}
