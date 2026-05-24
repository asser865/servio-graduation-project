class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.paymentId,
    required this.bookingId,
    required this.subtotal,
    required this.vatRate,
    required this.vat,
    required this.total,
    required this.currency,
    required this.issuedAt,
    this.pdfPath = '',
  });

  final String id;
  final String number;
  final String paymentId;
  final String bookingId;
  final double subtotal;
  final double vatRate;
  final double vat;
  final double total;
  final String currency;
  final DateTime issuedAt;
  final String pdfPath;

  String get displayTotal => '$currency ${total.toStringAsFixed(2)}';

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        number: (json['number'] as String?) ?? '',
        paymentId: (json['paymentId'] as String?) ?? '',
        bookingId: (json['bookingId'] as String?) ?? '',
        subtotal: ((json['subtotal'] as num?) ?? 0).toDouble(),
        vatRate: ((json['vatRate'] as num?) ?? 0.14).toDouble(),
        vat: ((json['vat'] as num?) ?? 0).toDouble(),
        total: ((json['total'] as num?) ?? 0).toDouble(),
        currency: (json['currency'] as String?) ?? 'EGP',
        issuedAt: DateTime.tryParse((json['issuedAt'] as String?) ?? '') ??
            DateTime.now(),
        pdfPath: (json['pdfPath'] as String?) ?? '',
      );
}
