import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/models/user_account.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/servio_tokens.dart';
import 'package:servio_mobile_app/src/features/technician/job_queue_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A minimal booking JSON that matches the real backend response shape.
Map<String, dynamic> _booking({
  String id = 'booking1',
  String status = 'accepted',
  String workerId = 'worker456',
  String serviceName = 'Plumbing',
  String customerName = 'Ahmed Hassan',
  String address = '12 Tahrir St, Cairo',
  double totalPrice = 350.0,
}) =>
    {
      '_id': id,
      'status': status,
      'scheduledDate': '2026-06-01T10:00:00.000Z',
      'totalPrice': totalPrice,
      'description': 'Fix leaking pipe',
      'worker': workerId,
      'service': {
        '_id': 'service789',
        'title': serviceName,
        'category': 'home',
        'basePrice': 300,
        'priceUnit': 'fixed',
      },
      'user': {
        '_id': 'customer111',
        'name': customerName,
        'phone': '01012345678',
      },
      'address': address,
    };

StorageService? _storage;

/// Wraps [child] in a [Provider<ApiClient>] and a [MaterialApp] that
/// includes the [ServioThemeExtension].
Widget _wrap(Widget child, {required ApiClient client}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider.load(_storage!, client),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          ServioThemeExtension(
            backgroundSoft: Color(0xFFF5F5F5),
            surfaceAlt: Color(0xFFEEEEEE),
            surfaceRaised: Color(0xFFFFFFFF),
            textSecondary: Color(0xFF888888),
            border: Color(0xFFDDDDDD),
            accent: ServioColors.accent,
            accentLight: ServioColors.accentLight,
            neutralWarm: ServioColors.neutralWarm,
            success: ServioColors.success,
            warning: ServioColors.warning,
            info: ServioColors.info,
            danger: ServioColors.danger,
          ),
        ],
      ),
      home: child,
    ),
  );
}

/// Builds an [ApiClient] with [mockHttp] and a real (mock-prefs) storage.
/// Call after [SharedPreferences.setMockInitialValues].
Future<ApiClient> _buildClient(
  http.Client mockHttp, {
  Duration? timeout = const Duration(seconds: 20),
}) async {
  final storage = await StorageService.init();
  _storage = storage;
  return ApiClient(
    storage: storage,
    httpClient: mockHttp,
    baseUrl: 'http://localhost',
    timeout: timeout,
  );
}

