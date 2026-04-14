import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.contactName,
    super.key,
  });

  final String contactName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(text: 'Hello, I am on my way to the address now.', incoming: true, time: '10:08 AM'),
    const _ChatMessage(text: 'Perfect, I will be there in 15 minutes.', incoming: false, time: '10:09 AM'),
    const _ChatMessage(text: 'Please keep the booking reference ready.', incoming: true, time: '10:10 AM'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, incoming: false, time: 'Now'));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

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
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final message = _messages[index];

                  return Align(
                    alignment: message.incoming ? Alignment.centerLeft : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment:
                            message.incoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: message.incoming ? null : ServioGradients.brand,
                              color: message.incoming ? servio.surfaceRaised : null,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(ServioRadius.xl),
                                topRight: const Radius.circular(ServioRadius.xl),
                                bottomLeft: Radius.circular(message.incoming ? 8 : ServioRadius.xl),
                                bottomRight: Radius.circular(message.incoming ? ServioRadius.xl : 8),
                              ),
                            ),
                            child: Text(
                              message.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: message.incoming ? theme.colorScheme.onSurface : Colors.white,
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.incoming,
    required this.time,
  });

  final String text;
  final bool incoming;
  final String time;
}
