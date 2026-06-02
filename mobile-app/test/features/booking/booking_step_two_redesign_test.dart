// mobile-app/test/features/booking/booking_step_two_redesign_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/users_api.dart';
import 'package:servio_mobile_app/src/core/api/payments_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/customer_addresses_state.dart';
import 'package:servio_mobile_app/src/core/state/payments_provider.dart';
import 'package:servio_mobile_app/src/core/models/user_account.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/booking/booking_flow_data.dart';
import 'package:servio_mobile_app/src/features/booking/booking_step_two_screen.dart';
import 'package:servio_mobile_app/src/features/booking/booking_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders 7 date bubbles for current week',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        await _wrap(const BookingStepTwoScreen(data: BookingFlowData())));
    await tester.pumpAndSettle();

    final List<DateTime> days = _buildDays(0);
    int totalBubbles = 0;
    for (final DateTime day in days) {
      final String dateStr = _dateKey(day);
      final bool isAvailable = find
          .byKey(ValueKey<String>('booking-date-$dateStr-available'))
          .evaluate()
          .isNotEmpty;
      final bool isUnavailable = find
          .byKey(ValueKey<String>('booking-date-$dateStr-unavailable'))
          .evaluate()
          .isNotEmpty;
      expect(isAvailable || isUnavailable, isTrue,
          reason: '${day.day}/${day.month} has no date bubble key');
      totalBubbles++;
    }
    expect(totalBubbles, equals(7));
  });

  testWidgets('shows Step 2 of 3 progress indicator',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        await _wrap(const BookingStepTwoScreen(data: BookingFlowData())));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });

  testWidgets('availability notice shown when technician has no slots',
      (WidgetTester tester) async {
    final BookingFlowData data = BookingFlowData(
      technicianId: 'worker1',
      technicianAvailability: const <AvailabilitySlot>[],
    );
    await tester.pumpWidget(
        await _wrap(BookingStepTwoScreen(data: data)));
    await tester.pumpAndSettle();

    expect(find.text(BookingStrings.technicianUnavailable), findsOneWidget);
  });

  testWidgets('time slot selection does not throw',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        await _wrap(const BookingStepTwoScreen(data: BookingFlowData())));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_slotLabel('09:00')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_slotLabel('09:00')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('continue button with no address prevents navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        await _wrap(const BookingStepTwoScreen(data: BookingFlowData()),
            httpClient: _emptyAddressClient()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(BookingStrings.continueLabel));
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Future<Widget> _wrap(
  Widget child, {
  http.Client? httpClient,
}) async {
  final StorageService storage = await StorageService.init();
  final ApiClient apiClient = ApiClient(
    storage: storage,
    httpClient: httpClient ?? _singleAddressClient(),
    baseUrl: 'http://localhost',
  );
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<CustomerAddressesProvider>(
        create: (_) => CustomerAddressesProvider(UsersApi(apiClient)),
      ),
      ChangeNotifierProvider<PaymentsProvider>(
        create: (_) => PaymentsProvider(PaymentsApi(apiClient)),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

http.Client _singleAddressClient() => MockClient((http.Request request) async {
      return http.Response(
        '{"success":true,"data":{"addresses":[{"_id":"home","label":"Home","street":"12 Nile St","city":"Cairo","state":"Maadi"}]}}',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

http.Client _emptyAddressClient() => MockClient((http.Request request) async {
      return http.Response(
        '{"success":true,"data":{"addresses":[]}}',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

List<DateTime> _buildDays(int weekOffset) {
  final DateTime base =
      DateTime.now().add(Duration(days: 1 + weekOffset * 7));
  final DateTime normalized = DateTime(base.year, base.month, base.day);
  return List<DateTime>.generate(
      7, (int i) => normalized.add(Duration(days: i)));
}

String _dateKey(DateTime value) {
  final String year = value.year.toString().padLeft(4, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _slotLabel(String value) {
  final int hour = int.tryParse(value.split(':').first) ?? 0;
  final int nextHour = hour + 1;
  return '${_hourLabel(hour)} - ${_hourLabel(nextHour)}';
}

String _hourLabel(int hour) {
  final int normalizedHour = hour % 24;
  final String suffix = normalizedHour >= 12 ? 'PM' : 'AM';
  final int displayHour = normalizedHour == 0
      ? 12
      : (normalizedHour > 12 ? normalizedHour - 12 : normalizedHour);
  return '$displayHour:00 $suffix';
}
