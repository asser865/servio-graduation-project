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
      // Use latin1 to avoid UTF-8 decoding errors on raw image bytes
      // embedded inside the multipart envelope.
      capturedBody = String.fromCharCodes(request.bodyBytes);
      capturedContentType = request.headers['content-type'];
      return _json(_successPayload());
    });

    final res = await api.analyzeRoom(
      imageBytes: const <int>[0x69, 0x6D, 0x67], // ASCII "img"
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

    // Multipart body is raw — assert string fragments instead of parsing.
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

    // Breakdown built from materials_subtotal_egp / labor_subtotal_egp
    expect(recommended.breakdown['materials'], 6500);
    expect(recommended.breakdown['labor'], 6000);

    // Materials
    expect(recommended.materials, hasLength(2));
    expect(recommended.materials.first.name, 'Ceramic floor tiles');

    // Labor
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
          'current_condition': 'bare concrete walls',
          'detected_features': <String>['window', 'door'],
          'style': 'modern',
        },
        'finishing_plans': <Map<String, dynamic>>[
          <String, dynamic>{
            'plan_name': 'Modern Mid-Range',
            'description': 'Balanced finish',
            'total_cost_egp': 14000,
            'materials_subtotal_egp': 6500,
            'labor_subtotal_egp': 6000,
            'timeline_days': 7,
            'color_palette': <String>['#FAF8F5', '#9A8C73'],
            'materials': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Ceramic floor tiles',
                'quantity': '16',
                'unit': 'm²',
                'estimated_cost_egp': 3200,
              },
              <String, dynamic>{
                'name': 'Latex wall paint',
                'quantity': '20',
                'unit': 'L',
                'estimated_cost_egp': 1800,
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
      },
      'generated_room_image': 'aGVsbG8=',
    },
  };
}
