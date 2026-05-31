class BackendService {
  const BackendService({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
    this.nameAr = '',
    this.descriptionAr = '',
    this.priceUnit = 'fixed',
    this.estimatedDurationMin = 0,
    this.isActive = true,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.images = const [],
  });

  final String id;
  final String name;
  final String nameAr;
  final String category;
  final String description;
  final String descriptionAr;
  final double basePrice;
  final String priceUnit; // 'per_hour' | 'per_sqm' | 'fixed'
  final int estimatedDurationMin;
  final bool isActive;
  final double averageRating;
  final int totalReviews;
  final List<String> images;

  String get priceUnitLabel {
    switch (priceUnit) {
      case 'per_hour':
        return 'EGP/hr';
      case 'per_sqm':
        return 'EGP/m²';
      default:
        return 'EGP';
    }
  }

  factory BackendService.fromJson(Map<String, dynamic> json) => BackendService(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        name: (json['title'] as String?) ?? (json['name'] as String?) ?? '',
        nameAr: (json['titleAr'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        descriptionAr: (json['descriptionAr'] as String?) ?? '',
        basePrice: ((json['basePrice'] as num?) ?? 0).toDouble(),
        priceUnit: (json['priceUnit'] as String?) ?? 'fixed',
        estimatedDurationMin:
            ((json['estimatedDurationMin'] as num?) ?? 0).toInt(),
        isActive: (json['isActive'] as bool?) ?? true,
        averageRating: ((json['averageRating'] as num?) ?? 0).toDouble(),
        totalReviews: ((json['totalReviews'] as num?) ?? 0).toInt(),
        images: List<String>.from((json['images'] as List<dynamic>?) ?? []),
      );
}
