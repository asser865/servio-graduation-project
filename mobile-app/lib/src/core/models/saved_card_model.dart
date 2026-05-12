class SavedCardModel {
  const SavedCardModel({
    required this.id,
    required this.last4,
    required this.expiry,
    required this.cardType,
    required this.label,
    required this.isDefault,
  });

  final String id;
  final String last4;
  final String expiry;
  final String cardType;
  final String label;
  final bool isDefault;

  factory SavedCardModel.fromJson(Map<String, dynamic> json) {
    return SavedCardModel(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      last4: (json['last4'] as String?) ?? '',
      expiry: (json['expiry'] as String?) ?? '',
      cardType: (json['cardType'] as String?) ?? 'other',
      label: (json['label'] as String?) ?? '',
      isDefault: (json['isDefault'] as bool?) ?? false,
    );
  }

  String get displayLabel {
    final brand = switch (cardType.toLowerCase()) {
      'visa' => 'Visa',
      'mastercard' => 'Mastercard',
      'amex' => 'Amex',
      _ => 'Card',
    };
    final prefix = label.trim().isNotEmpty ? '$label - ' : '';
    return '$prefix$brand ending $last4';
  }
}
