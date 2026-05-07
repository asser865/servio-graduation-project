import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/servio_tokens.dart';
import 'package:servio_mobile_app/src/features/technician/availability_manager_screen.dart';

// Mock backend response seeded with a worker who has weekday availability
// and no blocked dates.
final _workerJson = jsonEncode(<String, Object?>{
  'success': true,
  'data': <String, Object?>{
    '_id': 'worker1',
    'name': 'Test Worker',
    'email': 'test@example.com',
    'phone': '01000000000',
    'role': 'worker',
    'isAvailable': false,
    'availability': <Object?>[
      <String, String>{'day': 'monday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'tuesday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'wednesday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'thursday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'friday', 'from': '09:00', 'to': '17:00'},
    ],
    'blockedDates': <String>[],
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Existing tests ────────────────────────────────────────────────────────

  testWidgets('shows one availability page title', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump();

    expect(find.text('Availability'), findsOneWidget);
  });

  testWidgets('shows day and working hours on one compact row', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump();

    final dayTop = tester.getTopLeft(find.text('Mon')).dy;
    final fromTop = tester.getTopLeft(find.text('From').first).dy;
    final untilTop = tester.getTopLeft(find.text('Until').first).dy;

    expect((fromTop - dayTop).abs(), lessThan(18));
    expect((untilTop - dayTop).abs(), lessThan(18));
  });

  // ── New Time Off tests ────────────────────────────────────────────────────

  testWidgets('Time off card appears below weekly schedule', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Card title + legend chip both contain "Time off" — verify at least one.
    expect(find.text('Time off'), findsAtLeastNWidgets(1));
  });

  testWidgets('Time off card shows current month label', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final expectedLabel = DateFormat('MMMM yyyy').format(DateTime.now());
    expect(find.text(expectedLabel), findsOneWidget);
  });

  testWidgets('Time off card shows empty-schedule notice when no availability',
      (tester) async {
    await tester.pumpWidget(
      await _wrap(const AvailabilityManagerScreen(), emptyAccount: true),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'Set your weekly schedule above before blocking specific dates.',
      ),
      findsOneWidget,
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<Widget> _wrap(
  Widget child, {
  bool emptyAccount = false,
}) async {
  final storage = await StorageService.init();
  final responseBody = emptyAccount ? _emptyJson : _workerJson;

  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((http.Request request) async {
      return http.Response(
        responseBody,
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
    baseUrl: 'http://localhost',
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider(storage, client),
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(storage),
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

final _emptyJson = jsonEncode(<String, Object?>{
  'success': true,
  'data': <String, Object?>{},
});
