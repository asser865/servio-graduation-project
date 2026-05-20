import 'package:http_parser/http_parser.dart' show MediaType;

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

  /// Calls the AI finishing model: uploads a room photo + dimensions +
  /// budget + style, receives a JSON finishing analysis plus a base64
  /// preview image of the suggested finish.
  Future<RoomAnalysisResponse> analyzeRoom({
    required List<int> imageBytes,
    required String filename,
    required MediaType contentType,
    required double lengthM,
    required double widthM,
    required double heightM,
    required int budgetEgp,
    String style = 'modern',
    bool includeRender = true,
  }) async {
    final response = await _client.postMultipart(
      ApiEndpoints.aiAnalyzeRoom,
      fields: <String, String>{
        'length_m': lengthM.toString(),
        'width_m': widthM.toString(),
        'height_m': heightM.toString(),
        'budget_egp': budgetEgp.toString(),
        'style': style,
        'include_render': includeRender.toString(),
      },
      fileField: MultipartFilePart(
        field: 'image',
        bytes: imageBytes,
        filename: filename,
        contentType: contentType,
      ),
      // SD render on CPU + Gemini Vision can take several minutes on cold
      // start. Match backend axios ceiling (180s) plus a small buffer.
      timeoutOverride: const Duration(seconds: 200),
    );
    return RoomAnalysisResponse.fromJson(response);
  }
}

class ServiceStep {
  const ServiceStep({required this.service, required this.urgency});

  final String service;
  final String urgency;

