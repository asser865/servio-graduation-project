import 'user_account.dart';
import 'service_category.dart';
import '../api/api_config.dart';

class BackendWorkerService {
  const BackendWorkerService({
    required this.id,
    required this.name,
    required this.category,
    this.basePrice = 0,
    this.priceUnit = '',
  });

  final String id;
  final String name;
  final String category;
  final double basePrice;
  final String priceUnit;

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    return _readableLabel(category);
  }

  factory BackendWorkerService.fromJson(dynamic value) {
    if (value is String) {
      return BackendWorkerService(id: value, name: '', category: '');
    }
    if (value is Map<String, dynamic>) {
      return BackendWorkerService(
        id: _stringValue(value['_id'], fallback: _stringValue(value['id'])),
        name: _firstStringValue(<dynamic>[
          value['title'],
          value['name'],
        ]),
        category: _stringValue(value['category']),
        basePrice: ((value['basePrice'] as num?) ?? 0).toDouble(),
        priceUnit: _stringValue(value['priceUnit']),
      );
    }
    return const BackendWorkerService(id: '', name: '', category: '');
  }
}

class BackendWorker {
  const BackendWorker({
    required this.id,
    required this.name,
    required this.email,
    required this.profileImage,
    required this.bio,
    required this.skills,
    required this.categories,
    required this.services,
    required this.locationLabel,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.yearsExperience,
    required this.availabilityType,
    required this.availability,
  });

  final String id;
  final String name;
  final String email;
  final String profileImage;
  final String bio;
  final List<String> skills;
  final List<String> categories;
  final List<BackendWorkerService> services;
  final String locationLabel;
  final int hourlyRate;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final int yearsExperience;
  final String availabilityType;
  final List<AvailabilitySlot> availability;

  String get displayName => name.trim().isNotEmpty ? name.trim() : 'Technician';

  List<String> get serviceLabels {
    final serviceNames = services
        .map((service) => service.displayName)
        .where((label) => label.trim().isNotEmpty)
        .toList();
    if (serviceNames.isNotEmpty) return _dedupe(serviceNames);

    final categoryNames = categories
        .map(_readableLabel)
        .where((label) => label.trim().isNotEmpty)
        .toList();
    if (categoryNames.isNotEmpty) return _dedupe(categoryNames);

    return _dedupe(skills.map(_readableLabel).toList());
  }

  String get primaryServiceLabel {
    final labels = serviceLabels;
    return labels.isNotEmpty ? labels.first : '';
  }

  bool offersService(String serviceId) {
    final normalized = serviceId.trim();
    if (normalized.isEmpty) return false;
    return services.any((service) => service.id == normalized);
  }

  bool offersCategory(String category) {
    final normalized = normalizeServiceCategory(category);
    if (normalized.isEmpty) return false;
    final workerCategories =
        categories.map(normalizeServiceCategory).where((c) => c.isNotEmpty);
    if (workerCategories.contains(normalized)) return true;
    return services.any(
      (service) => normalizeServiceCategory(service.category) == normalized,
    );
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
  }

  factory BackendWorker.fromJson(Map<String, dynamic> json) => BackendWorker(
        id: _firstStringValue(<dynamic>[json['_id'], json['id']]),
        name: _stringValue(json['name']),
        email: _stringValue(json['email']),
        profileImage:
            ApiConfig.normalizeBackendUrl(_stringValue(json['profileImage'])),
        bio: _stringValue(json['bio']),
        skills: _stringList(json['skills']),
        categories: _stringList(json['categories']),
        services: _serviceList(json['services']),
        locationLabel: _stringValue(json['locationLabel']),
        hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toInt(),
        rating:
            ((json['rating'] as num?) ?? (json['averageRating'] as num?) ?? 0)
                .toDouble(),
        reviewCount: ((json['reviewCount'] as num?) ??
                (json['totalReviews'] as num?) ??
                0)
            .toInt(),
        isVerified: (json['isVerified'] as bool?) ?? false,
        yearsExperience: ((json['yearsExperience'] as num?) ?? 0).toInt(),
        availabilityType: _stringValue(json['availabilityType']),
        availability: _availabilityList(json['availability']),
      );
}

List<AvailabilitySlot> _availabilityList(dynamic value) {
  if (value is! List<dynamic>) return const <AvailabilitySlot>[];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(item)))
      .where((slot) => slot.day.trim().isNotEmpty)
      .toList();
}

List<String> _stringList(dynamic value) {
  if (value is! List<dynamic>) return const <String>[];
  return value
      .map(_stringValue)
      .where((item) => item.trim().isNotEmpty)
      .toList();
}

List<BackendWorkerService> _serviceList(dynamic value) {
  if (value is! List<dynamic>) return const <BackendWorkerService>[];
  return value
      .map(BackendWorkerService.fromJson)
      .where(
          (service) => service.id.isNotEmpty || service.displayName.isNotEmpty)
      .toList();
}

String _firstStringValue(List<dynamic> values) {
  for (final value in values) {
    final result = _stringValue(value);
    if (result.isNotEmpty) return result;
  }
  return '';
}

String _stringValue(dynamic value, {String fallback = ''}) {
  if (value is String) return value.trim();
  return fallback;
}

List<String> _dedupe(List<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) result.add(trimmed);
  }
  return result;
}

String _readableLabel(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[-_]+'), ' ');
  if (normalized.isEmpty) return '';
  final lower = normalized.toLowerCase();
  if (lower == 'hvac' || lower == 'ac') return lower.toUpperCase();
  return normalized.split(RegExp(r'\s+')).map((part) {
    if (part.length <= 3 && part.toUpperCase() == part) return part;
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }).join(' ');
}
