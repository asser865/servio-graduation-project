class DisputeEvidence {
  const DisputeEvidence({
    required this.url,
    required this.type,
    this.description = '',
    this.uploadedBy = '',
    this.uploadedByRole = 'user',
    this.uploadedAt,
  });

  final String url;
  final String type;
  final String description;
  final String uploadedBy;
  final String uploadedByRole;
  final DateTime? uploadedAt;

  factory DisputeEvidence.fromJson(Map<String, dynamic> json) =>
      DisputeEvidence(
        url: (json['url'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'image',
        description: (json['description'] as String?) ?? '',
        uploadedBy: _extractName(json['uploadedBy']),
        uploadedByRole: (json['uploadedByRole'] as String?) ?? 'user',
        uploadedAt: DateTime.tryParse((json['uploadedAt'] as String?) ?? ''),
      );
}

class DisputeHistory {
  const DisputeHistory({
    required this.status,
    required this.byRole,
    required this.at,
    this.byName,
    this.note,
  });

  final String status;
  final String byRole;
  final String? byName;
  final DateTime at;
  final String? note;

  factory DisputeHistory.fromJson(Map<String, dynamic> json) {
    final byRaw = json['by'];
    String? name;
    if (byRaw is Map<String, dynamic>) {
      name = (byRaw['name'] as String?) ?? (byRaw['fullName'] as String?);
    }
    return DisputeHistory(
      status: (json['status'] as String?) ?? '',
      byRole: (json['byRole'] as String?) ?? 'system',
      byName: name,
      at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
      note: json['note'] as String?,
    );
  }
}

class Dispute {
  const Dispute({
    required this.id,
    required this.bookingId,
    required this.paymentId,
    required this.raisedBy,
    required this.raisedByRole,
    required this.reason,
    required this.category,
    required this.status,
    required this.evidence,
    required this.createdAt,
    this.severity = 'medium',
    this.estimatedDamages = 0,
    this.resolution,
    this.appealStatus,
    this.slaFirstResponseDueAt,
    this.slaResolveDueAt,
    this.history = const <DisputeHistory>[],
    this.evidenceRequestedFrom,
    this.decision,
    this.refundAmount,
    this.resolvedAt,
    this.appealReason,
    this.appealedAt,
    this.customerName,
    this.serviceName,
  });

  final String id;
  final String bookingId;
  final String paymentId;
  final String raisedBy;
  final String raisedByRole;
  final String reason;
  final String category;
  final String severity;
  final double estimatedDamages;
  final String status;
  final List<DisputeEvidence> evidence;
  final String? resolution;
  final String? appealStatus;
  final DateTime? slaFirstResponseDueAt;
  final DateTime? slaResolveDueAt;
  final DateTime createdAt;

  final List<DisputeHistory> history;
  final String? evidenceRequestedFrom;
  final String? decision;
  final double? refundAmount;
  final DateTime? resolvedAt;
  final String? appealReason;
  final DateTime? appealedAt;
  final String? customerName;
  final String? serviceName;

  bool get isOpen =>
      status == 'open' ||
      status == 'reviewing' ||
      status == 'awaiting_evidence' ||
      status == 'appealed' ||
      status == 'escalated';
  bool get isResolved =>
      status == 'resolved_refund' ||
      status == 'resolved_release' ||
      status == 'resolved_partial' ||
      status == 'resolved_redo';

  factory Dispute.fromJson(Map<String, dynamic> json) {
    final rawEvidence = (json['evidence'] as List<dynamic>?) ?? <dynamic>[];
    final rawHistory = (json['history'] as List<dynamic>?) ?? <dynamic>[];

    final booking = json['booking'];
    String? customerName;
    String? serviceName;
    if (booking is Map<String, dynamic>) {
      final user = booking['user'];
      if (user is Map<String, dynamic>) {
        customerName =
            (user['name'] as String?) ?? (user['fullName'] as String?);
      }
      final service = booking['service'];
      if (service is Map<String, dynamic>) {
        serviceName = (service['name'] as String?);
      } else if (service is String) {
        serviceName = service;
      }
    }

    return Dispute(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      bookingId: _extractId(json['bookingId'] ?? json['booking']),
      paymentId: _extractId(json['paymentId'] ?? json['payment']),
      raisedBy: _extractId(json['raisedBy']),
      raisedByRole: (json['raisedByRole'] as String?) ?? 'customer',
      reason: (json['reason'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other',
      severity: (json['severity'] as String?) ?? 'medium',
      estimatedDamages: ((json['estimatedDamages'] as num?) ?? 0).toDouble(),
      status: (json['status'] as String?) ?? 'open',
      evidence: rawEvidence
          .whereType<Map<String, dynamic>>()
          .map(DisputeEvidence.fromJson)
          .toList(),
      resolution: json['resolution'] as String?,
      appealStatus: json['appealStatus'] as String?,
      slaFirstResponseDueAt: DateTime.tryParse(
          (json['slaFirstResponseDueAt'] as String?) ?? ''),
      slaResolveDueAt:
          DateTime.tryParse((json['slaResolveDueAt'] as String?) ?? ''),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
              DateTime.now(),
      history: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(DisputeHistory.fromJson)
          .toList(),
      evidenceRequestedFrom: json['evidenceRequestedFrom'] as String?,
      decision: json['decision'] as String?,
      refundAmount: (json['refundAmount'] as num?)?.toDouble(),
      resolvedAt: DateTime.tryParse((json['resolvedAt'] as String?) ?? ''),
      appealReason: json['appealReason'] as String?,
      appealedAt: DateTime.tryParse((json['appealedAt'] as String?) ?? ''),
      customerName: customerName,
      serviceName: serviceName,
    );
  }
}

String _extractId(dynamic value) {
  if (value is String) return value;
  if (value is Map<String, dynamic>) {
    return (value['_id'] as String?) ?? (value['id'] as String?) ?? '';
  }
  return '';
}

String _extractName(dynamic value) {
  if (value is String) return value;
  if (value is Map<String, dynamic>) {
    return (value['name'] as String?) ?? (value['fullName'] as String?) ?? '';
  }
  return '';
}
