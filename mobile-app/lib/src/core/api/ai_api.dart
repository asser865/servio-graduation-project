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

class AiRecommendationResponse {
  const AiRecommendationResponse({
    required this.predictedCategory,
    required this.confidence,
    required this.serviceName,
    required this.priceRange,
    required this.recommendedWorkers,
  });

  final String predictedCategory;
  final double confidence;
  final String serviceName;
  final String priceRange;
  final List<RecommendedWorker> recommendedWorkers;

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

    return AiRecommendationResponse(
      predictedCategory: _firstString(<dynamic>[
        json['predictedCategory'],
        json['category'],
        json['serviceCategory'],
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
      ]),
      priceRange: _firstString(<dynamic>[
        json['priceRange'],
        json['estimatedCost'],
        json['budgetLabel'],
      ]),
      recommendedWorkers: workers
          .whereType<Map<String, dynamic>>()
          .map(RecommendedWorker.fromJson)
          .toList(),
    );
  }
}

class RecommendedWorker {
  const RecommendedWorker({
    required this.id,
    required this.name,
    required this.matchLabel,
    required this.reason,
  });

  final String id;
  final String name;
  final String matchLabel;
  final String reason;

  factory RecommendedWorker.fromJson(Map<String, dynamic> json) {
    final worker = json['worker'];
    final workerJson = worker is Map<String, dynamic> ? worker : json;
    final score = _firstNum(<dynamic>[
      json['matchScore'],
      json['score'],
      json['confidence'],
    ]);
    final scoreLabel = score <= 0
        ? _firstString(<dynamic>[json['match'], json['matchLabel']])
        : '${(score <= 1 ? score * 100 : score).round()}%';

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
      ]),
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
