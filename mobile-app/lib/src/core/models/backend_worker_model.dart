class BackendWorker {
  const BackendWorker({
    required this.id,
    required this.name,
    required this.email,
    required this.skills,
    required this.locationLabel,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.availabilityType,
  });

  final String id;
  final String name;
  final String email;
  final List<String> skills;
  final String locationLabel;
  final int hourlyRate;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String availabilityType;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'T';
  }

  factory BackendWorker.fromJson(Map<String, dynamic> json) => BackendWorker(
        id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        skills: ((json['skills'] as List<dynamic>?) ?? <dynamic>[]).cast<String>(),
        locationLabel: (json['locationLabel'] as String?) ?? '',
        hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toInt(),
        rating: ((json['rating'] as num?) ?? 0).toDouble(),
        reviewCount: ((json['reviewCount'] as num?) ?? 0).toInt(),
        isVerified: (json['isVerified'] as bool?) ?? false,
        availabilityType: (json['availabilityType'] as String?) ?? 'both',
      );
}
