class SupportIssue {
  const SupportIssue({
    required this.id,
    required this.bookingId,
    required this.status,
    required this.type,
    required this.description,
    required this.createdAt,
    this.priority = 'normal',
    this.resolution,
    this.workerName,
    this.serviceName,
    this.serviceCategory,
    this.evidence = const <String>[],
    this.updatedAt,
  });

  final String id;
  final String bookingId;
  final String status;
  final String type;
  final String priority;
  final String description;
  final String? resolution;
  final String? workerName;
  final String? serviceName;
  final String? serviceCategory;
  final List<String> evidence;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isOpen => !['resolved', 'closed'].contains(status);
  bool get isResolved => status == 'resolved' || status == 'closed';

  String get displayStatus => _statusLabels[status] ?? 'Open';
  String get displayType => _typeLabels[type] ?? 'Other';
  String get displayService => serviceName ?? serviceCategory ?? 'Service booking';

  static const Map<String, String> _statusLabels = <String, String>{
    'open': 'Open',
    'reviewing': 'Reviewing',
    'waiting_customer': 'Waiting for you',
    'waiting_worker': 'Waiting for technician',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  static const Map<String, String> _typeLabels = <String, String>{
    'late': 'Late arrival',
    'no_show': 'No-show',
    'during_work_problem': 'During-work problem',
    'safety': 'Safety concern',
    'post_completion': 'Post-completion issue',
    'other': 'Other',
  };

  factory SupportIssue.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'];
    String? workerName;
    String? serviceName;
    String? serviceCategory;
    String bookingId;

    if (booking is Map<String, dynamic>) {
      bookingId = (booking['_id'] as String?) ?? (booking['id'] as String?) ?? '';
      final worker = booking['worker'];
      if (worker is Map<String, dynamic>) {
        workerName = (worker['name'] as String?) ?? (worker['fullName'] as String?);
      } else if (worker is String) {
        workerName = null;
      }
      final service = booking['service'];
      if (service is Map<String, dynamic>) {
        serviceName = (service['title'] as String?) ?? (service['name'] as String?);
      } else if (service is String) {
        serviceName = service;
      }
      serviceCategory = (booking['serviceCategory'] as String?);
    } else if (booking is String) {
      bookingId = booking;
    } else {
      bookingId = (json['bookingId'] as String?) ?? '';
    }

    // worker at top level (some responses populate it)
    if (workerName == null) {
      final topWorker = json['worker'];
      if (topWorker is Map<String, dynamic>) {
        workerName = (topWorker['name'] as String?) ?? (topWorker['fullName'] as String?);
      }
    }

    final rawEvidence = json['evidence'];
    final evidence = <String>[];
    if (rawEvidence is List<dynamic>) {
      for (final e in rawEvidence) {
        if (e is String) evidence.add(e);
        if (e is Map<String, dynamic>) {
          final url = e['url'] as String?;
          if (url != null && url.isNotEmpty) evidence.add(url);
        }
      }
    }

    return SupportIssue(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      bookingId: bookingId,
      status: (json['status'] as String?) ?? 'open',
      type: (json['type'] as String?) ?? 'other',
      priority: (json['priority'] as String?) ?? 'normal',
      description: (json['description'] as String?) ?? '',
      resolution: json['resolution'] as String?,
      workerName: workerName,
      serviceName: serviceName,
      serviceCategory: serviceCategory,
      evidence: evidence,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
    );
  }
}
