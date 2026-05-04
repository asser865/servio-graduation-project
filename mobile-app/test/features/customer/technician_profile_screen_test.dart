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
import 'package:servio_mobile_app/src/core/state/workers_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/customer/technician_profile_screen.dart';

Map<String, dynamic> _worker({
  String id = 'worker1',
  String name = 'Mona Adel',
  String bio = 'Licensed home maintenance specialist.',
  List<Map<String, dynamic>> services = const <Map<String, dynamic>>[
    <String, dynamic>{'_id': 'service1', 'title': 'Drain Cleaning'},
    <String, dynamic>{'_id': 'service2', 'title': 'AC Tune Up'},
  ],
  List<String> categories = const <String>[],
  double averageRating = 4.8,
  int totalReviews = 24,
  int hourlyRate = 450,
}) =>
    <String, dynamic>{
      '_id': id,
      'name': name,
      'email': 'mona@example.com',
      'bio': bio,
      'services': services,
      'categories': categories,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'hourlyRate': hourlyRate,
      'locationLabel': 'New Cairo',
      'yearsExperience': 7,
      'availabilityType': 'both',
      'isVerified': true,
    };

http.Client _mockClient(Map<String, Map<String, dynamic>> workers) =>
    MockClient(
      (http.Request request) async {
        final path = request.url.path;
        if (path.contains('/users/workers/')) {
          final id = path.split('/').last;
          final worker = workers[id];
          if (worker == null) return http.Response('not found', 404);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'ok',
              'data': <String, dynamic>{'worker': worker},
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (path.contains('/reviews/worker/')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'ok',
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  '_id': 'review1',
                  'rating': 5,
                  'comment': 'Clean work and fast response.',
                  'user': <String, dynamic>{'name': 'Ahmed Hassan'},
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      },
    );

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders complete technician data and service objects',
      (tester) async {
    await tester.pumpWidget(
      await _wrap(
        const TechnicianProfileScreen(technicianId: 'worker1'),
        httpClient: _mockClient(<String, Map<String, dynamic>>{
          'worker1': _worker(),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mona Adel'), findsWidgets);
    expect(find.textContaining('Drain Cleaning'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Licensed home maintenance specialist.'), findsOneWidget);
    expect(find.text('Drain Cleaning'), findsWidgets);
    expect(find.text('AC Tune Up'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Ahmed Hassan'), findsOneWidget);
    expect(find.text('Book technician'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders fallbacks for missing optional fields', (tester) async {
    await tester.pumpWidget(
      await _wrap(
        const TechnicianProfileScreen(technicianId: 'worker2'),
        httpClient: _mockClient(<String, Map<String, dynamic>>{
          'worker2': _worker(
            id: 'worker2',
            name: '',
            bio: '',
            services: const <Map<String, dynamic>>[],
            categories: const <String>[],
            averageRating: 0,
            totalReviews: 0,
            hourlyRate: 0,
          ),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Technician'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('No bio available.'), findsOneWidget);
    expect(find.text('No services listed.'), findsOneWidget);
    expect(find.text('Rating not available'), findsOneWidget);
    expect(find.text('Rate on request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows route-safe empty state when technician id is missing',
      (tester) async {
    await tester.pumpWidget(
      await _wrap(
        const TechnicianProfileScreen(),
        httpClient: _mockClient(<String, Map<String, dynamic>>{}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Technician profile not found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps many services readable on a small screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      await _wrap(
        const TechnicianProfileScreen(technicianId: 'worker3'),
        httpClient: _mockClient(<String, Map<String, dynamic>>{
          'worker3': _worker(
            id: 'worker3',
            services: const <Map<String, dynamic>>[
              <String, dynamic>{
                '_id': 's1',
                'title': 'Emergency Drain Cleaning'
              },
              <String, dynamic>{
                '_id': 's2',
                'title': 'Whole Home Electrical Inspection'
              },
              <String, dynamic>{
                '_id': 's3',
                'title': 'HVAC Preventive Maintenance'
              },
              <String, dynamic>{'_id': 's4', 'title': 'Kitchen Cabinet Repair'},
            ],
          ),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Emergency Drain Cleaning'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Drain Cleaning'), findsWidgets);
    expect(find.text('Whole Home Electrical Inspection'), findsWidgets);
    expect(find.text('Book technician'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking button stays tappable', (tester) async {
    await tester.pumpWidget(
      await _wrap(
        const TechnicianProfileScreen(technicianId: 'worker1'),
        httpClient: _mockClient(<String, Map<String, dynamic>>{
          'worker1': _worker(),
        }),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book technician'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Your Booking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
