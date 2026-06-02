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
import 'package:servio_mobile_app/src/features/messages/chat_screen.dart';

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

  Future<Widget> wrapChat(Widget child) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'servio_session': jsonEncode(testUser),
      'servio_account': jsonEncode(testUser),
    });

    final storage = await StorageService.init();
    final client = ApiClient(
      storage: storage,
      httpClient: MockClient((http.Request request) async {
        // Return standard getConversationMessages payload
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'conversation': <String, dynamic>{
                '_id': 'conv1',
                'otherUser': <String, dynamic>{
                  '_id': 'artisan123',
                  'name': 'Alex Rivera',
                  'avatarInitials': 'AR',
                  'role': 'technician',
                },
                'lastMessage': 'Counter-height stools. We actually bought them already',
                'unreadCount': 0,
                'updatedAt': '2026-05-26T10:45:00.000Z',
                'bookingId': 'booking_cabinetry'
              },
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  '_id': 'msg1',
                  'conversationId': 'conv1',
                  'content': 'Good morning! I\'m reviewing the dimensions you sent over...',
                  'senderId': 'artisan123',
                  'receiverId': 'user123',
                  'createdAt': '2026-05-26T09:45:00.000Z',
                  'read': true
                },
                <String, dynamic>{
                  '_id': 'msg2',
                  'conversationId': 'conv1',
                  'content': 'Hi Alex, sure thing. What do you need to know?',
                  'senderId': 'user123',
                  'receiverId': 'artisan123',
                  'createdAt': '2026-05-26T09:47:00.000Z',
                  'read': true
                }
              ]
            }
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
        Provider<ApiClient>.value(value: client),
      ],
      child: MaterialApp(
        theme: ServioTheme.light(),
        home: child,
      ),
    );
  }

  group('ChatScreen Redesign', () {
    testWidgets('renders v2 contextual headers, service cards, asymmetric bubbles, and input pill bar correctly', (tester) async {
      await tester.pumpWidget(await wrapChat(const ChatScreen(
        contactName: 'Alex Rivera',
        conversationId: 'conv1',
        bookingId: '8924',
      )));
      await tester.pumpAndSettle();

      // Check Custom Contextual AppBar Info
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('Lead Artisan • Online'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(6)); // Back, Phone, More, Handyman, Attach, Send

      // Check Bento-style Service Context Card
      expect(find.text('Custom Cabinetry Consultation'), findsOneWidget);
      expect(find.text('Reference: #SV-8924'), findsOneWidget);
      expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);

      // Check Asymmetrical Message Bubbles
      expect(find.text('Good morning! I\'m reviewing the dimensions you sent over...'), findsOneWidget);
      expect(find.text('Hi Alex, sure thing. What do you need to know?'), findsOneWidget);
      
      // Verified receiver message avatar exists on screen (appears in AppBar and bubble)
      expect(find.text('A'), findsNWidgets(2)); // Receiver initials in leading bubble avatar
      
      // Verified read tick marks exist for sender
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

      // Check bottom input bar components
      expect(find.byIcon(Icons.add_rounded), findsOneWidget); // Attach file button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      
      // Verify emoji button is NOT present
      expect(find.byIcon(Icons.mood), findsNothing);
      expect(find.byIcon(Icons.mood_rounded), findsNothing);
    });
  });
}
