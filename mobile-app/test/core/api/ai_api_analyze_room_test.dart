import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/ai_api.dart';
import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/api_exception.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('analyzeRoom posts multipart payload with all fields', () async {
    String? capturedPath;
    String? capturedMethod;
    String? capturedBody;
    String? capturedContentType;

    final api = await _api((http.Request request) async {
      capturedPath = request.url.path;
      capturedMethod = request.method;
      capturedBody = String.fromCharCodes(request.bodyBytes);
      capturedContentType = request.headers['content-type'];
      return _json(_successPayload());
    });

    final res = await api.analyzeRoom(
      imageBytes: const <int>[0x69, 0x6D, 0x67],
      filename: 'room.jpg',
      contentType: MediaType('image', 'jpeg'),
      lengthM: 4.5,
      widthM: 3.5,
      heightM: 2.7,
      budgetEgp: 15000,
      style: 'modern',
    );

    expect(capturedPath, '/mobile/ai/analyze-room');
    expect(capturedMethod, 'POST');
    expect(capturedContentType, isNotNull);
    expect(capturedContentType!.startsWith('multipart/form-data'), isTrue);

    expect(capturedBody, contains('name="length_m"'));
    expect(capturedBody, contains('4.5'));
    expect(capturedBody, contains('name="width_m"'));
    expect(capturedBody, contains('3.5'));
    expect(capturedBody, contains('name="height_m"'));
    expect(capturedBody, contains('name="budget_egp"'));
    expect(capturedBody, contains('15000'));
    expect(capturedBody, contains('name="style"'));
    expect(capturedBody, contains('modern'));
    expect(capturedBody, contains('name="include_render"'));
    expect(capturedBody, contains('true'));
    expect(capturedBody, contains('filename="room.jpg"'));

    expect(res.plans, hasLength(2));
    expect(res.recommendedPlanName, 'Modern Mid-Range');

    final recommended = res.recommendedPlan;
    expect(recommended.totalCostEgp, 14000);
    expect(recommended.durationDays, 7);

    expect(recommended.breakdown['materials'], 6500);
    expect(recommended.breakdown['labor'], 6000);

    expect(recommended.materials, hasLength(2));
    expect(recommended.materials.first.name, 'Ceramic floor tiles');

    expect(recommended.labor, hasLength(2));
    expect(recommended.labor.first.trade, 'Tiler');
    expect(recommended.labor.first.days, 3);
    expect(recommended.labor.first.dailyRateEgp, 700);
    expect(recommended.labor.first.totalEgp, 2100);

    expect(res.roomAnalysis.roomType, 'living-room');
    expect(res.roomAnalysis.detectedFeatures, contains('window'));
    expect(res.generatedImageBase64, isNotNull);
    expect(res.alternatePlans, hasLength(1));
    expect(res.alternatePlans.first.name, 'Budget Refresh');
  });

  // ── New field: wall_condition / estimatedCeilingHeightM / specialNotes ──────

  test('RoomAnalysis parses wall_condition, ceiling height, special_notes', () async {
    final api = await _api((_) async => _json(_successPayload()));
    final res = await _analyze(api);

    expect(res.roomAnalysis.wallCondition, 'bare brick');
    expect(res.roomAnalysis.currentCondition, 'bare brick');
    expect(res.roomAnalysis.estimatedCeilingHeightM, closeTo(2.8, 0.001));
    expect(res.roomAnalysis.specialNotes, contains('large window'));
  });

  // ── New field: recommendation_reason ────────────────────────────────────────

  test('RoomAnalysisResponse parses recommendation_reason', () async {
    final api = await _api((_) async => _json(_successPayload()));
    final res = await _analyze(api);

    expect(res.recommendationReason, contains('suitable'));
  });

  // ── New field: consistency_envelope ─────────────────────────────────────────

  test('ConsistencyEnvelope parsed correctly', () async {
    final api = await _api((_) async => _json(_successPayload()));
    final res = await _analyze(api);

    final env = res.consistencyEnvelope;
    expect(env.styleUsed, 'modern');
    expect(env.budgetTier, 'standard');
    expect(env.floorAreaM2, closeTo(15.75, 0.01));
    expect(env.primaryFlooring, contains('Ceramic'));
    expect(env.primaryWall, contains('Paint'));
    expect(env.sdPromptUsed, contains('porcelain'));
    expect(env.geminiTotalCost, 14000);
    expect(env.vendorAdjustedCost, 13500);
    expect(env.consistencyWarnings, isEmpty);
  });

  test('ConsistencyEnvelope.empty is the default when field missing', () async {
    final payload = _successPayload();
    (payload['data'] as Map<String, dynamic>).remove('consistency_envelope');
    final api = await _api((_) async => _json(payload));
    final res = await _analyze(api);

    expect(res.consistencyEnvelope, equals(ConsistencyEnvelope.empty));
    expect(res.consistencyEnvelope.budgetTier, isEmpty);
    expect(res.consistencyEnvelope.consistencyWarnings, isEmpty);
  });

  test('ConsistencyEnvelope warnings list parsed', () async {
    final payload = _successPayload();
    final env = ((payload['data'] as Map<String, dynamic>)['consistency_envelope']
        as Map<String, dynamic>);
    env['consistency_warnings'] = <String>['Flooring not in render', 'Style mismatch'];
    final api = await _api((_) async => _json(payload));
    final res = await _analyze(api);

    expect(res.consistencyEnvelope.consistencyWarnings, hasLength(2));
    expect(res.consistencyEnvelope.consistencyWarnings.first, contains('Flooring'));
  });

  // ── New PlanMaterial fields ──────────────────────────────────────────────────

  test('PlanMaterial parses category, unit_price_egp, notes, vendors', () async {
    final api = await _api((_) async => _json(_successPayload()));
    final res = await _analyze(api);

    final mat = res.recommendedPlan.materials.first;
    expect(mat.category, 'flooring');
    expect(mat.unitPriceEgp, 200);
    expect(mat.notes, contains('waste'));
    expect(mat.vendors, hasLength(2));
    expect(mat.vendors.first.name, 'Ceramica Cleopatra');
    expect(mat.vendors.first.source, 'fallback');
    expect(mat.vendors[1].name, 'RAK Ceramics');
  });

  test('PlanMaterial prefers total_egp over estimated_cost_egp', () async {
    final payload = _successPayload();
    final plans = ((payload['data'] as Map<String, dynamic>)['data']
        as Map<String, dynamic>)['finishing_plans'] as List<dynamic>;
    final mat = (plans[0]['materials'] as List<dynamic>)[0] as Map<String, dynamic>;
    mat['total_egp'] = 9999;
    mat['estimated_cost_egp'] = 1111;

    final api = await _api((_) async => _json(payload));
    final res = await _analyze(api);

    expect(res.recommendedPlan.materials.first.estimatedCostEgp, 9999);
  });

  test('PlanMaterial vendors empty list when field absent', () async {
    final payload = _successPayload();
    final plans = ((payload['data'] as Map<String, dynamic>)['data']
        as Map<String, dynamic>)['finishing_plans'] as List<dynamic>;
    final mat = (plans[0]['materials'] as List<dynamic>)[0] as Map<String, dynamic>;
    mat.remove('vendors');

    final api = await _api((_) async => _json(payload));
    final res = await _analyze(api);

    expect(res.recommendedPlan.materials.first.vendors, isEmpty);
  });

  // ── New FinishingPlan fields ─────────────────────────────────────────────────

  test('FinishingPlan parses planStyle and vendorAdjustedTotalEgp', () async {
    final api = await _api((_) async => _json(_successPayload()));
    final res = await _analyze(api);

    expect(res.recommendedPlan.planStyle, 'Contemporary modern');
    expect(res.recommendedPlan.vendorAdjustedTotalEgp, 13500);
  });

  test('FinishingPlan.vendorAdjustedTotalEgp defaults to 0 when absent', () async {
    final payload = _successPayload();
    final plans = ((payload['data'] as Map<String, dynamic>)['data']
        as Map<String, dynamic>)['finishing_plans'] as List<dynamic>;
    (plans[0] as Map<String, dynamic>).remove('vendor_adjusted_total_egp');

    final api = await _api((_) async => _json(payload));
    final res = await _analyze(api);

    expect(res.recommendedPlan.vendorAdjustedTotalEgp, 0);
  });

  // ── Backend error propagation ────────────────────────────────────────────────

  test('analyzeRoom surfaces backend error as ApiException', () async {
    final api = await _api((http.Request request) async {
      return _json(
        <String, dynamic>{
          'success': false,
          'message': 'Image too large.',
        },
        statusCode: 400,
      );
    });

    expect(
      () => api.analyzeRoom(
        imageBytes: const <int>[1, 2, 3],
        filename: 'big.jpg',
        contentType: MediaType('image', 'jpeg'),
        lengthM: 4,
        widthM: 4,
        heightM: 2.7,
        budgetEgp: 5000,
      ),
      throwsA(
        isA<ApiException>()
            .having((ApiException e) => e.statusCode, 'statusCode', 400)
            .having(
                (ApiException e) => e.message, 'message', 'Image too large.'),
      ),
    );
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Future<AiApi> _api(
  Future<http.Response> Function(http.Request request) handler,
) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((request) => handler(request)),
    baseUrl: 'http://localhost',
  );
  return AiApi(client);
}

