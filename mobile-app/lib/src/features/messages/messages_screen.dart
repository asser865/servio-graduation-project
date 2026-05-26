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
  bool _appInForeground = true;
  bool _tabActive = true;
  int _selectedTab = 0; // 0: Active, 1: Archived, 2: Support

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAutoRefresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messagesProvider ??= context.read<MessagesProvider>();
    final nextTabActive = ServioTabShell.isPageActiveOf(context);
    if (_tabActive == nextTabActive) return;
    _tabActive = nextTabActive;
    _syncAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      _syncAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appInForeground = false;
      _syncAutoRefresh();
    }
  }

  void _syncAutoRefresh() {
    final provider = _messagesProvider;
    if (provider == null) return;
    if (_appInForeground && _tabActive) {
      provider.startAutoRefresh();
    } else {
      provider.stopAutoRefresh();
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
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;
    final session = context.watch<SessionProvider>();
    final messagesProvider = context.watch<MessagesProvider>();
    final isTechnician = session.account?.role == UserRole.technician;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);
    final conversations = messagesProvider.conversations;

    // Split by archive flag first — use == true guard to be safe against
    // null values in hot-reload scenarios or legacy cached objects.
    final activeConversations =
        conversations.where((c) => c.isArchived != true).toList();
    final archivedConversations =
        conversations.where((c) => c.isArchived == true).toList();

    // Filter by search query within the active tab's list
    List<ApiConversation> filteredActive = _query.isEmpty
        ? activeConversations
        : activeConversations
            .where((c) =>
                c.contactName.toLowerCase().contains(_query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    List<ApiConversation> filteredArchived = _query.isEmpty
        ? archivedConversations
        : archivedConversations
            .where((c) =>
                c.contactName.toLowerCase().contains(_query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    // The list used by _buildBody for the current tab (Support tab has its own widget)
    final tabConversations = _selectedTab == 0 ? filteredActive : filteredArchived;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                ),
                onPressed: () => _openDashboard(isTechnician),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: servio.accent.withValues(alpha: 0.16),
                  child: Text(
                    session.account?.initials ?? 'U',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: servio.accent,
                    ),
                  ),
                ),
              ),
        title: Text(
          'SERVIO',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Title Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                16,
                ServioSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messages',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
                    ),
                  ),
                  // const SizedBox(height: 2),
                  // Text(
                  //   'Connect with your clients and team.',
                  //   style: TextStyle(
                  //     fontFamily: 'Inter',
                  //     fontSize: 14,
                  //     color: servio.textSecondary,
                  //   ),
                  //),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search input field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(
                    color: servio.textSecondary.withValues(alpha: 0.6),
                    fontFamily: 'Inter',
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF9A8C73),
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1D23) : const Color(0xFFF3EDE7).withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFF9A8C73).withValues(alpha: 0.1), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9A8C73), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab toggles (Active, Archived, Support)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding,
              ),
              child: Row(
                children: [
                  _buildTabButton(
                    label: 'Active (${filteredActive.length})',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                    servio: servio,
                    isDark: isDark,
                  ),
                  if (!isTechnician)
                    _buildTabButton(
                      label: 'Archived (${filteredArchived.length})',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                      servio: servio,
                      isDark: isDark,
                    ),
                  _buildTabButton(
                    label: 'Support',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                    servio: servio,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main messaging lists
            Expanded(
              child: AnimatedSwitcher(
                duration: ServioMotion.normal,
                child: _buildBody(tabConversations, bottomInset, messagesProvider, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ServioThemeExtension servio,
    required bool isDark,
  }) {
    final activeColor = isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            color: isSelected ? activeColor : servio.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    List<ApiConversation> conversations,
    double bottomInset,
    MessagesProvider messagesProvider,
    bool isDark,
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
      return _EmptyState(
        key: const ValueKey<String>('empty'),
        query: _query,
        tabIndex: _selectedTab,
      );
    }
    if (_selectedTab == 2) {
      return _EmptyState(
        key: const ValueKey<String>('support'),
        query: _query,
        tabIndex: _selectedTab,
      );
    }
    return RefreshIndicator(
      key: const ValueKey<String>('list'),
      onRefresh: () => messagesProvider.refresh(),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          ServioSpacing.screenPadding,
          4,
          ServioSpacing.screenPadding,
          16 + bottomInset,
        ),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final conversation = conversations[index];
          return _StaggeredEntry(
            index: index,
            child: _ConversationTile(
              conversation: conversation,
              isDark: isDark,
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

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.isDark,
  });

  final ApiConversation conversation;
  final VoidCallback onTap;
  final bool isDark;

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
    final isUnread = conversation.unreadCount > 0;

    // Premium styling parameters
    final cardBg = isUnread
        ? (widget.isDark ? const Color(0xFF262B34) : const Color(0xFFF3EDE7))
        : theme.cardColor;

    final border = isUnread
        ? Border.all(color: const Color(0xFF9A8C73).withValues(alpha: 0.15), width: 1)
        : Border.all(color: servio.border.withValues(alpha: 0.3), width: 1);

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontFamily: 'Poppins',
      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
      fontSize: 15,
      color: widget.isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23),
    );

    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'Inter',
      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
      fontSize: 13,
      color: isUnread
          ? (widget.isDark ? Colors.white : const Color(0xFF262B34))
          : servio.textSecondary,
    );

    final isSupport = conversation.contactName.toLowerCase().contains('support');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.curve,
        transform: Matrix4.identity()..scale(_pressed ? 0.985 : 1.0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: _pressed ? ServioShadows.restDark : ServioShadows.rest,
        ),
        child: Row(
          children: <Widget>[
            // Avatar Stack with Unread dot indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
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
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                if (isUnread)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFED7D0), // Soft pinkish-red
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cardBg,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Content section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conversation.contactName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                      if (isSupport) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Color(0xFF9A8C73),
                        ),
                      ] else ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: Color(0xFF9A8C73),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: messageStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Time and Count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _formatConversationTime(conversation.updatedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: servio.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: ServioMotion.normal,
                  child: isUnread
                      ? Container(
                          key: ValueKey<int>(conversation.unreadCount),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: servio.accent,
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox(width: 24, height: 16),
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
  const _EmptyState({
    required this.query,
    required this.tabIndex,
    super.key,
  });

  final String query;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final disabled = MediaQuery.disableAnimationsOf(context);

    IconData iconData = Icons.forum_outlined;
    String label = 'No messages yet';

    if (query.isNotEmpty) {
      iconData = Icons.search_off_rounded;
      label = 'No conversations found for "$query"';
    } else if (tabIndex == 1) {
      iconData = Icons.archive_outlined;
      label = 'No archived conversations';
    } else if (tabIndex == 2) {
      iconData = Icons.support_agent_rounded;
      label = 'No active support cases';
    }

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
              Icon(iconData, size: 56, color: servio.border),
              const SizedBox(height: 16),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: servio.textSecondary,
                ),
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
                style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry', style: TextStyle(fontFamily: 'Inter')),
              ),
            ],
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
