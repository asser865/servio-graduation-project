class CustomerAddress {
  const CustomerAddress({
    required this.id,
    this.label = 'Address',
    this.street = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.lat,
    this.lng,
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? lat;
  final double? lng;

  String get displayLabel => label.trim().isEmpty ? 'Address' : label.trim();

  String get formattedSingleLine => <String>[
        street,
        city,
        state,
        zipCode,
      ].where((part) => part.trim().isNotEmpty).join(', ');

  String get displayAddress {
    final parts = <String>[
      street,
      [city, state].where((part) => part.trim().isNotEmpty).join(', '),
      zipCode,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join('\n');
  }

  Map<String, dynamic> toBackendPayload() => <String, dynamic>{
        'label': label.trim(),
        'street': street.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'zipCode': zipCode.trim(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  CustomerAddress copyWith({
    String? id,
    String? label,
    String? street,
    String? city,
    String? state,
    String? zipCode,
    double? lat,
    double? lng,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  factory CustomerAddress.fromBackend(Map<String, dynamic> json) {
    return CustomerAddress(
      id: ((json['_id'] as String?) ?? (json['id'] as String?) ?? '').trim(),
      label: (json['label'] as String?) ?? 'Address',
      street: (json['street'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      zipCode: (json['zipCode'] as String?) ?? '',
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
    );
  }
}