Future<RoomAnalysisResponse> _analyze(AiApi api) => api.analyzeRoom(
      imageBytes: const <int>[0xFF, 0xD8, 0xFF],
      filename: 'room.jpg',
      contentType: MediaType('image', 'jpeg'),
      lengthM: 4.5,
      widthM: 3.5,
      heightM: 2.8,
      budgetEgp: 15000,
      style: 'modern',
    );

http.Response _json(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _successPayload() {
  return <String, dynamic>{
    'success': true,
    'message': 'ok',
    'data': <String, dynamic>{
      'status': 'success',
      'data': <String, dynamic>{
        'room_analysis': <String, dynamic>{
          'room_type': 'living-room',
          'wall_condition': 'bare brick',
          'detected_features': <String>['window', 'door'],
          'style': 'modern',
          'estimated_ceiling_height_m': 2.8,
          'special_notes': 'Room has a large window on the north wall.',
        },
        'finishing_plans': <Map<String, dynamic>>[
          <String, dynamic>{
            'plan_name': 'Modern Mid-Range',
            'style': 'Contemporary modern',
            'description': 'Balanced finish',
            'total_cost_egp': 14000,
            'materials_subtotal_egp': 6500,
            'labor_subtotal_egp': 6000,
            'vendor_adjusted_total_egp': 13500,
            'timeline_days': 7,
            'color_palette': <String>['#FAF8F5', '#9A8C73'],
            'materials': <Map<String, dynamic>>[
              <String, dynamic>{
                'category': 'flooring',
                'name': 'Ceramic floor tiles',
                'quantity': '16',
                'unit': 'm²',
                'unit_price_egp': 200,
                'total_egp': 3200,
                'notes': 'Include 10% waste factor. Ceramica Cleopatra recommended.',
                'vendors': <Map<String, dynamic>>[
                  <String, dynamic>{'name': 'Ceramica Cleopatra', 'source': 'fallback'},
                  <String, dynamic>{'name': 'RAK Ceramics', 'source': 'fallback'},
                ],
              },
              <String, dynamic>{
                'category': 'painting',
                'name': 'Latex wall paint',
                'quantity': '20',
                'unit': 'L',
                'unit_price_egp': 90,
                'total_egp': 1800,
                'notes': 'Two coats required.',
                'vendors': <Map<String, dynamic>>[
                  <String, dynamic>{'name': 'Jotun Egypt', 'source': 'fallback'},
                ],
              },
            ],
            'labor': <Map<String, dynamic>>[
              <String, dynamic>{
                'trade': 'Tiler',
                'description': 'Install ceramic floor tiles',
                'days': 3,
                'daily_rate_egp': 700,
                'total_egp': 2100,
              },
              <String, dynamic>{
                'trade': 'Painter',
                'description': 'Paint walls and ceiling',
                'days': 2,
                'daily_rate_egp': 600,
                'total_egp': 1200,
              },
            ],
          },
          <String, dynamic>{
            'plan_name': 'Budget Refresh',
            'style': 'Simple modern',
            'description': 'Lower-cost option',
            'total_cost_egp': 8000,
            'cost_breakdown': <String, dynamic>{
              'labor': 3500,
              'materials': 3500,
              'logistics': 1000,
            },
            'duration_days': 5,
            'color_palette': <String>['#F3EDE7'],
            'materials': <Map<String, dynamic>>[],
          },
        ],
        'recommended_plan': 'Modern Mid-Range',
        'recommendation_reason':
            'This plan is suitable for the budget and room size.',
      },
      'generated_room_image': 'aGVsbG8=',
      'consistency_envelope': <String, dynamic>{
        'style_used': 'modern',
        'budget_tier': 'standard',
        'floor_area_m2': 15.75,
        'primary_flooring': 'Ceramic floor tiles',
        'primary_wall': 'Latex Paint',
        'sd_prompt_used': 'modern living room porcelain tile recessed LED',
        'gemini_total_cost': 14000,
        'vendor_adjusted_cost': 13500,
        'consistency_warnings': <String>[],
      },
    },
  };
}
