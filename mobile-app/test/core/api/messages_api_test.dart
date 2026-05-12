import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/api/messages_api.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fetches conversations from backend', () async {
    final api = await _api((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/messages/conversations');
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'conversations': <Map<String, dynamic>>[_conversation()],
        },
      });
    });

    final conversations = await api.getConversations();

    expect(conversations, hasLength(1));
    expect(conversations.first.id, 'conv1');
    expect(conversations.first.contactName, 'Omar Tarek');
    expect(conversations.first.lastMessage, 'I am on my way');
    expect(conversations.first.unreadCount, 2);
  });

  test('fetches conversation message history', () async {
    final api = await _api((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/messages/conversations/conv1');
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'conversation': _conversation(),
          'messages': <Map<String, dynamic>>[
            _message(id: 'm1', senderId: 'user1', content: 'Hello'),
            _message(id: 'm2', senderId: 'worker1', content: 'Hi'),
          ],
        },
      });
    });

    final detail = await api.getConversationMessages('conv1');

    expect(detail.conversation.id, 'conv1');
    expect(detail.messages.map((m) => m.text), <String>['Hello', 'Hi']);
  });

  test('sending message posts conversation payload and parses saved message',
      () async {
    Map<String, dynamic>? payload;
    final api = await _api((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/messages');
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(
        <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'conversation': _conversation(lastMessageText: 'Saved'),
            'message': _message(content: 'Saved'),
          },
        },
        statusCode: 201,
      );
    });

    final result = await api.sendMessage(
      conversationId: 'conv1',
      content: 'Saved',
    );

    expect(payload, <String, dynamic>{
      'conversationId': 'conv1',
      'content': 'Saved',
    });
    expect(result.message.text, 'Saved');
    expect(result.conversation.lastMessage, 'Saved');
  });

  test('starts conversation by worker id', () async {
    Map<String, dynamic>? payload;
    final api = await _api((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/messages/conversations/start');
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'conversation': _conversation()},
      });
    });

    final conversation = await api.startConversation(workerId: 'worker1');

    expect(payload, <String, dynamic>{'workerId': 'worker1'});
    expect(conversation.id, 'conv1');
  });
}

Future<MessagesApi> _api(
  Future<http.Response> Function(http.Request request) handler,
) async {
  final storage = await StorageService.init();
  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((request) => handler(request)),
    baseUrl: 'http://localhost',
  );
  return MessagesApi(client);
}

Map<String, dynamic> _conversation(
    {String lastMessageText = 'I am on my way'}) {
  return <String, dynamic>{
    '_id': 'conv1',
    'conversationId': 'conv1',
    'otherUser': <String, dynamic>{
      '_id': 'worker1',
      'name': 'Omar Tarek',
      'role': 'worker',
    },
    'lastMessageText': lastMessageText,
    'lastMessageAt': '2026-05-11T10:05:00.000Z',
    'unreadCount': 2,
  };
}

Map<String, dynamic> _message({
  String id = 'm1',
  String senderId = 'user1',
  String content = 'Hello',
}) {
  return <String, dynamic>{
    '_id': id,
    'conversationId': 'conv1',
    'senderId': senderId,
    'receiverId': senderId == 'user1' ? 'worker1' : 'user1',
    'content': content,
    'createdAt': '2026-05-11T10:05:00.000Z',
  };
}

http.Response _json(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
