import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/message_model.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.contactName,
    this.conversationId,
    super.key,
  });

  final String contactName;
  final String? conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  ConversationModel? get _conversation {
    final provider = context.read<MessagesProvider>();
    final id = widget.conversationId;
    if (id == null) return null;
    return provider.conversations.where((c) => c.id == id).firstOrNull;
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final id = widget.conversationId;
    if (id != null) {
      context.read<MessagesProvider>().sendMessage(id, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    // Watch so the list rebuilds when new messages arrive.
    context.watch<MessagesProvider>();
    final messages = _conversation?.messages ?? <ChatMessage>[];

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
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final message = messages[index];

                  return Align(
                    alignment: !message.isMe ? Alignment.centerLeft : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment:
                            !message.isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: !message.isMe ? null : ServioGradients.brand,
                              color: !message.isMe ? servio.surfaceRaised : null,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(ServioRadius.xl),
                                topRight: const Radius.circular(ServioRadius.xl),
                                bottomLeft: Radius.circular(!message.isMe ? 8 : ServioRadius.xl),
                                bottomRight: Radius.circular(!message.isMe ? ServioRadius.xl : 8),
                              ),
                            ),
                            child: Text(
                              message.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: !message.isMe ? theme.colorScheme.onSurface : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.time,
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
                      onTap: _sendMessage,
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

