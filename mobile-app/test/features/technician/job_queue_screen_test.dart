import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
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
      'worker': 'worker456',
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

/// Wraps [child] in a [Provider<ApiClient>] and a [MaterialApp] that
/// includes the [ServioThemeExtension].
Widget _wrap(Widget child, {required ApiClient client}) {
  return Provider<ApiClient>(
    create: (_) => client,
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
Future<ApiClient> _buildClient(http.Client mockHttp) async {
  final storage = await StorageService.init();
  return ApiClient(
    storage: storage,
    httpClient: mockHttp,
    baseUrl: 'http://localhost',
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows loading indicator while fetching', (tester) async {
    // Use a Completer that never completes within the test to keep loading visible.
    // This avoids registering a real timer that would cause a "pending timer" error.
    final completer = Completer<http.Response>();
    final slowClient = MockClient((_) => completer.future);
    final client = await _buildClient(slowClient);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump(); // single frame — still loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('displays service name on job card after loading', (tester) async {
    final client = await _buildClient(
      _mockClient([_booking(status: 'accepted', serviceName: 'Plumbing')]),
    );

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    // Default tab is Pending (index 0). Switch to Confirmed to see accepted jobs.
    await tester.tap(find.text('Confirmed'));
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

    await tester.tap(find.text('Confirmed'));
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

    await tester.tap(find.text('Confirmed'));
    await tester.pumpAndSettle();

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

  testWidgets('shows empty state message when no jobs on current tab', (tester) async {
    final client = await _buildClient(_mockClient([]));

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('No jobs'), findsOneWidget);
  });

  testWidgets('shows error message and retry button on API failure', (tester) async {
    final errorClient = MockClient((_) async => http.Response('server error', 500));
    final client = await _buildClient(errorClient);

    await tester.pumpWidget(_wrap(const JobQueueScreen(), client: client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry button re-fetches and shows jobs on success', (tester) async {
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
