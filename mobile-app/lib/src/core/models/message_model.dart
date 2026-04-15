class ConversationModel {
  ConversationModel({
    required this.id,
    required this.contactName,
    required this.contactInitials,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.messages = const <ChatMessage>[],
  });

  final String id;
  final String contactName;
  final String contactInitials;
  String lastMessage;
  String time;
  int unreadCount;
  List<ChatMessage> messages;
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });

  final String text;
  final bool isMe;
  final String time;
}
