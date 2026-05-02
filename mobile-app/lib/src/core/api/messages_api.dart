import 'api_client.dart';

class ApiConversation {
  const ApiConversation({
    required this.bookingId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
  });

  final String bookingId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  factory ApiConversation.fromJson(Map<String, dynamic> json) {
    final other = json['otherUser'] as Map<String, dynamic>?;
    return ApiConversation(
      bookingId: (json['bookingId'] as String?) ?? '',
      otherUserId: (other?['_id'] as String?) ?? '',
      otherUserName: (other?['name'] as String?) ?? 'Unknown',
      lastMessage: (json['lastMessage'] as String?) ?? '',
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
      unreadCount: ((json['unreadCount'] as num?) ?? 0).toInt(),
    );
  }
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String senderId;
  final DateTime createdAt;

  factory ApiMessage.fromJson(Map<String, dynamic> json) => ApiMessage(
        id: (json['_id'] as String?) ?? '',
        text: (json['content'] as String?) ?? '',
        senderId: (json['senderId'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );
}

class MessagesApi {
  MessagesApi(this._client);

  final ApiClient _client;

  Future<List<ApiConversation>> getConversations() async {
    final data = _client.unwrapData(await _client.get('/messages/conversations'));
    final list = (data['conversations'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(ApiConversation.fromJson).toList();
  }

  Future<List<ApiMessage>> getMessages(String bookingId) async {
    final data = _client.unwrapData(await _client.get('/messages/$bookingId'));
    final list = (data['messages'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(ApiMessage.fromJson).toList();
  }

  Future<void> sendMessage(String bookingId, String content) async {
    await _client.post('/messages', <String, dynamic>{
      'bookingId': bookingId,
      'content': content,
    });
  }
}
