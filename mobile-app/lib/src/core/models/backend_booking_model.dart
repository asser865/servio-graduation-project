import 'user_account.dart';

class BackendBooking {
  const BackendBooking({
    required this.id,
    required this.status,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.totalAmount,
    required this.notes,
    required this.workerName,
    required this.workerId,
    required this.serviceName,
    required this.serviceId,
    required this.serviceCategory,
    required this.addressCity,
    required this.addressStreet,
    required this.customerName,
    required this.customerId,
    required this.pin,
    required this.paymentMethod,
    required this.paymentCardLast4,
    required this.paymentCardType,
    required this.paymentCardLabel,
    this.workerAvailability = const <AvailabilitySlot>[],
  });

  final String id;
  final String status;
  final DateTime scheduledDate;
  final String scheduledTime;
  final double totalAmount;
  final String notes;
  final String workerName;
  final String workerId;
  final String serviceName;
  final String serviceId;
  final String serviceCategory;
  final String addressCity;
  final String addressStreet;
  final String customerName;
  final String customerId;
  final String pin;
  final String paymentMethod;
  final String paymentCardLast4;
  final String paymentCardType;
  final String paymentCardLabel;
  final List<AvailabilitySlot> workerAvailability;

  factory BackendBooking.fromJson(Map<String, dynamic> json) {
    // worker is a raw ObjectId string (not populated by getWorkerBookings)
    final worker = json['worker'];
    String workerName = '';
    var workerAvailability = const <AvailabilitySlot>[];
    String workerId = _firstAssignmentId(<dynamic>[
      json['workerId'],
      json['technicianId'],
      json['assignedTo'],
      json['assignedWorker'],
    ]);
    if (worker is Map<String, dynamic>) {
      workerName = (worker['name'] as String?) ?? '';
      workerAvailability = _availabilityList(worker['availability']);
      workerId = _firstStringValue(<dynamic>[
        worker['_id'],
        worker['id'],
        workerId,
      ]);
    } else if (worker is String) {
      workerId = worker;
    }
    if (workerId.isEmpty) {
      workerId = _firstAssignmentId(<dynamic>[
        json['assignedTo'],
        json['assignedWorker'],
      ]);
    }

    // service is a populated object { _id, title, category, basePrice, priceUnit }
    final service = json['service'];
    String serviceName = (json['serviceName'] as String?) ?? '';
    String serviceId = '';
    String serviceCategory = (json['serviceCategory'] as String?) ?? '';
    if (service is Map<String, dynamic>) {
      serviceName = (service['title'] as String?) ?? serviceName;
      serviceId = (service['_id'] as String?) ?? '';
      serviceCategory = (service['category'] as String?) ?? serviceCategory;
    } else if (service is String) {
      serviceId = service;
    }

    // user is a populated object { _id, name, phone, profileImage }
    final user = json['user'];
    String customerName = '';
    String customerId = '';
    if (user is Map<String, dynamic>) {
      customerName = (user['name'] as String?) ?? '';
      customerId = (user['_id'] as String?) ?? '';
    } else if (user is String) {
      customerId = user;
    }

    final addressRaw = json['address'];
    var addressCity = '';
    var addressStreet = '';
    if (addressRaw is String) {
      addressCity = addressRaw;
    } else if (addressRaw is Map<String, dynamic>) {
      addressCity = (addressRaw['city'] as String?) ?? '';
      addressStreet = (addressRaw['street'] as String?) ?? '';
    }

    final paymentMeta = json['paymentMeta'] is Map<String, dynamic>
        ? json['paymentMeta'] as Map<String, dynamic>
        : <String, dynamic>{};
    final savedCard = json['savedCard'] is Map<String, dynamic>
        ? json['savedCard'] as Map<String, dynamic>
        : <String, dynamic>{};

    return BackendBooking(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      scheduledDate:
          DateTime.tryParse((json['scheduledDate'] as String?) ?? '') ??
              DateTime.now(),
      scheduledTime: (json['scheduledTime'] as String?) ?? '',
      totalAmount: (((json['totalPrice'] as num?) ??
                  (json['totalAmount'] as num?) ??
                  (json['amount'] as num?)) ??
              0)
          .toDouble(),
      notes: (json['description'] as String?) ?? '',
      workerName: workerName,
      workerId: workerId,
      serviceName: serviceName,
      serviceId: serviceId,
      serviceCategory: serviceCategory,
      addressCity: addressCity,
      addressStreet: addressStreet,
      customerName: customerName,
      customerId: customerId,
      pin: (json['pin'] as String?) ?? '',
      paymentMethod: (json['paymentMethod'] as String?) ?? '',
      paymentCardLast4: (paymentMeta['last4'] as String?) ??
          (savedCard['last4'] as String?) ??
          '',
      paymentCardType: (paymentMeta['cardType'] as String?) ??
          (savedCard['cardType'] as String?) ??
          '',
      paymentCardLabel: (paymentMeta['label'] as String?) ??
          (savedCard['label'] as String?) ??
          '',
      workerAvailability: workerAvailability,
    );
  }

  /// Creates a copy of this booking with the given fields replaced.
  /// Used by optimistic UI updates to immediately reflect a new status
  /// in local state before the API call completes.
  BackendBooking copyWith({String? status}) {
    return BackendBooking(
      id: id,
      status: status ?? this.status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      totalAmount: totalAmount,
      notes: notes,
      workerName: workerName,
      workerId: workerId,
      serviceName: serviceName,
      serviceId: serviceId,
      serviceCategory: serviceCategory,
      addressCity: addressCity,
      addressStreet: addressStreet,
      customerName: customerName,
      customerId: customerId,
      pin: pin,
      paymentMethod: paymentMethod,
      paymentCardLast4: paymentCardLast4,
      paymentCardType: paymentCardType,
      paymentCardLabel: paymentCardLabel,
      workerAvailability: workerAvailability,
    );
  }
}

List<AvailabilitySlot> _availabilityList(dynamic value) {
  if (value is! List<dynamic>) return const <AvailabilitySlot>[];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(item)))
      .where((slot) => slot.day.trim().isNotEmpty)
      .toList();
}

String _assignmentIdFrom(dynamic value) {
  if (value is String) return value;
  if (value is Map<String, dynamic>) {
    return _firstStringValue(<dynamic>[value['_id'], value['id']]);
  }
  return '';
}

String _firstAssignmentId(List<dynamic> values) {
  for (final value in values) {
    final id = _assignmentIdFrom(value);
    if (id.trim().isNotEmpty) return id.trim();
  }
  return '';
}

String _firstStringValue(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
