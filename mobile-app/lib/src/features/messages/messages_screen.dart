import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/messages_api.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../customer/customer_shell.dart';
import '../technician/technician_shell.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  MessagesProvider? _messagesProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messagesProvider?.startAutoRefresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messagesProvider ??= context.read<MessagesProvider>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _messagesProvider?.startAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _messagesProvider?.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesProvider?.stopAutoRefresh();
    _searchController.dispose();
    super.dispose();
  }

  void _openDashboard(bool isTechnician) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            isTechnician ? const TechnicianShell() : const CustomerShell(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final session = context.watch<SessionProvider>();
    final messagesProvider = context.watch<MessagesProvider>();
    final isTechnician = session.account?.role == UserRole.technician;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);
    final conversations = messagesProvider.conversations;
    final filtered = _query.isEmpty
        ? conversations
        : conversations
            .where((c) =>
                c.contactName.toLowerCase().contains(_query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                ServioSpacing.screenPadding,
                ServioSpacing.screenPadding,
                0,
              ),
              child: _WorkspaceHeader(
                isTechnician: isTechnician,
                onDashboardTap: () => _openDashboard(isTechnician),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding,
              ),
              child: Text(
                '${filtered.length} conversation${filtered.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: servio.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: _body(filtered, bottomInset, messagesProvider),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _body(
    List<ApiConversation> conversations,
    double bottomInset,
    MessagesProvider messagesProvider,
  ) {
    if (messagesProvider.loading && messagesProvider.conversations.isEmpty) {
      return const Center(
        key: ValueKey<String>('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (messagesProvider.error != null &&
        messagesProvider.conversations.isEmpty) {
      return _ErrorState(
        key: const ValueKey<String>('error'),
        message: messagesProvider.error!,
        onRetry: () => messagesProvider.refresh(),
      );
    }
    if (conversations.isEmpty) {
      return _EmptyState(key: const ValueKey<String>('empty'), query: _query);
    }
    return RefreshIndicator(
      key: const ValueKey<String>('list'),
      onRefresh: () => messagesProvider.refresh(),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          ServioSpacing.screenPadding,
          0,
          ServioSpacing.screenPadding,
          8 + bottomInset,
        ),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final conversation = conversations[index];
          return _StaggeredEntry(
            index: index,
            child: _ConversationTile(
              conversation: conversation,
              onTap: () async {
                final messagesProvider = context.read<MessagesProvider>();
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      conversationId: conversation.id,
                      contactName: conversation.contactName,
                    ),
                  ),
                );
                if (mounted) {
                  messagesProvider.refresh(silent: true);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.isTechnician,
    required this.onDashboardTap,
  });

  final bool isTechnician;
  final VoidCallback onDashboardTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _BackIconButton(onTap: onDashboardTap),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isTechnician ? 'MY CONVERSATIONS' : 'WORKSPACE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: servio.textSecondary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Messages',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _SecureBadge(),
      ],
    );
  }
}

class _BackIconButton extends StatelessWidget {
  const _BackIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Semantics(
      button: true,
      label: 'Back to dashboard',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: servio.border),
              boxShadow: ServioShadows.rest,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: servio.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.accent),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: servio.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, color: servio.accent, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Saved securely',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: servio.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ApiConversation conversation;
  final VoidCallback onTap;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final conversation = widget.conversation;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.curve,
        transform: Matrix4.identity()..scale(_pressed ? 0.985 : 1.0),
        padding: const EdgeInsets.all(ServioSpacing.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.card),
          border: Border.all(color: servio.border),
          boxShadow: _pressed ? ServioShadows.restDark : ServioShadows.rest,
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 25,
              backgroundColor: servio.accent.withValues(alpha: 0.16),
              foregroundImage: conversation.otherUser.avatar == null
                  ? null
                  : NetworkImage(conversation.otherUser.avatar!),
              onForegroundImageError:
                  conversation.otherUser.avatar == null ? null : (_, __) {},
              child: Text(
                conversation.contactInitials,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: servio.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    conversation.contactName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _formatConversationTime(conversation.updatedAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: servio.textSecondary),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: ServioMotion.normal,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: conversation.unreadCount > 0
                      ? Container(
                          key: ValueKey<int>(conversation.unreadCount),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: servio.accent,
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey<String>('none'), width: 24),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled) return child;
    final delayMs = (index * 60).clamp(0, 360).toInt();
    final delay = Duration(milliseconds: delayMs);
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(index),
      tween: Tween<double>(begin: 0, end: 1),
      duration: ServioMotion.normal + delay,
      curve: ServioMotion.curve,
      builder: (context, value, child) {
        final delayed = delay.inMilliseconds == 0
            ? value
            : ((value * (ServioMotion.normal + delay).inMilliseconds -
                        delay.inMilliseconds) /
                    ServioMotion.normal.inMilliseconds)
                .clamp(0.0, 1.0);
        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - delayed)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final disabled = MediaQuery.disableAnimationsOf(context);
    final icon = Icon(
      query.isNotEmpty ? Icons.search_off_rounded : Icons.forum_outlined,
      size: 56,
      color: servio.border,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
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
              icon,
              const SizedBox(height: 16),
              Text(
                query.isNotEmpty
                    ? 'No conversations found for "$query"'
                    : 'No messages yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: servio.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation<double>(1),
        child: Padding(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
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
                Icon(Icons.wifi_off_rounded, color: servio.accent),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
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

String _formatConversationTime(DateTime date) {
  final now = DateTime.now();
  final sameDay =
      now.year == date.year && now.month == date.month && now.day == date.day;
  if (sameDay) return DateFormat('HH:mm').format(date);
  if (now.difference(date).inDays < 7) return DateFormat('EEE').format(date);
  return DateFormat('MMM d').format(date);
}
