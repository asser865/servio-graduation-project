import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/booking/booking_flow_data.dart';
import 'package:servio_mobile_app/src/features/customer/my_bookings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('details screen shows a back button on a root route',
      (tester) async {
    await tester.pumpWidget(
      await _wrap(
        const BookingDetailsScreen(
          data: BookingFlowData(technicianName: 'Youssef Tarek'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back to bookings'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('My Bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<Widget> _wrap(Widget child) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'bookings': <Map<String, dynamic>>[],
          },
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
    baseUrl: 'http://localhost',
  );

  return Provider<ApiClient>.value(
    value: client,
    child: MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    ),
  );
}
