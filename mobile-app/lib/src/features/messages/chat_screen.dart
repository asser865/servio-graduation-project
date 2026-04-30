import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/messages_api.dart';
import '../../core/models/message_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.contactName,
    this.conversationId,
    this.bookingId,
    super.key,
  });

  final String contactName;
  final String? conversationId;
  final String? bookingId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ApiMessage> _apiMessages = <ApiMessage>[];
  String? _currentUserId;

  ConversationModel? get _conversation {
    final provider = context.read<MessagesProvider>();
    final id = widget.conversationId;
    if (id == null) return null;
    return provider.conversations.where((c) => c.id == id).firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentUserId = context.read<SessionProvider>().account?.id;
      _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    final id = widget.bookingId;
    if (id == null) return;
    try {
      final client = context.read<ApiClient>();
      final msgs = await MessagesApi(client).getMessages(id);
      if (!mounted) return;
      setState(() => _apiMessages = msgs);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final bId = widget.bookingId;
    if (bId != null) {
      try {
        final client = context.read<ApiClient>();
        await MessagesApi(client).sendMessage(bId, text);
        await _fetchMessages();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    } else {
      final id = widget.conversationId;
      if (id != null) {
        context.read<MessagesProvider>().sendMessage(id, text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    // Watch so the list rebuilds when new messages arrive.
    context.watch<MessagesProvider>();
    final messages = _conversation?.messages ?? <ChatMessage>[];
    final useApi = widget.bookingId != null && _apiMessages.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(ServioRadius.xl),
                boxShadow: ServioShadows.rest,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      shape: BoxShape.circle,
                      border: Border.all(color: servio.accent, width: 2),
                    ),
                    child: Center(child: Text(widget.contactName[0])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.contactName, style: theme.textTheme.labelLarge),
                        const SizedBox(height: 2),
                        Text(
                          'Online',
                          style: theme.textTheme.bodySmall?.copyWith(color: ServioColors.success),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline_rounded)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: useApi ? _apiMessages.length : messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final bool isMe;
                  final String text;
                  final String time;
                  if (useApi) {
                    final msg = _apiMessages[index];
                    isMe = msg.senderId == _currentUserId;
                    text = msg.text;
                    time = '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}';
                  } else {
                    final message = messages[index];
                    isMe = message.isMe;
                    text = message.text;
                    time = message.time;
                  }

                  return Align(
                    alignment: !isMe ? Alignment.centerLeft : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment:
                            !isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: !isMe ? null : ServioGradients.brand,
                              color: !isMe ? servio.surfaceRaised : null,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(ServioRadius.xl),
                                topRight: const Radius.circular(ServioRadius.xl),
                                bottomLeft: Radius.circular(!isMe ? 8 : ServioRadius.xl),
                                bottomRight: Radius.circular(!isMe ? ServioRadius.xl : 8),
                              ),
                            ),
                            child: Text(
                              text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: !isMe ? theme.colorScheme.onSurface : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
                            style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file_rounded)),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: servio.surfaceAlt,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                            borderSide: BorderSide(color: servio.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                            borderSide: BorderSide(color: servio.accent, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _sendMessage(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: ServioGradients.brand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

