class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.status,
    required this.payoutMethod,
    required this.payoutDetails,
    required this.requestedAt,
    this.transactionRef = '',
    this.adminNote = '',
  });

  final String id;
  final String workerId;
  final double amount;
  final String status;
  final String payoutMethod;
  final Map<String, dynamic> payoutDetails;
  final DateTime requestedAt;
  final String transactionRef;
  final String adminNote;

  bool get isPending => status == 'pending';

  factory PayoutRequest.fromJson(Map<String, dynamic> json) => PayoutRequest(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        workerId: (json['workerId'] as String?) ?? '',
        amount: ((json['amount'] as num?) ?? 0).toDouble(),
        status: (json['status'] as String?) ?? 'pending',
        payoutMethod: (json['payoutMethod'] as String?) ?? '',
        payoutDetails: (json['payoutDetails'] as Map<String, dynamic>?) ??
            <String, dynamic>{},
        requestedAt:
            DateTime.tryParse((json['requestedAt'] as String?) ?? '') ??
                DateTime.now(),
        transactionRef: (json['transactionRef'] as String?) ?? '',
        adminNote: (json['adminNote'] as String?) ?? '',
      );
}
