import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/core/state/services_state.dart';
import 'package:servio_mobile_app/src/core/state/workers_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/customer/service_detail_screen.dart';
import 'package:servio_mobile_app/src/features/customer/technician_listing_screen.dart';
import 'package:servio_mobile_app/src/features/customer/technician_profile_screen.dart';

const String plumbingServiceId = '664000000000000000000001';
const String electricalServiceId = '664000000000000000000002';

Map<String, dynamic> _service({
  required String id,
  required String title,
  required String category,
}) =>
    <String, dynamic>{
      '_id': id,
      'title': title,
      'category': category,
      'description': '$title description',
      'basePrice': 200,
    };

Map<String, dynamic> _worker({
  required String id,
  required String name,
  required String category,
  required String serviceId,
  String serviceTitle = 'Service',
}) =>
    <String, dynamic>{
      '_id': id,
      'name': name,
      'profileImage': '',
      'categories': <String>[category],
      'services': <Map<String, dynamic>>[
        <String, dynamic>{
          '_id': serviceId,
          'title': serviceTitle,
          'category': category,
        },
      ],
      'skills': <String>[category],
      'averageRating': 4.8,
      'totalReviews': 12,
      'locationLabel': 'Cairo',
      'hourlyRate': 220,
      'isVerified': true,
      'isAvailable': true,
      'availability': <Map<String, dynamic>>[
        <String, dynamic>{
          'day': 'monday',
          'from': '09:00',
          'to': '17:00',
        },
      ],
    };

Future<Widget> _wrap(
  Widget child, {
  required http.Client httpClient,
}) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: httpClient,
    baseUrl: 'http://localhost',
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(storage),
      ),
      ChangeNotifierProvider<ServicesProvider>(
        create: (_) => ServicesProvider(client),
      ),
      ChangeNotifierProvider<WorkersProvider>(
        create: (_) => WorkersProvider(client),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

http.Response _json(Map<String, dynamic> body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'service detail find technician calls workers API with service filter',
      (tester) async {
    final requests = <Uri>[];
    final httpClient = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path == '/services') {
        expect(request.url.queryParameters['category'], 'plumbing');
        return _json(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'services': <Map<String, dynamic>>[
              _service(
                id: plumbingServiceId,
                title: 'Drain Cleaning',
                category: 'plumbing',
              ),
            ],
          },
        });
      }
      if (request.url.path == '/users/workers') {
        return _json(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'workers': <Map<String, dynamic>>[
              _worker(
                id: 'plumber1',
                name: 'Plumbing Test Worker',
                category: 'plumbing',
                serviceId: plumbingServiceId,
                serviceTitle: 'Drain Cleaning',
              ),
            ],
          },
        });
      }
      return _json(<String, dynamic>{'message': 'not found'}, 404);
    });

    await tester.pumpWidget(
      await _wrap(
        const ServiceDetailScreen(serviceId: 'plumbing'),
        httpClient: httpClient,
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.text('Find a Technician'));
    await _pumpFrames(tester);

    final workersRequest = requests.lastWhere(
      (uri) => uri.path == '/users/workers',
    );
    expect(workersRequest.queryParameters['serviceId'], plumbingServiceId);
    expect(workersRequest.queryParameters['category'], 'plumbing');
    expect(find.textContaining('Plumbing Test Worker'), findsWidgets);
  });

  testWidgets(
      'plumbing listing renders only plumbing workers from backend response',
      (tester) async {
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/users/workers');
      expect(request.url.queryParameters['category'], 'plumbing');
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'workers': <Map<String, dynamic>>[
            _worker(
              id: 'plumber1',
              name: 'Plumbing Test Worker',
              category: 'plumbing',
              serviceId: plumbingServiceId,
            ),
            _worker(
              id: 'electrician1',
              name: 'Electrical Test Worker',
              category: 'electrical',
              serviceId: electricalServiceId,
            ),
          ],
        },
      });
    });

    await tester.pumpWidget(
      await _wrap(
        const TechnicianListingScreen(category: 'plumbing'),
        httpClient: httpClient,
      ),
    );
    await _pumpFrames(tester);

    expect(find.textContaining('Plumbing Test Worker'), findsWidgets);
    expect(find.textContaining('Electrical Test Worker'), findsNothing);
  });

  testWidgets('electrical listing does not render plumbing-only worker',
      (tester) async {
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/users/workers');
      expect(request.url.queryParameters['category'], 'electrical');
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'workers': <Map<String, dynamic>>[
            _worker(
              id: 'plumber1',
              name: 'Plumbing Test Worker',
              category: 'plumbing',
              serviceId: plumbingServiceId,
            ),
          ],
        },
      });
    });

    await tester.pumpWidget(
      await _wrap(
        const TechnicianListingScreen(category: 'electrical'),
        httpClient: httpClient,
      ),
    );
    await _pumpFrames(tester);

    expect(find.textContaining('Plumbing Test Worker'), findsNothing);
    expect(find.text('No technicians found'), findsOneWidget);
  });

  testWidgets('technician profile fetches worker by backend id',
      (tester) async {
    final requests = <Uri>[];
    final httpClient = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path == '/users/workers/backend-worker-1') {
        return _json(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'worker': _worker(
              id: 'backend-worker-1',
              name: 'Backend Worker',
              category: 'plumbing',
              serviceId: plumbingServiceId,
            ),
          },
        });
      }
      if (request.url.path == '/reviews/worker/backend-worker-1') {
        return _json(<String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[],
        });
      }
      return _json(<String, dynamic>{'message': 'not found'}, 404);
    });

    await tester.pumpWidget(
      await _wrap(
        const TechnicianProfileScreen(technicianId: 'backend-worker-1'),
        httpClient: httpClient,
      ),
    );
    await _pumpFrames(tester);

    expect(
      requests.any((uri) => uri.path == '/users/workers/backend-worker-1'),
      isTrue,
    );
    expect(find.textContaining('Backend Worker'), findsWidgets);
  });

  testWidgets(
      'empty category result shows empty state without demo technicians',
      (tester) async {
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/users/workers');
      expect(request.url.queryParameters['category'], 'cleaning');
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'workers': <Map<String, dynamic>>[],
        },
      });
    });

    await tester.pumpWidget(
      await _wrap(
        const TechnicianListingScreen(category: 'cleaning'),
        httpClient: httpClient,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('No technicians found'), findsOneWidget);
    expect(find.textContaining('Karim'), findsNothing);
    expect(find.textContaining('Mona'), findsNothing);
  });
}
