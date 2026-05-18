import 'api_client.dart';
import 'api_endpoints.dart';

class AiApi {
  AiApi(this._client);

  final ApiClient _client;

  Future<AiRecommendationResponse> recommend({
    required String description,
    String location = '',
    num? budget,
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.aiRecommend, <String, dynamic>{
        'description': description,
        'location': location,
        'budget': budget,
      }),
    );
    return AiRecommendationResponse.fromJson(data);
  }
}

class ServiceStep {
  const ServiceStep({required this.service, required this.urgency});

  final String service;
  final String urgency;

  String get urgencyLabel {
    switch (urgency) {
      case 'urgent':    return 'Book First';
      case 'same_day':  return 'Same Day';
      case 'high':      return 'High Priority';
      default:          return 'Schedule Later';
    }
  }

  factory ServiceStep.fromJson(Map<String, dynamic> json) {
    return ServiceStep(
      service: _firstString(<dynamic>[json['service']]),
      urgency: _firstString(<dynamic>[json['urgency']]),
    );
  }
}

class AiRecommendationResponse {
  const AiRecommendationResponse({
    required this.predictedCategory,
    required this.confidence,
    required this.serviceName,
    required this.priceRange,
    required this.recommendedWorkers,
    required this.scenario,
    required this.steps,
  });

  final String predictedCategory;
  final double confidence;
  final String serviceName;
  final String priceRange;
  final List<RecommendedWorker> recommendedWorkers;
  final String scenario;
  final List<ServiceStep> steps;

  bool get isMulti => scenario == 'multi' && steps.length > 1;

  String get confidenceLabel {
    if (confidence <= 0) return 'AI Match';
    final value = confidence <= 1 ? confidence * 100 : confidence;
    return '${value.round()}% Match';
  }

  factory AiRecommendationResponse.fromJson(Map<String, dynamic> json) {
    final workers = _firstList(<dynamic>[
      json['recommendedWorkers'],
      json['workers'],
      json['technicians'],
      json['matches'],
    ]);

    final rawSteps = json['steps'];
    final steps = (rawSteps is List)
        ? rawSteps
            .whereType<Map<String, dynamic>>()
            .map(ServiceStep.fromJson)
            .where((s) => s.service.isNotEmpty)
            .toList()
        : <ServiceStep>[];

    return AiRecommendationResponse(
      predictedCategory: _firstString(<dynamic>[
        json['predictedCategory'],
        json['category'],
        json['serviceCategory'],
        json['recommended_service'],
      ]),
      confidence: _firstNum(<dynamic>[
        json['confidence'],
        json['matchScore'],
        json['score'],
      ]).toDouble(),
      serviceName: _firstString(<dynamic>[
        json['serviceName'],
        json['recommendedService'],
        json['title'],
        json['recommended_service'],
      ]),
      priceRange: _firstString(<dynamic>[
        json['priceRange'],
        json['estimatedCost'],
        json['budgetLabel'],
        json['price_range'],
      ]),
      recommendedWorkers: workers
          .whereType<Map<String, dynamic>>()
          .map(RecommendedWorker.fromJson)
          .toList(),
      scenario: _firstString(<dynamic>[json['scenario'], json['issue_mode']]),
      steps: steps,
    );
  }
}

class RecommendedWorker {
  const RecommendedWorker({
    required this.id,
    required this.name,
    required this.matchLabel,
    required this.reason,
    this.profileImage,
    this.averageRating,
    this.totalReviews,
    this.locationLabel,
    this.categories = const <String>[],
  });

  final String id;
  final String name;
  final String matchLabel;
  final String reason;
  final String? profileImage;
  final double? averageRating;
  final int? totalReviews;
  final String? locationLabel;
  final List<String> categories;

  factory RecommendedWorker.fromJson(Map<String, dynamic> json) {
    final worker = json['worker'];
    final workerJson = worker is Map<String, dynamic> ? worker : json;
    final score = _firstNum(<dynamic>[
      json['matchScore'],
      json['score'],
      json['confidence'],
    ]);
    final rating = _firstNum(<dynamic>[
      workerJson['averageRating'],
      workerJson['rating'],
    ]);
    String scoreLabel;
    if (score > 0) {
      scoreLabel = '${(score <= 1 ? score * 100 : score).round()}%';
    } else if (rating > 0) {
      scoreLabel = '★ ${rating.toStringAsFixed(1)}';
    } else {
      scoreLabel = _firstString(<dynamic>[json['match'], json['matchLabel']]);
    }

    return RecommendedWorker(
      id: _firstString(<dynamic>[workerJson['_id'], workerJson['id']]),
      name: _firstString(<dynamic>[
        workerJson['name'],
        json['name'],
        json['technicianName'],
      ]),
      matchLabel: scoreLabel.isEmpty ? 'Match' : scoreLabel,
      reason: _firstString(<dynamic>[
        json['reason'],
        json['explanation'],
        json['why'],
        workerJson['bio'],
      ]),
      profileImage: workerJson['profileImage'] as String?,
      averageRating: rating > 0 ? rating.toDouble() : null,
      totalReviews: workerJson['totalReviews'] as int?,
      locationLabel: workerJson['locationLabel'] as String?,
      categories: (workerJson['categories'] is List)
          ? List<String>.from(
              (workerJson['categories'] as List).map((e) => e.toString()))
          : <String>[],
    );
  }
}

String _firstString(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
  }
  return '';
}

num _firstNum(List<dynamic> values) {
  for (final value in values) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

List<dynamic> _firstList(List<dynamic> values) {
  for (final value in values) {
    if (value is List<dynamic>) return value;
  }
  return const <dynamic>[];
}
