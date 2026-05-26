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
  bool _archiving = false;
  bool _isArchived = false; // local mirror of backend flag
  bool _polling = false; // true during a background poll tick
  String? _error;

  Timer? _pollTimer;
  static const Duration _kPollInterval = Duration(seconds: 4);

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
        _isArchived = detail.conversation.isArchived;
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

  Future<void> _archiveChat({required bool archive}) async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty || _archiving) return;
    setState(() => _archiving = true);
    try {
      final api = MessagesApi(context.read<ApiClient>());
      await context
          .read<MessagesProvider>()
          .archiveConversation(api, conversationId, archive: archive);
      if (!mounted) return;
      setState(() => _isArchived = archive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archive ? 'Chat archived.' : 'Chat unarchived.'),
          action: archive
              ? SnackBarAction(
                  label: 'Undo',
                  onPressed: () => _archiveChat(archive: false),
                )
              : null,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError(archive ? 'Failed to archive chat.' : 'Failed to unarchive chat.');
    } finally {
      if (mounted) setState(() => _archiving = false);
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
    final isDark = theme.brightness == Brightness.dark;
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    final isCustomer =
        context.watch<SessionProvider>().account?.role == UserRole.customer;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D23) : const Color(0xFFF3EDE7).withValues(alpha: 0.95),
        elevation: 0,
        leadingWidth: 48,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: servio.accent.withValues(alpha: 0.16),
                  child: Text(
                    _contactName.trim().isEmpty ? '?' : _contactName.trim()[0].toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: servio.accent,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50), // Premium Green
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1A1D23) : const Color(0xFFF3EDE7),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                    ),
                  ),
                  Text(
                    _polling ? 'Lead Artisan • Updating...' : 'Lead Artisan • Online',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: servio.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.phone_outlined,
              color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
            ),
            onPressed: () {},
          ),
          if (isCustomer) ...[
            _ChatActionButton(
              canDelete: _conversationId != null && !_deleting,
              isDeleting: _deleting || _archiving,
              isArchived: _isArchived,
              onReport: _reportChat,
              onDelete: _confirmDeleteChat,
              onArchive: () => _archiveChat(archive: !_isArchived),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: _body(isDark),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                color: theme.scaffoldBackgroundColor,
                child: Row(
                  children: <Widget>[
                    // Attach File Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF9A8C73),
                          size: 24,
                        ),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_sending,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                          fontFamily: 'Inter',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: servio.textSecondary.withValues(alpha: 0.6),
                            fontFamily: 'Inter',
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: const Color(0xFF9A8C73).withValues(alpha: 0.15), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFF9A8C73), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Send Button
                    AnimatedContainer(
                      duration: ServioMotion.micro,
                      curve: ServioMotion.curve,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: canSend ? const Color(0xFF1A1D23) : servio.border.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        boxShadow: canSend ? ServioShadows.restDark : null,
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
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
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

  Widget _body(bool isDark) {
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

    final showContextCard = widget.bookingId != null || _conversationId != null;
    final totalItems = _messages.length + (showContextCard ? 1 : 0);

    return RefreshIndicator(
      key: const ValueKey<String>('messages'),
      onRefresh: _poll,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: totalItems,
        itemBuilder: (BuildContext context, int index) {
          if (showContextCard && index == 0) {
            return _ServiceContextCard(
              bookingId: widget.bookingId ?? _conversationId ?? 'SV-8924',
              contactName: _contactName,
            );
          }
          final msgIndex = showContextCard ? index - 1 : index;
          final message = _messages[msgIndex];
          final isMe = message.senderId == _currentUserId;
          return _MessageBubble(
            key: ValueKey<String>(message.id.isEmpty ? '$msgIndex' : message.id),
            message: message,
            isMe: isMe,
            index: msgIndex,
            contactName: _contactName,
          );
        },
      ),
    );
  }
}

class _ServiceContextCard extends StatelessWidget {
  const _ServiceContextCard({
    required this.bookingId,
    required this.contactName,
  });

  final String bookingId;
  final String contactName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;

    final shortId = bookingId.length > 8 ? bookingId.substring(bookingId.length - 8).toUpperCase() : bookingId.toUpperCase();
    final refText = 'Reference: #SV-$shortId';

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9A8C73).withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: ServioShadows.rest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: servio.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Custom Cabinetry Consultation',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            refText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: servio.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.canDelete,
    required this.isDeleting,
    required this.isArchived,
    required this.onReport,
    required this.onDelete,
    required this.onArchive,
  });

  final bool canDelete;
  final bool isDeleting;
  final bool isArchived;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<_ChatAction>(
      enabled: !isDeleting,
      tooltip: 'Chat actions',
      offset: const Offset(0, 44),
      icon: AnimatedSwitcher(
        duration: ServioMotion.micro,
        child: isDeleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Icon(
                Icons.more_vert_rounded,
                color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                size: 22,
              ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      onSelected: (action) {
        switch (action) {
          case _ChatAction.report:
            onReport();
            break;
          case _ChatAction.archive:
            onArchive();
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
          value: _ChatAction.archive,
          child: Row(
            children: <Widget>[
              Icon(
                isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(isArchived ? 'Unarchive chat' : 'Archive chat'),
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
    );
  }
}

enum _ChatAction { report, archive, delete }

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.index,
    required this.contactName,
    super.key,
  });

  final ApiMessage message;
  final bool isMe;
  final int index;
  final String contactName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;
    final disabled = MediaQuery.disableAnimationsOf(context);

    // Asymmetric styles
    final bubbleBg = isMe
        ? (isDark ? const Color(0xFF1A1D23) : const Color(0xFF1A1D23))
        : (isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7));

    final textColor = isMe
        ? Colors.white
        : (isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23));

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(!isMe ? 0 : 16),
      bottomRight: Radius.circular(!isMe ? 16 : 0),
    );

    final bubbleBorder = Border.all(
      color: isMe
          ? Colors.transparent
          : const Color(0xFF9A8C73).withValues(alpha: 0.15),
      width: 1,
    );

    final initial = contactName.trim().isEmpty ? '?' : contactName.trim()[0].toUpperCase();

    final bubble = Align(
      alignment: !isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: servio.accent.withValues(alpha: 0.16),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: servio.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    !isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: <Widget>[
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bubbleBg,
                      borderRadius: borderRadius,
                      border: bubbleBorder,
                      boxShadow: isMe ? ServioShadows.restDark : ServioShadows.rest,
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: servio.textSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Color(0xFF9A8C73),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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
