import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/messages_api.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.contactName,
    this.conversationId,
    this.bookingId,
    this.receiverId,
    this.workerId,
    this.customerId,
    super.key,
  });

  final String contactName;
  final String? conversationId;
  final String? bookingId;
  final String? receiverId;
  final String? workerId;
  final String? customerId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  String? _currentUserId;
  String _contactName = '';
  List<ApiMessage> _messages = <ApiMessage>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversationId = _blankToNull(widget.conversationId);
    _contactName = widget.contactName;
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentUserId = context.read<SessionProvider>().account?.id;
      _load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = MessagesApi(context.read<ApiClient>());
      ApiConversationDetail detail;
      if (_conversationId != null) {
        detail = await api.getConversationMessages(_conversationId!);
      } else if (_blankToNull(widget.bookingId) != null) {
        detail = await api.getBookingMessages(widget.bookingId!.trim());
      } else {
        final conversation = await api.startConversation(
          receiverId: widget.receiverId,
          workerId: widget.workerId,
          customerId: widget.customerId,
        );
        _conversationId = conversation.id;
        detail = await api.getConversationMessages(conversation.id);
      }
      if (!mounted) return;
      setState(() {
        _conversationId = detail.conversation.id;
        _contactName = detail.conversation.contactName == 'Unknown'
            ? widget.contactName
            : detail.conversation.contactName;
        _messages = detail.messages;
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load conversation.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await MessagesApi(context.read<ApiClient>()).sendMessage(
        conversationId: _conversationId,
        receiverId: widget.receiverId,
        workerId: widget.workerId,
        customerId: widget.customerId,
        bookingId: widget.bookingId,
        content: text,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _conversationId = result.conversation.id.isNotEmpty
            ? result.conversation.id
            : _conversationId;
        _messages = <ApiMessage>[..._messages, result.message];
        _error = null;
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Failed to send message.';
      setState(() => _error = message);
      _showError(message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: ServioMotion.normal,
        curve: ServioMotion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final canSend = _controller.text.trim().isNotEmpty && !_sending;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ChatHeader(contactName: _contactName),
            Expanded(
              child: AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: _body(),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                color: theme.colorScheme.surface,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: null,
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: servio.textSecondary.withValues(alpha: 0.45),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_sending,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: servio.surfaceAlt,
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                            borderSide: BorderSide(color: servio.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                            borderSide:
                                BorderSide(color: servio.accent, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: ServioMotion.micro,
                      curve: ServioMotion.curve,
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: canSend ? ServioGradients.brand : null,
                        color: canSend ? null : servio.border,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: canSend ? _sendMessage : null,
                        icon: AnimatedSwitcher(
                          duration: ServioMotion.micro,
                          child: _sending
                              ? const SizedBox(
                                  key: ValueKey<String>('sending'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  key: ValueKey<String>('send'),
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
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

  Widget _body() {
    if (_loading) {
      return const Center(
        key: ValueKey<String>('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null && _messages.isEmpty) {
      return _ErrorState(
        key: const ValueKey<String>('error'),
        message: _error!,
        onRetry: _load,
      );
    }
    if (_messages.isEmpty) {
      return const _EmptyThread(key: ValueKey<String>('empty'));
    }
    return RefreshIndicator(
      key: const ValueKey<String>('messages'),
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: _messages.length,
        itemBuilder: (BuildContext context, int index) {
          final message = _messages[index];
          final isMe = message.senderId == _currentUserId;
          return _MessageBubble(
            key: ValueKey<String>(message.id.isEmpty ? '$index' : message.id),
            message: message,
            isMe: isMe,
            index: index,
          );
        },
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.contactName});

  final String contactName;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final initial = contactName.trim().isEmpty ? '?' : contactName.trim()[0];

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: ServioGradients.warm,
              shape: BoxShape.circle,
              border: Border.all(color: servio.accent, width: 2),
            ),
            child: Center(child: Text(initial)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  contactName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Conversation history',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.index,
    super.key,
  });

  final ApiMessage message;
  final bool isMe;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final disabled = MediaQuery.disableAnimationsOf(context);

    final bubble = Align(
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
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: !isMe ? theme.colorScheme.onSurface : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      ),
    );

    if (disabled) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: ServioMotion.normal,
      curve: ServioMotion.curve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(isMe ? 18 * (1 - value) : -18 * (1 - value), 0),
          child: child,
        ),
      ),
      child: bubble,
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final disabled = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: disabled ? 1 : 0.92, end: 1),
        duration: disabled ? Duration.zero : ServioMotion.normal,
        curve: ServioMotion.spring,
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: value, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.chat_bubble_outline_rounded,
                size: 54, color: servio.border),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: AnimatedOpacity(
          opacity: 1,
          duration: ServioMotion.normal,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(ServioRadius.card),
              border: Border.all(color: servio.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline_rounded, color: servio.accent),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _blankToNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}
