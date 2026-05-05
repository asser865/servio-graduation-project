import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/messages_api.dart';
import '../../core/models/message_model.dart';
import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../customer/customer_shell.dart';
import '../technician/technician_shell.dart';

import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<ApiConversation> _apiConversations = <ApiConversation>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchConversations());
  }

  Future<void> _fetchConversations() async {
    try {
      final client = context.read<ApiClient>();
      final convs = await MessagesApi(client).getConversations();
      if (!mounted) return;
      setState(() => _apiConversations = convs);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDashboard(bool isTechnician) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => isTechnician
            ? const TechnicianShell()
            : const CustomerShell(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final allConversations = context.watch<MessagesProvider>().conversations;
    final session = context.watch<SessionProvider>();
    final isTechnician = session.account?.role == UserRole.technician;

    // Filter by search query
    final conversations = _query.isEmpty
        ? allConversations
        : allConversations
            .where((c) =>
                c.contactName.toLowerCase().contains(_query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Workspace header ─────────────────────────────────────────────
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

            // ── Search field ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search conversations…',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Conversation count row ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Text(
                '${conversations.length} conversation${conversations.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: servio.textSecondary),
              ),
            ),
            const SizedBox(height: 10),

            // ── Conversation list ────────────────────────────────────────────
            Expanded(
              child: conversations.isEmpty
                  ? _EmptyState(query: _query)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ServioSpacing.screenPadding),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final conv = conversations[index];
                        return _ConversationTile(
                          conversation: conv,
                          onTap: () {
                            context.read<MessagesProvider>().markRead(conv.id);
                            final apiConv = _apiConversations
                                .where((a) => a.otherUserName == conv.contactName)
                                .firstOrNull;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  conversationId: conv.id,
                                  contactName: conv.contactName,
                                  bookingId: apiConv?.bookingId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── _ConversationTile ─────────────────────────────────────────────────────────

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: onDashboardTap,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: Text(
              isTechnician
                  ? 'Back to Technician Dashboard'
                  : 'Back to Dashboard',
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
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
              'End-to-end secured',
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.normal,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.all(ServioSpacing.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.card),
          border: Border.all(
            color: servio.border.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.45
                    : 1.0),
          ),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? ServioShadows.restDark
              : ServioShadows.rest,
        ),
        child: Row(
          children: <Widget>[
            // Avatar with online indicator
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.warm,
                    shape: BoxShape.circle,
                    border: Border.all(color: servio.accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      conversation.contactInitials,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ServioColors.deepBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ServioColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.surface, width: 2),
                    ),
                  ),
                ),
              ],
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
                  conversation.time,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: servio.textSecondary),
                ),
                const SizedBox(height: 8),
                if (conversation.unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: servio.accent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 24), // Keeps consistent alignment
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── _EmptyState ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 56,
              color: servio.border,
            ),
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
    );
  }
}
