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
    required this.addressCity,
    required this.addressStreet,
    required this.customerName,
    required this.customerId,
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
  final String addressCity;
  final String addressStreet;
  final String customerName;
  final String customerId;

  factory BackendBooking.fromJson(Map<String, dynamic> json) {
    // worker is a raw ObjectId string (not populated by getWorkerBookings)
    final worker = json['worker'];
    String workerName = '';
    String workerId = '';
    if (worker is Map<String, dynamic>) {
      workerName = (worker['name'] as String?) ?? '';
      workerId = (worker['_id'] as String?) ?? '';
    } else if (worker is String) {
      workerId = worker;
    }

    // service is a populated object { _id, title, category, basePrice, priceUnit }
    final service = json['service'];
    String serviceName = (json['serviceName'] as String?) ?? '';
    String serviceId = '';
    if (service is Map<String, dynamic>) {
      serviceName = (service['title'] as String?) ?? serviceName;
      serviceId = (service['_id'] as String?) ?? '';
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

    return BackendBooking(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      scheduledDate:
          DateTime.tryParse((json['scheduledDate'] as String?) ?? '') ??
              DateTime.now(),
      scheduledTime: (json['scheduledTime'] as String?) ?? '',
      totalAmount: ((json['totalPrice'] as num?) ?? 0).toDouble(),
      notes: (json['description'] as String?) ?? '',
      workerName: workerName,
      workerId: workerId,
      serviceName: serviceName,
      serviceId: serviceId,
      addressCity: addressCity,
      addressStreet: addressStreet,
      customerName: customerName,
      customerId: customerId,
    );
  }
}
