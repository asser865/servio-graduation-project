import 'api_client.dart';
import 'api_config.dart';
import 'api_endpoints.dart';

class ApiParticipant {
  const ApiParticipant({
    required this.id,
    required this.name,
    required this.role,
    this.avatar,
  });

  final String id;
  final String name;
  final String role;
  final String? avatar;

  factory ApiParticipant.fromJson(Map<String, dynamic>? json) {
    return ApiParticipant(
      id: _string(json?['_id'] ?? json?['id']),
      name: _string(json?['name'], fallback: 'Unknown'),
      role: _string(json?['role']),
      avatar: _nullableUrl(json?['profileImage'] ?? json?['avatar']),
    );
  }
}

class ApiConversation {
  const ApiConversation({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
    this.bookingId,
    this.isArchived = false,
  });

  final String id;
  final ApiParticipant otherUser;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
  final String? bookingId;
  final bool isArchived;

  String get contactName => otherUser.name;
  String get contactInitials => _initials(otherUser.name);

  factory ApiConversation.fromJson(Map<String, dynamic> json) {
    final other = json['otherUser'] as Map<String, dynamic>?;
    final lastObj = json['lastMessage'];
    final lastMap = lastObj is Map<String, dynamic> ? lastObj : null;
    final lastStr = lastObj is String ? lastObj : null;

    // Safely coerce isArchived — backend may send bool, null, or other types.
    final rawArchived = json['isArchived'];
    final isArchived =
        rawArchived == true || rawArchived == 1 || rawArchived == '1';

    return ApiConversation(
      id: _string(json['conversationId'] ?? json['id'] ?? json['_id']),
      otherUser: ApiParticipant.fromJson(other),
      lastMessage: _string(
        json['lastMessageText'] ?? lastStr ?? lastMap?['content'] ?? lastMap?['text'],
        fallback: 'New conversation',
      ),
      updatedAt: _date(json['lastMessageAt'] ?? json['updatedAt']),
      unreadCount: ((json['unreadCount'] as num?) ?? 0).toInt(),
      bookingId: _nullableString(json['bookingId']),
      isArchived: isArchived,
    );
  }
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String conversationId;
  final String text;
  final String senderId;
  final String receiverId;
  final DateTime createdAt;
  final bool read;

  factory ApiMessage.fromJson(Map<String, dynamic> json) => ApiMessage(
        id: _string(json['_id'] ?? json['id']),
        conversationId: _string(json['conversationId'] ?? json['conversation']),
        text: _string(json['content'] ?? json['body'] ?? json['text']),
        senderId: _string(json['senderId'] ?? _idFrom(json['sender'])),
        receiverId: _string(
          json['receiverId'] ??
              json['recipientId'] ??
              _idFrom(json['receiver']) ??
              _idFrom(json['recipient']),
        ),
        createdAt: _date(json['createdAt']),
        read: (json['read'] as bool?) ?? false,
      );
}

class ApiConversationDetail {
  const ApiConversationDetail({
    required this.conversation,
    required this.messages,
  });

  final ApiConversation conversation;
  final List<ApiMessage> messages;
}

class ApiSendMessageResult {
  const ApiSendMessageResult({
    required this.conversation,
    required this.message,
  });

  final ApiConversation conversation;
  final ApiMessage message;
}

class MessagesApi {
  MessagesApi(this._client);

  final ApiClient _client;

  Future<List<ApiConversation>> getConversations() async {
    final data =
        _client.unwrapData(await _client.get(ApiEndpoints.conversations));
    final list = (data['conversations'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiConversation.fromJson)
        .toList();
  }

  Future<ApiConversation> startConversation({
    String? receiverId,
    String? workerId,
    String? customerId,
    String? bookingId,
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.startConversation, <String, dynamic>{
        if (_hasValue(receiverId)) 'receiverId': receiverId!.trim(),
        if (_hasValue(workerId)) 'workerId': workerId!.trim(),
        if (_hasValue(customerId)) 'customerId': customerId!.trim(),
        if (_hasValue(bookingId)) 'bookingId': bookingId!.trim(),
      }),
    );
    return ApiConversation.fromJson(
      (data['conversation'] as Map<String, dynamic>?) ?? data,
    );
  }

  Future<ApiConversationDetail> getConversationMessages(
    String conversationId,
  ) async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.messagesForConversation(conversationId)),
    );
    final conversation = ApiConversation.fromJson(
      (data['conversation'] as Map<String, dynamic>?) ??
          <String, dynamic>{'id': conversationId},
    );
    final list = (data['messages'] as List<dynamic>?) ?? <dynamic>[];
    return ApiConversationDetail(
      conversation: conversation,
      messages: list
          .whereType<Map<String, dynamic>>()
          .map(ApiMessage.fromJson)
          .toList(),
    );
  }

  Future<ApiConversationDetail> getBookingMessages(String bookingId) async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.messagesForBooking(bookingId)),
    );
    final conversation = ApiConversation.fromJson(
      (data['conversation'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    final list = (data['messages'] as List<dynamic>?) ?? <dynamic>[];
    return ApiConversationDetail(
      conversation: conversation,
      messages: list
          .whereType<Map<String, dynamic>>()
          .map(ApiMessage.fromJson)
          .toList(),
    );
  }

  Future<void> archiveConversation(String conversationId, {bool archive = true}) async {
    await _client.patch(
      ApiEndpoints.conversationArchive(conversationId),
      <String, dynamic>{'archive': archive},
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await _client.delete(ApiEndpoints.conversation(conversationId));
  }

  Future<ApiSendMessageResult> sendMessage({
    String? conversationId,
    String? receiverId,
    String? workerId,
    String? customerId,
    String? bookingId,
    required String content,
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.messages, <String, dynamic>{
        if (_hasValue(conversationId)) 'conversationId': conversationId!.trim(),
        if (_hasValue(receiverId)) 'receiverId': receiverId!.trim(),
        if (_hasValue(workerId)) 'workerId': workerId!.trim(),
        if (_hasValue(customerId)) 'customerId': customerId!.trim(),
        if (_hasValue(bookingId)) 'bookingId': bookingId!.trim(),
        'content': content,
      }),
    );
    return ApiSendMessageResult(
      conversation: ApiConversation.fromJson(
        (data['conversation'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      message: ApiMessage.fromJson(
        (data['message'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

String? _nullableString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

String? _nullableUrl(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return ApiConfig.normalizeBackendUrl(value);
  }
  return null;
}

String _string(dynamic value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

DateTime _date(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

dynamic _idFrom(dynamic value) {
  if (value is Map<String, dynamic>) return value['_id'] ?? value['id'];
  return value;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((part) => part[0]).join().toUpperCase();
}
