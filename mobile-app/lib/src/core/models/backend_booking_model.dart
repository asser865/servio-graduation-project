class BackendBooking {
  const BackendBooking({
    required this.id,
    required this.status,
    required this.scheduledDate,
    required this.totalAmount,
    required this.notes,
    required this.workerName,
    required this.workerId,
    required this.serviceName,
    required this.serviceId,
    required this.addressCity,
    required this.addressStreet,
  });

  final String id;
  final String status;
  final DateTime scheduledDate;
  final double totalAmount;
  final String notes;
  final String workerName;
  final String workerId;
  final String serviceName;
  final String serviceId;
  final String addressCity;
  final String addressStreet;

  factory BackendBooking.fromJson(Map<String, dynamic> json) {
    final worker = json['workerId'];
    final service = json['serviceId'];
    final address = json['address'] as Map<String, dynamic>?;

    String workerName = '';
    String workerId = '';
    if (worker is Map<String, dynamic>) {
      workerName = (worker['name'] as String?) ?? '';
      workerId = (worker['_id'] as String?) ?? '';
    } else if (worker is String) {
      workerId = worker;
    }

    String serviceName = '';
    String serviceId = '';
    if (service is Map<String, dynamic>) {
      serviceName = (service['name'] as String?) ?? '';
      serviceId = (service['_id'] as String?) ?? '';
    } else if (service is String) {
      serviceId = service;
    }

    return BackendBooking(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      scheduledDate: DateTime.tryParse((json['scheduledDate'] as String?) ?? '') ?? DateTime.now(),
      totalAmount: ((json['totalAmount'] as num?) ?? 0).toDouble(),
      notes: (json['notes'] as String?) ?? '',
      workerName: workerName,
      workerId: workerId,
      serviceName: serviceName,
      serviceId: serviceId,
      addressCity: (address?['city'] as String?) ?? '',
      addressStreet: (address?['street'] as String?) ?? '',
    );
  }
}
