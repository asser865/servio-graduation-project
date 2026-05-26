class DebtSettlement {
  const DebtSettlement({
    required this.id,
    required this.workerId,
    required this.debtIds,
    required this.totalAmount,
    required this.method,
    required this.status,
    required this.submittedAt,
    this.reference = '',
    this.proofUrl = '',
    this.rejectionReason,
  });

  final String id;
  final String workerId;
  final List<String> debtIds;
  final double totalAmount;
  final String method;
  final String status;
  final DateTime submittedAt;
  final String reference;
  final String proofUrl;
  final String? rejectionReason;

  bool get isPending => status == 'pending_verification';
  bool get isVerified => status == 'verified';

  factory DebtSettlement.fromJson(Map<String, dynamic> json) => DebtSettlement(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        workerId: (json['workerId'] as String?) ?? '',
        debtIds: ((json['debts'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        totalAmount: ((json['totalAmount'] as num?) ?? 0).toDouble(),
        method: (json['method'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending_verification',
        submittedAt:
            DateTime.tryParse((json['submittedAt'] as String?) ?? '') ??
                DateTime.now(),
        reference: (json['reference'] as String?) ?? '',
        proofUrl: (json['proofUrl'] as String?) ?? '',
        rejectionReason: json['rejectionReason'] as String?,
      );
}
