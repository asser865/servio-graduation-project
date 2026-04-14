import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: <Widget>[
          TextButton(onPressed: () {}, child: const Text('Mark all as read')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        children: const <Widget>[
          _NotificationTile(
            title: 'Technician accepted your booking',
            body: 'Ahmed Nabil confirmed the plumbing visit for 10:00 AM.',
            time: '5m ago',
            type: _NotificationType.warning,
            unread: true,
          ),
          SizedBox(height: 12),
          _NotificationTile(
            title: 'Payment released',
            body: 'Your escrow payment for the completed service was released.',
            time: '1h ago',
            type: _NotificationType.success,
          ),
          SizedBox(height: 12),
          _NotificationTile(
            title: 'AI recommendation ready',
            body: 'SERVIO AI found a high-confidence match for your request.',
            time: '3h ago',
            type: _NotificationType.ai,
            unread: true,
          ),
          SizedBox(height: 12),
          _NotificationTile(
            title: 'Booking update',
            body: 'Your technician is on the way to the service location.',
            time: 'Yesterday',
            type: _NotificationType.info,
          ),
          SizedBox(height: 12),
          _NotificationTile(
            title: 'Cancellation notice',
            body: 'A previously scheduled request was cancelled.',
            time: '2d ago',
            type: _NotificationType.danger,
          ),
        ],
      ),
    );
  }
}

enum _NotificationType { info, warning, success, danger, ai }

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.unread = false,
  });

  final String title;
  final String body;
  final String time;
  final _NotificationType type;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final palette = switch (type) {
      _NotificationType.info => (servio.info, Icons.calendar_today_outlined),
      _NotificationType.warning => (servio.warning, Icons.hourglass_top_rounded),
      _NotificationType.success => (servio.success, Icons.check_circle_outline_rounded),
      _NotificationType.danger => (servio.danger, Icons.error_outline_rounded),
      _NotificationType.ai => (servio.accent, Icons.auto_awesome_rounded),
    };

    return ServioCard(
      backgroundColor: unread ? servio.backgroundSoft : Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ServioColors.tint(palette.$1),
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
            child: Icon(palette.$2, color: palette.$1, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
          ),
        ],
      ),
    );
  }
}
