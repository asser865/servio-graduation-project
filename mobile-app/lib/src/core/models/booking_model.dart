import 'package:intl/intl.dart';

import 'backend_booking_model.dart';

enum BookingStatus { upcoming, inProgress, completed, cancelled }

class BookingModel {
  BookingModel({
    required this.id,
    required this.reference,
    required this.serviceName,
    required this.technicianName,
    required this.technicianId,
    required this.date,
    required this.time,
    required this.location,
    required this.amount,
    required this.status,
    required this.pin,
    this.notes = '',
  });

  final String id;
  final String reference;
  final String serviceName;
  final String technicianName;
  final String technicianId;
  final String date;
  final String time;
  final String location;
  final String amount;
  final BookingStatus status;
  final String pin;
  final String notes;

  BookingModel copyWith({BookingStatus? status}) {
    return BookingModel(
      id: id,
      reference: reference,
      serviceName: serviceName,
      technicianName: technicianName,
      technicianId: technicianId,
      date: date,
      time: time,
      location: location,
      amount: amount,
      status: status ?? this.status,
      pin: pin,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'serviceName': serviceName,
        'technicianName': technicianName,
        'technicianId': technicianId,
        'date': date,
        'time': time,
        'location': location,
        'amount': amount,
        'status': status.name,
        'pin': pin,
        'notes': notes,
      };

  factory BookingModel.fromBackend(BackendBooking b) => BookingModel(
        id: b.id,
        reference:
            '#${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id.toUpperCase()}',
        serviceName: b.serviceName.isNotEmpty ? b.serviceName : 'Service',
        technicianName: b.workerName.isNotEmpty ? b.workerName : 'Technician',
        technicianId: b.workerId,
        date: DateFormat('MMM d, y').format(b.scheduledDate),
        time: b.scheduledTime.isNotEmpty
            ? _displayScheduledTime(b.scheduledTime)
            : DateFormat('h:mm a').format(b.scheduledDate),
        location: b.addressCity.isNotEmpty ? b.addressCity : 'Cairo',
        amount: 'EGP ${b.totalAmount.toStringAsFixed(0)}',
        status: _parseBookingStatus(b.status),
        pin: '0000',
        notes: b.notes,
      );

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String,
        reference: json['reference'] as String,
        serviceName: json['serviceName'] as String,
        technicianName: json['technicianName'] as String,
        technicianId: json['technicianId'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        location: json['location'] as String,
        amount: json['amount'] as String,
        status: BookingStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => BookingStatus.upcoming,
        ),
        pin: json['pin'] as String,
        notes: (json['notes'] as String?) ?? '',
      );
}

BookingStatus _parseBookingStatus(String s) => switch (s) {
      'confirmed' || 'pending' || 'accepted' => BookingStatus.upcoming,
      'in_progress' || 'inProgress' => BookingStatus.inProgress,
      'completed' => BookingStatus.completed,
      _ => BookingStatus.cancelled,
    };

String _displayScheduledTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:00 $suffix';
}
