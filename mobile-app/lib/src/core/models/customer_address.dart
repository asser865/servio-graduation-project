class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.cityArea,
    required this.isDefault,
    this.landmarkInstructions,
  });

  final String id;
  final String label;
  final String fullAddress;
  final String cityArea;
  final String? landmarkInstructions;
  final bool isDefault;

  String get displayAddress {
    final parts = <String>[
      fullAddress,
      cityArea,
      if (landmarkInstructions != null && landmarkInstructions!.isNotEmpty)
        landmarkInstructions!,
    ];
    return parts.join('\n');
  }

  CustomerAddress copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? cityArea,
    String? landmarkInstructions,
    bool? isDefault,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      cityArea: cityArea ?? this.cityArea,
      landmarkInstructions: landmarkInstructions ?? this.landmarkInstructions,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
