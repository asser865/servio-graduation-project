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