  String get urgencyLabel {
    switch (urgency) {
      case 'urgent':
        return 'Book First';
      case 'same_day':
        return 'Same Day';
      case 'high':
        return 'High Priority';
      default:
        return 'Schedule Later';
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

// ── AI finishing model (analyze-room) ───────────────────────────────────────

/// Top-level response from `/ai/analyze-room`. Mirrors the FastAPI shape
/// `{ status, data: { room_analysis, finishing_plans, recommended_plan },
///   generated_room_image }`. The Node backend wraps it again in its
/// `ApiResponse.success` envelope, so `unwrapData` is applied.
class RoomAnalysisResponse {
  const RoomAnalysisResponse({
    required this.roomAnalysis,
    required this.plans,
    required this.recommendedPlanName,
    required this.generatedImageBase64,
  });

  final RoomAnalysis roomAnalysis;
  final List<FinishingPlan> plans;
  final String recommendedPlanName;
  final String? generatedImageBase64;

  FinishingPlan get recommendedPlan {
    return plans.firstWhere(
      (FinishingPlan p) => p.name == recommendedPlanName,
      orElse: () => plans.isNotEmpty
          ? plans.first
          : const FinishingPlan(
              name: '',
              summary: '',
              totalCostEgp: 0,
              breakdown: <String, num>{},
              materials: <PlanMaterial>[],
              labor: <PlanLabor>[],
              palette: <String>[],
              durationDays: 0,
            ),
    );
  }

  List<FinishingPlan> get alternatePlans => plans
      .where((FinishingPlan p) => p.name != recommendedPlanName)
      .toList(growable: false);

  factory RoomAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final wrapped = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    // Backend forwards FastAPI's { status, data, generated_room_image }
    // — the Node wrapper places that whole object under `data` again.
    final inner = (wrapped['data'] is Map<String, dynamic>)
        ? wrapped['data'] as Map<String, dynamic>
        : wrapped;

    final roomAnalysisJson = inner['room_analysis'];
    final plansJson = inner['finishing_plans'];

    return RoomAnalysisResponse(
      roomAnalysis: roomAnalysisJson is Map<String, dynamic>
          ? RoomAnalysis.fromJson(roomAnalysisJson)
          : const RoomAnalysis.empty(),
      plans: plansJson is List
          ? plansJson
              .whereType<Map<String, dynamic>>()
              .map(FinishingPlan.fromJson)
              .toList(growable: false)
          : const <FinishingPlan>[],
      recommendedPlanName: _firstString(<dynamic>[inner['recommended_plan']]),
      generatedImageBase64: _firstString(<dynamic>[
        wrapped['generated_room_image'],
        inner['generated_room_image'],
        json['generated_room_image'],
      ]).isEmpty
          ? null
          : _firstString(<dynamic>[
              wrapped['generated_room_image'],
              inner['generated_room_image'],
              json['generated_room_image'],
            ]),
    );
  }
}

/// Structural description of the user's room as returned by the model.
class RoomAnalysis {
  const RoomAnalysis({
    required this.roomType,
    required this.currentCondition,
    required this.detectedFeatures,
    required this.style,
  });

  const RoomAnalysis.empty()
      : roomType = '',
        currentCondition = '',
        detectedFeatures = const <String>[],
        style = '';

  final String roomType;
  final String currentCondition;
  final List<String> detectedFeatures;
  final String style;

  factory RoomAnalysis.fromJson(Map<String, dynamic> json) {
    final features = json['detected_features'];
    return RoomAnalysis(
      roomType: _firstString(<dynamic>[json['room_type'], json['type']]),
      currentCondition: _firstString(<dynamic>[
        json['current_condition'],
        json['condition'],
      ]),
      detectedFeatures: features is List
          ? features.map((dynamic e) => e.toString()).toList(growable: false)
          : const <String>[],
      style: _firstString(<dynamic>[json['style'], json['detected_style']]),
    );
  }
}

/// One finishing plan suggested by the model. The model returns several;
/// one is flagged as `recommended_plan`.
class FinishingPlan {
  const FinishingPlan({
    required this.name,
    required this.summary,
    required this.totalCostEgp,
    required this.breakdown,
    required this.materials,
    required this.labor,
    required this.palette,
    required this.durationDays,
  });

  final String name;
  final String summary;
  final num totalCostEgp;
  final Map<String, num> breakdown;
  final List<PlanMaterial> materials;
  final List<PlanLabor> labor;
  final List<String> palette;
  final int durationDays;

  factory FinishingPlan.fromJson(Map<String, dynamic> json) {
    final materialsJson = json['materials'];
    final laborJson    = json['labor'];
    final paletteJson  = json['color_palette'];

    // Prefer explicit cost_breakdown map; fall back to the two subtotal fields
    // that Gemini actually returns (materials_subtotal_egp / labor_subtotal_egp).
    final breakdownJson = json['cost_breakdown'];
    final Map<String, num> breakdown;
    if (breakdownJson is Map<String, dynamic> && breakdownJson.isNotEmpty) {
      breakdown = breakdownJson.map<String, num>(
        (String k, dynamic v) => MapEntry<String, num>(k, _firstNum(<dynamic>[v])),
      );
    } else {
      final matSub   = _firstNum(<dynamic>[json['materials_subtotal_egp']]);
      final laborSub = _firstNum(<dynamic>[json['labor_subtotal_egp']]);
      breakdown = <String, num>{
        if (matSub   > 0) 'materials': matSub,
        if (laborSub > 0) 'labor': laborSub,
      };
    }

    return FinishingPlan(
      name: _firstString(<dynamic>[json['plan_name'], json['name']]),
      summary: _firstString(<dynamic>[
        json['description'],
        json['summary'],
        json['overview'],
      ]),
      totalCostEgp: _firstNum(<dynamic>[
        json['total_cost_egp'],
        json['total_cost'],
        json['cost'],
      ]),
      breakdown: breakdown,
      materials: materialsJson is List
          ? materialsJson
              .whereType<Map<String, dynamic>>()
              .map(PlanMaterial.fromJson)
              .toList(growable: false)
          : const <PlanMaterial>[],
      labor: laborJson is List
          ? laborJson
              .whereType<Map<String, dynamic>>()
              .map(PlanLabor.fromJson)
              .toList(growable: false)
          : const <PlanLabor>[],
      palette: paletteJson is List
          ? paletteJson.map((dynamic e) => e.toString()).toList(growable: false)
          : const <String>[],
      // Gemini returns timeline_days; also accept duration_days for compat.
      durationDays: _firstNum(<dynamic>[
        json['timeline_days'],
        json['duration_days'],
        json['durationDays'],
      ]).toInt(),
    );
  }
}

/// Materials line item inside a [FinishingPlan].
class PlanMaterial {
  const PlanMaterial({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedCostEgp,
  });

  final String name;
  final String quantity;
  final String unit;
  final num estimatedCostEgp;

  factory PlanMaterial.fromJson(Map<String, dynamic> json) {
    return PlanMaterial(
      name: _firstString(<dynamic>[json['name'], json['material']]),
      quantity: _firstString(<dynamic>[json['quantity'], json['qty']]),
      unit: _firstString(<dynamic>[json['unit']]),
      estimatedCostEgp: _firstNum(<dynamic>[
        json['estimated_cost_egp'],
        json['estimated_cost'],
        json['cost'],
      ]),
    );
  }
}

/// Labor line item inside a [FinishingPlan].
class PlanLabor {
  const PlanLabor({
    required this.trade,
    required this.description,
    required this.days,
    required this.dailyRateEgp,
    required this.totalEgp,
  });

  final String trade;
  final String description;
  final int days;
  final num dailyRateEgp;
  final num totalEgp;

  factory PlanLabor.fromJson(Map<String, dynamic> json) {
    return PlanLabor(
      trade: _firstString(<dynamic>[json['trade']]),
      description: _firstString(<dynamic>[json['description']]),
      days: _firstNum(<dynamic>[json['days']]).toInt(),
      dailyRateEgp: _firstNum(<dynamic>[
        json['daily_rate_egp'],
        json['dailyRateEgp'],
        json['rate'],
      ]),
      totalEgp: _firstNum(<dynamic>[
        json['total_egp'],
        json['total'],
        json['cost'],
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
