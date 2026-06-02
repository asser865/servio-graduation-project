class CashDebt {
  const CashDebt({
    required this.id,
    required this.workerId,
    required this.bookingId,
    required this.amount,
    required this.paidAmount,
    required this.remaining,
    required this.status,
    required this.currency,
    this.autoDeductedAt,
    this.paidAt,
  });

  final String id;
  final String workerId;
  final String bookingId;
  final double amount;
  final double paidAmount;
  final double remaining;
  final String status;
  final String currency;
  final DateTime? autoDeductedAt;
  final DateTime? paidAt;

  bool get isPaid => status == 'paid';
  bool get isOutstanding => status == 'outstanding';

  factory CashDebt.fromJson(Map<String, dynamic> json) => CashDebt(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        workerId: (json['workerId'] as String?) ?? '',
        bookingId: (json['bookingId'] as String?) ?? '',
        amount: ((json['amount'] as num?) ?? 0).toDouble(),
        paidAmount: ((json['paidAmount'] as num?) ?? 0).toDouble(),
        remaining: ((json['remaining'] as num?) ?? 0).toDouble(),
        status: (json['status'] as String?) ?? 'outstanding',
        currency: (json['currency'] as String?) ?? 'EGP',
        autoDeductedAt:
            DateTime.tryParse((json['autoDeductedAt'] as String?) ?? ''),
        paidAt: DateTime.tryParse((json['paidAt'] as String?) ?? ''),
      );
}

class CashDebtSummary {
  const CashDebtSummary({
    required this.totalOutstanding,
    required this.warningThreshold,
    required this.blockThreshold,
    required this.debts,
  });

  final double totalOutstanding;
  final double warningThreshold;
  final double blockThreshold;
  final List<CashDebt> debts;

  bool get isWarning =>
      totalOutstanding >= warningThreshold && totalOutstanding < blockThreshold;
  bool get isBlocked => totalOutstanding >= blockThreshold;

  factory CashDebtSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? json;
    final rawDebts = (json['debts'] as List<dynamic>?) ?? <dynamic>[];
    return CashDebtSummary(
      totalOutstanding:
          ((summary['totalOutstanding'] as num?) ?? 0).toDouble(),
      warningThreshold:
          ((summary['warningThreshold'] as num?) ?? 500).toDouble(),
      blockThreshold: ((summary['blockThreshold'] as num?) ?? 1000).toDouble(),
      debts: rawDebts
          .whereType<Map<String, dynamic>>()
          .map(CashDebt.fromJson)
          .toList(),
    );
  }
}
