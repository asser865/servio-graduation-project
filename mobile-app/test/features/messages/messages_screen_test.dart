import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/messages_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/messages/messages_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Map<String, dynamic> testUser = {
    'id': 'user123',
    'name': 'Alexander Sterling',
    'email': 'alexander.s@example.com',
    'phone': '+1 555 1234567',
    'role': 'customer',
    'avatarInitials': 'AS',
    'status': 'active',
  };

  Future<Widget> wrapMessages(Widget child) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'servio_session': jsonEncode(testUser),
      'servio_account': jsonEncode(testUser),
    });

    final storage = await StorageService.init();
    final client = ApiClient(
      storage: storage,
      httpClient: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                '_id': 'conv1',
                'otherUser': <String, dynamic>{
                  '_id': 'client1',
                  'name': 'Sarah Jenkins',
                  'avatarInitials': 'SJ',
                  'role': 'customer',
                },
                'lastMessage': 'The plumbing looks great, thank you!',
                'unreadCount': 1,
                'updatedAt': '2026-05-26T10:42:00.000Z',
              }
            ]
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
      baseUrl: 'http://localhost',
    );

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider.load(storage, client),
        ),
        ChangeNotifierProvider<MessagesProvider>(
          create: (_) => MessagesProvider(MessagesApi(client)),
        ),
      ],
      child: MaterialApp(
        theme: ServioTheme.light(),
        home: child,
      ),
    );
  }

  group('MessagesScreen Redesign', () {
    testWidgets('renders all visual elements correctly with unread conversation', (tester) async {
      await tester.pumpWidget(await wrapMessages(const MessagesScreen()));
      await tester.pumpAndSettle();

      // Standalone test environment triggers refresh manually due to no ServioTabShell
      final BuildContext context = tester.element(find.byType(MessagesScreen));
      await context.read<MessagesProvider>().refresh();
      await tester.pumpAndSettle();

      // Check Header SERVIO Title & User Initials
      expect(find.text('SERVIO'), findsOneWidget);
      expect(find.text('AS'), findsOneWidget); // User initials in AppBar
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Connect with your clients and team.'), findsOneWidget);

      // Check Search bar and Tab button toggles
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Archived (0)'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);

      // Check Conversation cards
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('The plumbing looks great, thank you!'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Unread count badge
    });
  });
}
