import 'package:intl/intl.dart';

import 'backend_booking_model.dart';
import 'user_account.dart';

enum BookingStatus {
  pending,
  confirmed,
  enRoute,
  arrived,
  inProgress,
  awaitingCustomerConfirmation,
  completed,
  cancelled,
  rejected,
  disputed,
}

extension BookingStatusX on BookingStatus {
  bool get isActive => switch (this) {
        BookingStatus.pending ||
        BookingStatus.confirmed ||
        BookingStatus.enRoute ||
        BookingStatus.arrived ||
        BookingStatus.inProgress ||
        BookingStatus.awaitingCustomerConfirmation =>
          true,
        BookingStatus.completed ||
        BookingStatus.cancelled ||
        BookingStatus.rejected ||
        BookingStatus.disputed =>
          false,
      };

  bool get isPast => !isActive;
}

class BookingModel {
  BookingModel({
    required this.id,
    required this.reference,
    required this.serviceName,
    this.serviceId = '',
    this.serviceCategory = '',
    required this.technicianName,
    required this.technicianId,
    required this.date,
    required this.time,
    required this.location,
    required this.amount,
    required this.status,
    required this.pin,
    required this.paymentMethod,
    required this.paymentCardLabel,
    required this.paymentCardLast4,
    this.notes = '',
    this.technicianAvailability = const <AvailabilitySlot>[],
  });

  final String id;
  final String reference;
  final String serviceName;
  final String serviceId;
  final String serviceCategory;
  final String technicianName;
  final String technicianId;
  final String date;
  final String time;
  final String location;
  final String amount;
  final BookingStatus status;
  final String pin;
  final String paymentMethod;
  final String paymentCardLabel;
  final String paymentCardLast4;
  final String notes;
  final List<AvailabilitySlot> technicianAvailability;

  BookingModel copyWith({BookingStatus? status}) {
    return BookingModel(
      id: id,
      reference: reference,
      serviceName: serviceName,
      serviceId: serviceId,
      serviceCategory: serviceCategory,
      technicianName: technicianName,
      technicianId: technicianId,
      date: date,
      time: time,
      location: location,
      amount: amount,
      status: status ?? this.status,
      pin: pin,
      paymentMethod: paymentMethod,
      paymentCardLabel: paymentCardLabel,
      paymentCardLast4: paymentCardLast4,
      notes: notes,
      technicianAvailability: technicianAvailability,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'serviceName': serviceName,
        'serviceId': serviceId,
        'serviceCategory': serviceCategory,
        'technicianName': technicianName,
        'technicianId': technicianId,
        'date': date,
        'time': time,
        'location': location,
        'amount': amount,
        'status': status.name,
        'pin': pin,
        'paymentMethod': paymentMethod,
        'paymentCardLabel': paymentCardLabel,
        'paymentCardLast4': paymentCardLast4,
        'notes': notes,
        'technicianAvailability':
            technicianAvailability.map((slot) => slot.toJson()).toList(),
      };

  factory BookingModel.fromBackend(BackendBooking b) => BookingModel(
        id: b.id,
        reference:
            '#${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id.toUpperCase()}',
        serviceName: b.serviceName.isNotEmpty ? b.serviceName : 'Service',
        serviceId: b.serviceId,
        serviceCategory: b.serviceCategory,
        technicianName: b.workerName.isNotEmpty ? b.workerName : 'Technician',
        technicianId: b.workerId,
        date: DateFormat('MMM d, y').format(b.scheduledDate),
        time: b.scheduledTime.isNotEmpty
            ? _displayScheduledTime(b.scheduledTime)
            : DateFormat('h:mm a').format(b.scheduledDate),
        location: _displayAddress(b.addressStreet, b.addressCity),
        amount: 'EGP ${b.totalAmount.toStringAsFixed(0)}',
        status: _parseBookingStatus(b.status),
        pin: b.pin,
        paymentMethod: _paymentMethodLabel(b.paymentMethod),
        paymentCardLabel: b.paymentCardLabel,
        paymentCardLast4: b.paymentCardLast4,
        notes: b.notes,
        technicianAvailability: b.workerAvailability,
      );

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String,
        reference: json['reference'] as String,
        serviceName: json['serviceName'] as String,
        serviceId: (json['serviceId'] as String?) ?? '',
        serviceCategory: (json['serviceCategory'] as String?) ?? '',
        technicianName: json['technicianName'] as String,
        technicianId: json['technicianId'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        location: json['location'] as String,
        amount: json['amount'] as String,
        status: BookingStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => BookingStatus.pending,
        ),
        pin: (json['pin'] as String?) ?? '',
        paymentMethod: (json['paymentMethod'] as String?) ?? 'Cash',
        paymentCardLabel: (json['paymentCardLabel'] as String?) ?? '',
        paymentCardLast4: (json['paymentCardLast4'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        technicianAvailability:
            _availabilityFromJson(json['technicianAvailability']),
      );
}

List<AvailabilitySlot> _availabilityFromJson(dynamic value) {
  if (value is! List<dynamic>) return const <AvailabilitySlot>[];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(item)))
      .where((slot) => slot.day.trim().isNotEmpty)
      .toList();
}

BookingStatus _parseBookingStatus(String s) => switch (s.toLowerCase()) {
      'pending' => BookingStatus.pending,
      'confirmed' || 'accepted' || 'scheduled' => BookingStatus.confirmed,
      'en_route' || 'enroute' => BookingStatus.enRoute,
      'arrived' => BookingStatus.arrived,
      'in_progress' || 'inprogress' => BookingStatus.inProgress,
      'awaiting_customer_confirmation' ||
      'awaitingcustomerconfirmation' =>
        BookingStatus.awaitingCustomerConfirmation,
      'completed' || 'done' => BookingStatus.completed,
      'cancelled' || 'canceled' => BookingStatus.cancelled,
      'rejected' => BookingStatus.rejected,
      'disputed' => BookingStatus.disputed,
      _ => BookingStatus.pending,
    };

String _paymentMethodLabel(String value) {
  return switch (value.toLowerCase()) {
    'card' || 'online' => 'Credit Card',
    'cash' => 'Cash',
    _ => value.trim().isEmpty ? 'Cash' : value,
  };
}

String _displayAddress(String street, String city) {
  final value =
      <String>[street, city].where((part) => part.trim().isNotEmpty).join(', ');
  return value.isNotEmpty ? value : 'Cairo';
}

String _displayScheduledTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:00 $suffix';
}
