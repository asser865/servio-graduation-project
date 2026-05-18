import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/messages_api.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../shared/report_problem_screen.dart';

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
  bool _deleting = false;
  bool _polling = false; // true during a background poll tick
  String? _error;

  Timer? _pollTimer;
  static const Duration _kPollInterval = Duration(seconds: 1);

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
    _stopPolling();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Polling ──────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Background poll — silently fetches new messages and merges them.
  /// Skipped while the user is actively sending to avoid race conditions.
  Future<void> _poll() async {
    if (!mounted || _conversationId == null || _sending) return;
    setState(() => _polling = true);
    try {
      final detail = await MessagesApi(context.read<ApiClient>())
          .getConversationMessages(_conversationId!);
      if (!mounted) return;

      // Only update when there are genuinely new messages to avoid
      // unnecessary rebuilds and jarring scroll jumps.
      final incoming = detail.messages;
      final existingIds = _messages.map((m) => m.id).toSet();
      final newMessages =
          incoming.where((m) => !existingIds.contains(m.id)).toList();

      if (newMessages.isNotEmpty) {
        setState(() {
          _messages = incoming;
          _error = null;
        });
        _scrollToBottom();
      }
    } catch (_) {
      // Silently swallow poll errors — the user still has their existing
      // messages and the next tick will retry automatically.
    } finally {
      if (mounted) setState(() => _polling = false);
    }
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
      // Start background polling once we have a valid conversation.
      _startPolling();
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
      context.read<MessagesProvider>().refresh(silent: true);
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

  Future<void> _reportChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReportProblemScreen(),
      ),
    );
  }

  Future<void> _confirmDeleteChat() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final servio = dialogContext.servio;
        return AlertDialog(
          title: const Text('Delete chat?'),
          content: const Text(
            'This removes the conversation and all messages from the database.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: servio.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _deleteChat(conversationId);
  }

  Future<void> _deleteChat(String conversationId) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await MessagesApi(context.read<ApiClient>()).deleteConversation(
        conversationId,
      );
      if (!mounted) return;
      _stopPolling();
      context.read<MessagesProvider>().refresh(silent: true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Chat deleted.')),
      );
      navigator.maybePop();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Failed to delete chat.');
    } finally {
      if (mounted) setState(() => _deleting = false);
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
    final isCustomer =
        context.watch<SessionProvider>().account?.role == UserRole.customer;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ChatHeader(
              contactName: _contactName,
              isLive: _polling,
              showActions: isCustomer,
              canDelete: _conversationId != null && !_deleting,
              isDeleting: _deleting,
              onReport: _reportChat,
              onDelete: _confirmDeleteChat,
            ),
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
      onRefresh: _poll,
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
  const _ChatHeader({
    required this.contactName,
    required this.showActions,
    required this.canDelete,
    required this.isDeleting,
    required this.onReport,
    required this.onDelete,
    this.isLive = false,
  });

  final String contactName;
  final bool showActions;
  final bool canDelete;
  final bool isDeleting;
  final bool isLive;
  final VoidCallback onReport;
  final VoidCallback onDelete;

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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isLive
                      ? Row(
                          key: const ValueKey<String>('live'),
                          children: <Widget>[
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: servio.accent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Updating...',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: servio.accent),
                            ),
                          ],
                        )
                      : Text(
                          key: const ValueKey<String>('idle'),
                          'Conversation history',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                ),
              ],
            ),
          ),
          if (showActions) ...<Widget>[
            const SizedBox(width: 8),
            _ChatActionButton(
              canDelete: canDelete,
              isDeleting: isDeleting,
              onReport: onReport,
              onDelete: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

enum _ChatAction { report, delete }

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.canDelete,
    required this.isDeleting,
    required this.onReport,
    required this.onDelete,
  });

  final bool canDelete;
  final bool isDeleting;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return PopupMenuButton<_ChatAction>(
      enabled: !isDeleting,
      tooltip: 'Chat actions',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      onSelected: (action) {
        switch (action) {
          case _ChatAction.report:
            onReport();
            break;
          case _ChatAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_ChatAction>>[
        const PopupMenuItem<_ChatAction>(
          value: _ChatAction.report,
          child: Row(
            children: <Widget>[
              Icon(Icons.flag_outlined, size: 20),
              SizedBox(width: 10),
              Text('Report chat'),
            ],
          ),
        ),
        PopupMenuItem<_ChatAction>(
          value: _ChatAction.delete,
          enabled: canDelete,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: canDelete ? servio.danger : servio.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                'Delete chat',
                style: TextStyle(
                  color: canDelete ? servio.danger : servio.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Semantics(
        button: true,
        label: 'Chat actions',
        child: Container(
          width: ServioSpacing.tapTarget,
          height: ServioSpacing.tapTarget,
          decoration: BoxDecoration(
            color: ServioColors.tint(servio.warning),
            shape: BoxShape.circle,
            border: Border.all(color: servio.warning.withValues(alpha: 0.28)),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: ServioMotion.micro,
            child: isDeleting
                ? SizedBox(
                    key: const ValueKey<String>('deleting'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: servio.warning,
                    ),
                  )
                : Icon(
                    key: const ValueKey<String>('actions'),
                    Icons.priority_high_rounded,
                    color: servio.warning,
                    size: 22,
                  ),
          ),
        ),
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
