import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

enum _NType { booking, payment, system, ai }

enum _NCategory { all, bookings, payments, system }

class _Notif {
  _Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.unread = false,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final _NType type;
  bool unread;

  _Notif copy() {
    return _Notif(
      id: id,
      title: title,
      body: body,
      time: time,
      type: type,
      unread: unread,
    );
  }
}

final List<_Notif> _kNotifications = <_Notif>[
  _Notif(
    id: 'n1',
    title: 'Booking Confirmed',
    body: 'Ahmed Nabil confirmed your plumbing visit for 10:00 AM tomorrow.',
    time: '5m ago',
    type: _NType.booking,
    unread: true,
  ),
  _Notif(
    id: 'n2',
    title: 'Technician En Route',
    body: 'Ahmed Nabil is on his way. Estimated arrival in 15 minutes.',
    time: '22m ago',
    type: _NType.booking,
    unread: true,
  ),
  _Notif(
    id: 'n3',
    title: 'Payment Released',
    body:
        'Your escrow payment of 850 EGP for the completed plumbing service has been released.',
    time: '1h ago',
    type: _NType.payment,
  ),
  _Notif(
    id: 'n4',
    title: 'AI Match Ready',
    body:
        'SERVIO AI found 3 high-confidence technician matches for your AC maintenance request.',
    time: '3h ago',
    type: _NType.ai,
    unread: true,
  ),
  _Notif(
    id: 'n5',
    title: 'Invoice Available',
    body:
        'Your invoice #INV-20240326 for electrical repair is ready to download.',
    time: '5h ago',
    type: _NType.payment,
  ),
  _Notif(
    id: 'n6',
    title: 'Booking Cancelled',
    body:
        'Booking #BK-00291 has been cancelled. A full refund will be processed within 3 business days.',
    time: 'Yesterday',
    type: _NType.booking,
  ),
  _Notif(
    id: 'n7',
    title: 'Leave a Review',
    body:
        'How was your experience with Nour Hany? Share your feedback to help other customers.',
    time: 'Yesterday',
    type: _NType.system,
  ),
  _Notif(
    id: 'n8',
    title: 'Welcome to SERVIO',
    body:
        'Your account is set up and ready. Browse verified professionals or let AI match you with the right technician.',
    time: '2d ago',
    type: _NType.system,
  ),
];

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final List<_Notif> _notifs;
  _NCategory _category = _NCategory.all;

  @override
  void initState() {
    super.initState();
    _notifs = _kNotifications.map((_Notif n) => n.copy()).toList();
  }

  List<_Notif> get _visible {
    return _notifs.where((_Notif n) {
      return switch (_category) {
        _NCategory.all => true,
        _NCategory.bookings => n.type == _NType.booking,
        _NCategory.payments => n.type == _NType.payment,
        _NCategory.system => n.type == _NType.system || n.type == _NType.ai,
      };
    }).toList();
  }

  int get _totalUnread => _notifs.where((_Notif n) => n.unread).length;

  int _countFor(_NCategory category, {bool unreadOnly = false}) {
    return _notifs.where((_Notif n) {
      final matches = switch (category) {
        _NCategory.all => true,
        _NCategory.bookings => n.type == _NType.booking,
        _NCategory.payments => n.type == _NType.payment,
        _NCategory.system => n.type == _NType.system || n.type == _NType.ai,
      };

      return matches && (!unreadOnly || n.unread);
    }).length;
  }

  void _markAll() {
    setState(() {
      for (final n in _notifs) {
        n.unread = false;
      }
    });
  }

  void _markOne(String id) {
    setState(() {
      final n = _notifs.firstWhere((_Notif n) => n.id == id);
      n.unread = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visible = _visible;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Stack(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth >= 700 ? 28.0 : 20.0;
                final maxContentWidth =
                    constraints.maxWidth >= 700 ? 760.0 : double.infinity;

                return CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _NotificationsHero(
                        totalCount: _notifs.length,
                        unreadCount: _totalUnread,
                        bookingCount: _countFor(_NCategory.bookings),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _CenteredContent(
                          horizontalPadding: horizontalPadding,
                          maxWidth: maxContentWidth,
                          child: _CategoryBar(
                            selected: _category,
                            onChanged: (c) => setState(() => _category = c),
                            unreadCounts: <_NCategory, int>{
                              for (final category in _NCategory.values)
                                category: _countFor(
                                  category,
                                  unreadOnly: true,
                                ),
                            },
                            totalCounts: <_NCategory, int>{
                              for (final category in _NCategory.values)
                                category: _countFor(category),
                            },
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CenteredContent(
                        horizontalPadding: horizontalPadding,
                        maxWidth: maxContentWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _InboxPulseCard(
                            unreadCount: _totalUnread,
                            visibleCount: visible.length,
                            selectedCategory: _category,
                          ),
                        ),
                      ),
                    ),
                    if (visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _CenteredContent(
                          horizontalPadding: horizontalPadding,
                          maxWidth: maxContentWidth,
                          child: _EmptyState(category: _category),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          34,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxWidth: maxContentWidth),
                              child: Column(
                                children: List<Widget>.generate(
                                  visible.length,
                                  (i) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            i == visible.length - 1 ? 0 : 12,
                                      ),
                                      child: _NotificationTile(
                                        notif: visible[i],
                                        onTap: () => _markOne(visible[i].id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            _PinnedNotificationActions(
              onBack: () => Navigator.of(context).pop(),
              onMarkAll: _totalUnread > 0 ? _markAll : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedNotificationActions extends StatelessWidget {
  const _PinnedNotificationActions({
    required this.onBack,
    required this.onMarkAll,
  });

  final VoidCallback onBack;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        10,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: servio.border.withValues(alpha: 0.45)),
        ),
        boxShadow: isDark ? ServioShadows.restDark : ServioShadows.rest,
      ),
      child: Row(
        children: <Widget>[
          _PinnedCircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const Spacer(),
          _PinnedActionChip(
            label: onMarkAll == null ? 'All caught up' : 'Mark all read',
            icon: onMarkAll == null
                ? Icons.check_circle_outline_rounded
                : Icons.done_all_rounded,
            onTap: onMarkAll,
          ),
        ],
      ),
    );
  }
}

class _PinnedCircleButton extends StatelessWidget {
  const _PinnedCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(color: servio.border.withValues(alpha: 0.72)),
          boxShadow: isDark ? ServioShadows.restDark : ServioShadows.rest,
        ),
        child: Icon(icon, color: theme.colorScheme.onSurface, size: 21),
      ),
    );
  }
}

class _PinnedActionChip extends StatelessWidget {
  const _PinnedActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: isEnabled ? ServioGradients.brand : null,
          color: isEnabled
              ? null
              : theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.18)
                : servio.border.withValues(alpha: 0.72),
          ),
          boxShadow: isDark ? ServioShadows.restDark : ServioShadows.rest,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: isEnabled ? Colors.white : servio.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isEnabled ? Colors.white : servio.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({
    required this.totalCount,
    required this.unreadCount,
    required this.bookingCount,
  });

  final int totalCount;
  final int unreadCount;
  final int bookingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? ServioColors.navyDark : Colors.white;
    final mutedText = textColor.withValues(alpha: 0.74);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 86,
              20,
              26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Notifications',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bookings, payments, and SERVIO updates collected in one clean inbox.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                _HeroMetricsGrid(
                  textColor: textColor,
                  metrics: <_HeroMetricData>[
                    _HeroMetricData(
                      icon: Icons.mark_email_unread_outlined,
                      value: '$unreadCount',
                      label: 'Unread',
                    ),
                    _HeroMetricData(
                      icon: Icons.notifications_active_outlined,
                      value: '$totalCount',
                      label: 'Total',
                    ),
                    _HeroMetricData(
                      icon: Icons.calendar_month_outlined,
                      value: '$bookingCount',
                      label: 'Bookings',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMetricData {
  const _HeroMetricData({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

class _HeroMetricsGrid extends StatelessWidget {
  const _HeroMetricsGrid({
    required this.metrics,
    required this.textColor,
  });

  final List<_HeroMetricData> metrics;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final columns = isWide ? 3 : 2;
        const gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List<Widget>.generate(metrics.length, (index) {
            final width = !isWide && index == metrics.length - 1
                ? constraints.maxWidth
                : itemWidth;

            return SizedBox(
              width: width,
              child: _HeroMetric(
                metric: metrics[index],
                textColor: textColor,
              ),
            );
          }),
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.metric,
    required this.textColor,
  });

  final _HeroMetricData metric;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: textColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: Icon(metric.icon, color: textColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metric.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredContent extends StatelessWidget {
  const _CenteredContent({
    required this.child,
    required this.horizontalPadding,
    required this.maxWidth,
  });

  final Widget child;
  final double horizontalPadding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.selected,
    required this.onChanged,
    required this.unreadCounts,
    required this.totalCounts,
  });

  final _NCategory selected;
  final ValueChanged<_NCategory> onChanged;
  final Map<_NCategory, int> unreadCounts;
  final Map<_NCategory, int> totalCounts;

  static const List<_NCategory> _tabs = <_NCategory>[
    _NCategory.all,
    _NCategory.bookings,
    _NCategory.payments,
    _NCategory.system,
  ];

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? servio.surfaceRaised : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: servio.border.withValues(alpha: 0.78)),
        boxShadow: isDark ? ServioShadows.restDark : ServioShadows.rest,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _tabs.map((category) {
            final active = category == selected;
            final unread = unreadCounts[category] ?? 0;
            final total = totalCounts[category] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _CategoryPill(
                active: active,
                label: _categoryLabel(category),
                icon: _categoryIcon(category),
                count: unread > 0 ? unread : total,
                showsUnread: unread > 0,
                onTap: () => onChanged(category),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.active,
    required this.label,
    required this.icon,
    required this.count,
    required this.showsUnread,
    required this.onTap,
  });

  final bool active;
  final String label;
  final IconData icon;
  final int count;
  final bool showsUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final foreground = active ? Colors.white : servio.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.spring,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          gradient: active ? ServioGradients.brand : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(ServioRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: foreground, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.18)
                    : (showsUnread ? servio.warning : servio.backgroundSoft),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active
                      ? Colors.white
                      : (showsUnread ? Colors.white : servio.textSecondary),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxPulseCard extends StatelessWidget {
  const _InboxPulseCard({
    required this.unreadCount,
    required this.visibleCount,
    required this.selectedCategory,
  });

  final int unreadCount;
  final int visibleCount;
  final _NCategory selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final hasUnread = unreadCount > 0;
    final accent = hasUnread ? servio.warning : servio.success;

    return ServioCard(
      padding: const EdgeInsets.all(16),
      borderColor: accent.withValues(alpha: 0.24),
      backgroundColor: Color.alphaBlend(
        accent.withValues(alpha: 0.06),
        theme.colorScheme.surface,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ServioColors.tint(accent),
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Icon(
              hasUnread
                  ? Icons.priority_high_rounded
                  : Icons.check_circle_outline_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hasUnread ? '$unreadCount unread updates' : 'Inbox is clear',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$visibleCount ${_categoryLabel(selectedCategory).toLowerCase()} updates visible right now.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _LiveBadge(color: accent),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Live',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notif, required this.onTap});

  final _Notif notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final style = _typeStyle(context, notif.type);
    final cardColor = Color.alphaBlend(
      style.color.withValues(alpha: notif.unread ? 0.075 : 0.0),
      theme.colorScheme.surface,
    );

    return ServioCard(
      onTap: onTap,
      elevated: notif.unread,
      borderColor:
          notif.unread ? style.color.withValues(alpha: 0.34) : servio.border,
      backgroundColor: cardColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TypeIcon(style: style, unread: notif.unread),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notif.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                              notif.unread ? FontWeight.w800 : FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (notif.unread) ...<Widget>[
                      const SizedBox(width: 8),
                      _NewBadge(color: style.color),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  notif.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MetaPill(
                      icon: style.icon,
                      label: style.label,
                      color: style.color,
                    ),
                    _MetaPill(
                      icon: Icons.schedule_rounded,
                      label: notif.time,
                      color: servio.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.style, required this.unread});

  final _NotificationStyle style;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ServioRadius.md),
            border: Border.all(color: style.color.withValues(alpha: 0.18)),
          ),
          child: Icon(style.icon, color: style.color, size: 22),
        ),
        if (unread)
          PositionedDirectional(
            top: -2,
            end: -2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: style.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        'New',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.category});

  final _NCategory category;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final label = switch (category) {
      _NCategory.all => 'No notifications yet',
      _NCategory.bookings => 'No booking notifications',
      _NCategory.payments => 'No payment notifications',
      _NCategory.system => 'No system notifications',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: ServioCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: ServioGradients.warm,
                  borderRadius: BorderRadius.circular(ServioRadius.xl),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 42,
                  color: servio.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You're all caught up.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: servio.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;
}

_NotificationStyle _typeStyle(BuildContext context, _NType type) {
  final servio = context.servio;

  return switch (type) {
    _NType.booking => _NotificationStyle(
        color: servio.warning,
        icon: Icons.calendar_month_outlined,
        label: 'Booking',
      ),
    _NType.payment => _NotificationStyle(
        color: servio.success,
        icon: Icons.payments_outlined,
        label: 'Payment',
      ),
    _NType.ai => _NotificationStyle(
        color: servio.accent,
        icon: Icons.auto_awesome_rounded,
        label: 'AI Match',
      ),
    _NType.system => _NotificationStyle(
        color: servio.info,
        icon: Icons.notifications_outlined,
        label: 'System',
      ),
  };
}

String _categoryLabel(_NCategory category) {
  return switch (category) {
    _NCategory.all => 'All',
    _NCategory.bookings => 'Bookings',
    _NCategory.payments => 'Payments',
    _NCategory.system => 'System',
  };
}

IconData _categoryIcon(_NCategory category) {
  return switch (category) {
    _NCategory.all => Icons.inbox_outlined,
    _NCategory.bookings => Icons.calendar_month_outlined,
    _NCategory.payments => Icons.payments_outlined,
    _NCategory.system => Icons.tune_rounded,
  };
}
