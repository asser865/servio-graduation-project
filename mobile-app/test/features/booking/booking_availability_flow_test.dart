import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/users_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/customer_addresses_state.dart';
import 'package:servio_mobile_app/src/core/models/user_account.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/booking/booking_flow_data.dart';
import 'package:servio_mobile_app/src/features/booking/booking_step_three_screen.dart';
import 'package:servio_mobile_app/src/features/booking/booking_step_two_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('date picker disables weekly day-off dates', (tester) async {
    final data = BookingFlowData(
      technicianId: 'worker1',
      technicianAvailability: const <AvailabilitySlot>[
        AvailabilitySlot(day: 'monday', from: '12:00', to: '17:00'),
        AvailabilitySlot(day: 'tuesday', from: '09:00', to: '17:00'),
      ],
    );

    await tester.pumpWidget(await _wrap(BookingStepTwoScreen(data: data)));
    await tester.pumpAndSettle();

    final days = _visibleBookingDays();
    final saturday = days.firstWhere((day) => day.weekday == DateTime.saturday);
    final sunday = days.firstWhere((day) => day.weekday == DateTime.sunday);
    final firstAvailable = days.firstWhere(
      (day) =>
          day.weekday == DateTime.monday || day.weekday == DateTime.tuesday,
    );
    final firstHour = firstAvailable.weekday == DateTime.monday ? 12 : 9;

    expect(
      find.byKey(ValueKey<String>(
        'booking-date-${_dateKey(saturday)}-unavailable',
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>(
        'booking-date-${_dateKey(sunday)}-unavailable',
      )),
      findsOneWidget,
    );
    expect(find.text(_slotLabel(firstHour)), findsOneWidget);

    await tester.tap(find.byKey(ValueKey<String>(
      'booking-date-${_dateKey(saturday)}-unavailable',
    )));
    await tester.pumpAndSettle();

    expect(find.text(_slotLabel(firstHour)), findsOneWidget);
    expect(find.text('Technician is not available on this day'), findsNothing);
  });

  testWidgets('date picker blocks booking when no weekdays are available',
      (tester) async {
    await tester.pumpWidget(await _wrap(const BookingStepTwoScreen(
      data: BookingFlowData(technicianId: 'worker1'),
    )));
    await tester.pumpAndSettle();

    expect(
        find.text('Technician is not available on this day'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review step blocks stale unavailable scheduled dates',
      (tester) async {
    final days = _visibleBookingDays();
    final unavailableDate =
        days.firstWhere((day) => day.weekday == DateTime.saturday);

    await tester.pumpWidget(await _wrap(BookingStepThreeScreen(
      data: BookingFlowData(
        technicianId: 'worker1',
        serviceId: 'service1',
        serviceName: 'Drain Cleaning',
        category: 'plumbing',
        scheduledDateTime: unavailableDate,
        date: DateTime(unavailableDate.year, unavailableDate.month,
                unavailableDate.day)
            .toIso8601String(),
        time: '10:00 AM - 11:00 AM',
        technicianAvailability: const <AvailabilitySlot>[
          AvailabilitySlot(day: 'monday', from: '12:00', to: '17:00'),
        ],
      ),
    )));
    await tester.pumpAndSettle();

    expect(
        find.text('Technician is not available on this day'), findsOneWidget);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Booking'));
    await tester.pumpAndSettle();

    expect(find.text('Booking Confirmed!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review step shows base price plus platform fee',
      (tester) async {
    await tester.pumpWidget(await _wrap(const BookingStepThreeScreen(
      data: BookingFlowData(
        serviceName: 'Custom Woodwork',
        technicianName: 'Youssef Tarek',
        specialty: 'Custom Woodwork',
        amount: '200 EGP',
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('200 EGP'), findsWidgets);
    expect(find.text('10 EGP (5%)'), findsOneWidget);
    expect(find.text('210 EGP'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<Widget> _wrap(Widget child) async {
  final storage = await StorageService.init();
  final apiClient = ApiClient(
    storage: storage,
    httpClient: MockClient((request) async {
      return http.Response(
        '{"success":true,"data":{"addresses":[{"_id":"addr1","label":"Home","street":"12 Nile St","city":"Cairo","state":"Maadi"}]}}',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
    baseUrl: 'http://localhost',
  );
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<CustomerAddressesProvider>(
        create: (_) => CustomerAddressesProvider(UsersApi(apiClient)),
      ),
    ],
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}

List<DateTime> _visibleBookingDays() {
  final firstDay = DateTime.now().add(const Duration(days: 1));
  final normalizedFirstDay =
      DateTime(firstDay.year, firstDay.month, firstDay.day);
  return List<DateTime>.generate(
    7,
    (index) => normalizedFirstDay.add(Duration(days: index)),
  );
}

String _dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _slotLabel(int hour) => '${_hourLabel(hour)} - ${_hourLabel(hour + 1)}';

String _hourLabel(int hour) {
  final normalizedHour = hour % 24;
  final suffix = normalizedHour >= 12 ? 'PM' : 'AM';
  final displayHour = normalizedHour == 0
      ? 12
      : (normalizedHour > 12 ? normalizedHour - 12 : normalizedHour);
  return '$displayHour:00 $suffix';
}