http.Client _mockClient(List<Map<String, dynamic>> bookings) => MockClient(
      (http.Request request) async {
        if (request.url.path.contains('/bookings/worker')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'data': {
                'bookings': bookings,
                'pagination': {'total': bookings.length, 'page': 1, 'pages': 1},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PATCH') {
          return http.Response(
            jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      },
    );

Future<void> _selectQueueTab(WidgetTester tester, String label) async {
  const historyTabs = <String>{'Completed', 'Cancelled', 'Rejected'};

  if (historyTabs.contains(label)) {
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'servio_session': jsonEncode(
        const UserAccount(
          id: 'worker456',
          name: 'Tech Worker',
          email: 'tech@example.com',
          phone: '01000000000',
          role: UserRole.technician,
        ).toJson(),
      ),
    });
    _storage = null;
  });

  testWidgets('shows loading indicator while fetching', (tester) async {
    // Use a Completer that never completes within the test to keep loading visible.
    // This avoids registering a real timer that would cause a "pending timer" error.
    final completer = Completer<http.Response>();
    final slowClient = MockClient((_) => completer.future);
    final client = await _buildClient(slowClient, timeout: null);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump(); // single frame — still loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('displays service name on job card after loading',
      (tester) async {
    final client = await _buildClient(
      _mockClient([_booking(status: 'accepted', serviceName: 'Plumbing')]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Plumbing'), findsOneWidget);
  });

  testWidgets('displays customer name on job card', (tester) async {
    final client = await _buildClient(
      _mockClient([_booking(status: 'accepted', customerName: 'Fatima Ali')]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fatima Ali'), findsOneWidget);
  });

  testWidgets('Confirmed tab shows only accepted-status jobs', (tester) async {
    final client = await _buildClient(
      _mockClient([
        _booking(id: 'b1', status: 'accepted', serviceName: 'Electrical'),
        _booking(id: 'b2', status: 'pending', serviceName: 'Painting'),
      ]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    await _selectQueueTab(tester, 'Confirmed');

    expect(find.text('Electrical'), findsOneWidget);
    expect(find.text('Painting'), findsNothing);
  });

  testWidgets('Pending tab shows only pending-status jobs', (tester) async {
    final client = await _buildClient(
      _mockClient([
        _booking(id: 'b1', status: 'pending', serviceName: 'Carpentry'),
        _booking(id: 'b2', status: 'accepted', serviceName: 'Electrical'),
      ]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    // Default tab is Pending (index 0)
    expect(find.text('Carpentry'), findsOneWidget);
    expect(find.text('Electrical'), findsNothing);
  });

  testWidgets('In Progress tab includes arrived jobs', (tester) async {
    final client = await _buildClient(
      _mockClient([
        _booking(id: 'b1', status: 'arrived', serviceName: 'Sink Repair'),
        _booking(id: 'b2', status: 'accepted', serviceName: 'Electrical'),
      ]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    await _selectQueueTab(tester, 'In Progress');

    expect(find.text('Sink Repair'), findsOneWidget);
    expect(find.text('Arrived'), findsOneWidget);
    expect(find.text('Electrical'), findsNothing);
  });

  testWidgets('Cancelled tab shows cancelled jobs as read-only history',
      (tester) async {
    final client = await _buildClient(
      _mockClient([
        _booking(
          id: 'cancelled-job',
          status: 'cancelled',
          serviceName: 'Old Paint Job',
        ),
        _booking(id: 'pending-job', status: 'pending', serviceName: 'Tiling'),
      ]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    await _selectQueueTab(tester, 'Cancelled');

    expect(find.text('Old Paint Job'), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(find.text('View Details'), findsOneWidget);
  });

  testWidgets('Rejected tab shows rejected jobs as read-only history',
      (tester) async {
    final client = await _buildClient(
      _mockClient([
        _booking(
          id: 'rejected-job',
          status: 'rejected',
          serviceName: 'Declined Plumbing',
        ),
        _booking(id: 'pending-job', status: 'pending', serviceName: 'Tiling'),
      ]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    await _selectQueueTab(tester, 'Rejected');

    expect(find.text('Declined Plumbing'), findsOneWidget);
    expect(find.text('Rejected'), findsWidgets);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(find.text('View Details'), findsOneWidget);
  });

  testWidgets('Decline sends backend-supported rejected status',
      (tester) async {
    var currentStatus = 'pending';
    String? patchedStatus;
    final httpClient = MockClient((request) async {
      if (request.url.path.contains('/bookings/worker')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'ok',
            'data': {
              'bookings': [
                _booking(
                  id: 'decline-me',
                  status: currentStatus,
                  serviceName: 'Decline Me',
                ),
              ],
              'pagination': {'total': 1, 'page': 1, 'pages': 1},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        patchedStatus = body['status'] as String?;
        currentStatus = patchedStatus ?? currentStatus;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });
    final client = await _buildClient(httpClient);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(patchedStatus, 'rejected');
    expect(find.text('Could not update job status. Please try again.'),
        findsNothing);

    expect(find.text('Decline Me'), findsOneWidget);
    expect(find.text('Rejected'), findsWidgets);
  });

  testWidgets('queue tabs account for all dashboard-counted jobs',
      (tester) async {
    final bookings = <Map<String, dynamic>>[
      _booking(id: 'b1', status: 'pending', serviceName: 'Pending 1'),
      _booking(id: 'b2', status: 'pending', serviceName: 'Pending 2'),
      _booking(id: 'b3', status: 'accepted', serviceName: 'Accepted 1'),
      _booking(id: 'b4', status: 'accepted', serviceName: 'Accepted 2'),
      _booking(id: 'b5', status: 'accepted', serviceName: 'Accepted 3'),
      _booking(id: 'b6', status: 'accepted', serviceName: 'Accepted 4'),
      _booking(id: 'b7', status: 'accepted', serviceName: 'Accepted 5'),
      _booking(id: 'b8', status: 'arrived', serviceName: 'Arrived Job'),
      _booking(id: 'b9', status: 'cancelled', serviceName: 'Cancelled Job'),
    ];
    final client = await _buildClient(_mockClient(bookings));

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Pending 1'), findsOneWidget);
    expect(find.text('Pending 2'), findsOneWidget);

    await _selectQueueTab(tester, 'Confirmed');
    expect(find.text('Accepted 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Accepted 5'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accepted 5'), findsOneWidget);

    await _selectQueueTab(tester, 'In Progress');
    expect(find.text('Arrived Job'), findsOneWidget);

    await _selectQueueTab(tester, 'Cancelled');
    expect(find.text('Cancelled Job'), findsOneWidget);
  });

  testWidgets('shows only bookings assigned to logged-in worker',
      (tester) async {
    final client = await _buildClient(
      _mockClient([
        _booking(id: 'mine', workerId: 'worker456', serviceName: 'Mine Job'),
        _booking(id: 'other', workerId: 'worker999', serviceName: 'Other Job'),
      ]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mine Job'), findsOneWidget);
    expect(find.text('Other Job'), findsNothing);
  });

  testWidgets('sends logged-in worker id in worker bookings query',
      (tester) async {
    Uri? capturedUri;
    final httpClient = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'ok',
          'data': {
            'bookings': [_booking(status: 'pending')],
            'pagination': {'total': 1, 'page': 1, 'pages': 1},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = await _buildClient(httpClient);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(capturedUri?.path, contains('/bookings/worker'));
    expect(capturedUri?.queryParameters['workerId'], equals('worker456'));
  });

  testWidgets('auto refresh shows newly requested pending jobs',
      (tester) async {
    var workerBookingsCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.contains('/bookings/worker')) {
        workerBookingsCalls += 1;
        final bookings = workerBookingsCalls == 1
            ? <Map<String, dynamic>>[]
            : <Map<String, dynamic>>[
                _booking(
                  id: 'new-request',
                  status: 'pending',
                  serviceName: 'Fresh Request',
                ),
              ];
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'ok',
            'data': {
              'bookings': bookings,
              'pagination': {
                'total': bookings.length,
                'page': 1,
                'pages': 1,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });
    final client = await _buildClient(httpClient);

    await tester.pumpWidget(
      _wrap(
        const JobQueueScreen(
          autoRefreshInterval: Duration(milliseconds: 25),
        ),
        client: client,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No jobs'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump();

    expect(find.text('Fresh Request'), findsOneWidget);
    expect(workerBookingsCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('shows empty state message when no jobs on current tab',
      (tester) async {
    final client = await _buildClient(_mockClient([]));

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('No jobs'), findsOneWidget);
  });

  testWidgets('shows error message and retry button on API failure',
      (tester) async {
    final errorClient =
        MockClient((_) async => http.Response('server error', 500));
    final client = await _buildClient(errorClient);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry button re-fetches and shows jobs on success',
      (tester) async {
    int callCount = 0;
    final flakyHttp = MockClient((_) async {
      callCount++;
      if (callCount == 1) return http.Response('server error', 500);
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'ok',
          'data': {
            'bookings': [_booking(status: 'pending', serviceName: 'Tiling')],
            'pagination': {'total': 1, 'page': 1, 'pages': 1},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = await _buildClient(flakyHttp);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Tiling'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
