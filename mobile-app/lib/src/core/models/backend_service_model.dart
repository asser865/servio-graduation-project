class BackendService {
  const BackendService({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double basePrice;

  factory BackendService.fromJson(Map<String, dynamic> json) => BackendService(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        name: (json['title'] as String?) ?? (json['name'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        basePrice: ((json['basePrice'] as num?) ?? 0).toDouble(),
      );
}
