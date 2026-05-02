import 'package:flutter/material.dart';

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
    body: 'Your invoice #INV-20240326 for electrical repair is ready to download.',
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
    _notifs = List<_Notif>.from(_kNotifications);
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

  int get _totalUnread => _notifs.where((n) => n.unread).length;

  void _markAll() {
    setState(() {
      for (final n in _notifs) {
        n.unread = false;
      }
    });
  }

  void _markOne(String id) {
    setState(() {
      final n = _notifs.firstWhere((n) => n.id == id);
      n.unread = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visible = _visible;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Gradient header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 110,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                // ── Header row ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ServioSpacing.screenPadding, 14, ServioSpacing.screenPadding, 14),
                  child: Row(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? ServioColors.navyDark : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Notifications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: isDark ? ServioColors.navyDark : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_totalUnread > 0) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Text(
                            '$_totalUnread',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? ServioColors.navyDark : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_totalUnread > 0)
                        GestureDetector(
                          onTap: _markAll,
                          child: Text(
                            'Mark all read',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: (isDark ? ServioColors.navyDark : Colors.white)
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Category bar ─────────────────────────────
                _CategoryBar(
                  selected: _category,
                  onChanged: (c) => setState(() => _category = c),
                  counts: <_NCategory, int>{
                    _NCategory.all: _notifs.where((n) => n.unread).length,
                    _NCategory.bookings: _notifs
                        .where((n) => n.type == _NType.booking && n.unread)
                        .length,
                    _NCategory.payments: _notifs
                        .where((n) => n.type == _NType.payment && n.unread)
                        .length,
                    _NCategory.system: _notifs
                        .where(
                          (n) =>
                              (n.type == _NType.system || n.type == _NType.ai) &&
                              n.unread,
                        )
                        .length,
                  },
                ),
                // ── List ─────────────────────────────────────
                Expanded(
                  child: visible.isEmpty
                      ? _EmptyState(category: _category)
                      : ListView.separated(
                          padding:
                              const EdgeInsets.all(ServioSpacing.screenPadding),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, int i) => _NotificationTile(
                            notif: visible[i],
                            onTap: () => _markOne(visible[i].id),
                          ),
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

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.selected,
    required this.onChanged,
    required this.counts,
  });

  final _NCategory selected;
  final ValueChanged<_NCategory> onChanged;
  final Map<_NCategory, int> counts;

  static const List<({_NCategory cat, String label})> _tabs =
      <({_NCategory cat, String label})>[
    (cat: _NCategory.all, label: 'All'),
    (cat: _NCategory.bookings, label: 'Bookings'),
    (cat: _NCategory.payments, label: 'Payments'),
    (cat: _NCategory.system, label: 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: servio.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding, vertical: 4),
        child: Row(
          children: _tabs.map((tab) {
            final active = tab.cat == selected;
            final unread = counts[tab.cat] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => onChanged(tab.cat),
                child: AnimatedContainer(
                  duration: ServioMotion.micro,
                  curve: ServioMotion.curve,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? servio.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        tab.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color:
                              active ? Colors.white : servio.textSecondary,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (unread > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white.withValues(alpha: 0.3)
                                : servio.accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$unread',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: active ? Colors.white : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
    final (Color color, IconData icon) = switch (notif.type) {
      _NType.booking => (servio.warning, Icons.calendar_month_outlined),
      _NType.payment => (servio.success, Icons.payments_outlined),
      _NType.ai => (servio.accent, Icons.auto_awesome_rounded),
      _NType.system => (servio.info, Icons.notifications_outlined),
    };

    return GestureDetector(
      onTap: onTap,
      child: ServioCard(
        backgroundColor: notif.unread
            ? servio.backgroundSoft
            : Theme.of(context).colorScheme.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(color),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (notif.unread)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: servio.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notif.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: notif.unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notif.time,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: ServioGradients.warm,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 52,
              color: servio.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(label, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            "You're all caught up.",
            style:
                theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}
