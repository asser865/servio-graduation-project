class CustomerCredit {
  const CustomerCredit({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.source,
    required this.balanceRemaining,
    required this.consumed,
    this.reason = '',
    this.expiresAt,
  });

  final String id;
  final String customerId;
  final double amount;
  final String source;
  final double balanceRemaining;
  final bool consumed;
  final String reason;
  final DateTime? expiresAt;

  bool get isValid => !consumed && balanceRemaining > 0;

  factory CustomerCredit.fromJson(Map<String, dynamic> json) => CustomerCredit(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        customerId: (json['customerId'] as String?) ?? '',
        amount: ((json['amount'] as num?) ?? 0).toDouble(),
        source: (json['source'] as String?) ?? '',
        balanceRemaining:
            ((json['balanceRemaining'] as num?) ?? 0).toDouble(),
        consumed: (json['consumed'] as bool?) ?? false,
        reason: (json['reason'] as String?) ?? '',
        expiresAt: DateTime.tryParse((json['expiresAt'] as String?) ?? ''),
      );
}
