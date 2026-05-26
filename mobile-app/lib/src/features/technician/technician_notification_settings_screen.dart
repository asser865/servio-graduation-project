import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/notifications_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class TechnicianNotificationSettingsScreen extends StatefulWidget {
  const TechnicianNotificationSettingsScreen({super.key});

  @override
  State<TechnicianNotificationSettingsScreen> createState() =>
      _TechnicianNotificationSettingsScreenState();
}

class _TechnicianNotificationSettingsScreenState
    extends State<TechnicianNotificationSettingsScreen> {
  bool _messages = true;
  bool _systemUpdates = false;
  bool _sound = true;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsProvider>().loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          final prefs = provider.preferences;
          return ListView(
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            children: <Widget>[
              Text('General', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  children: <Widget>[
                    _RedesignedSwitchRow(
                      label: 'Push Notifications',
                      subtitle: 'Immediate alerts on your device',
                      icon: Icons.notifications_active_outlined,
                      value: prefs.push,
                      onChanged: (v) =>
                          provider.updatePreferences(prefs.copyWith(push: v)),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: Divider(),
                    ),
                    _RedesignedSwitchRow(
                      label: 'Email Notifications',
                      subtitle: 'Daily summaries and receipts',
                      icon: Icons.mail_outline_rounded,
                      value: prefs.email,
                      onChanged: (v) =>
                          provider.updatePreferences(prefs.copyWith(email: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Activity', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  children: <Widget>[
                    _RedesignedSwitchRow(
                      label: 'New Job Requests',
                      subtitle: 'Alerts for new matching work requests',
                      icon: Icons.assignment_outlined,
                      value: prefs.inApp,
                      onChanged: (v) =>
                          provider.updatePreferences(prefs.copyWith(inApp: v)),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: Divider(),
                    ),
                    _RedesignedSwitchRow(
                      label: 'Messages',
                      subtitle: 'Direct messages from customers',
                      icon: Icons.chat_bubble_outline_rounded,
                      value: _messages,
                      onChanged: (v) => setState(() => _messages = v),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: Divider(),
                    ),
                    _RedesignedSwitchRow(
                      label: 'System Updates',
                      subtitle: 'Important platform notifications and updates',
                      icon: Icons.system_update_alt_rounded,
                      value: _systemUpdates,
                      onChanged: (v) => setState(() => _systemUpdates = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Device', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  children: <Widget>[
                    _RedesignedSwitchRow(
                      label: 'Sound',
                      icon: Icons.volume_up_rounded,
                      value: _sound,
                      onChanged: (v) => setState(() => _sound = v),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: Divider(),
                    ),
                    _RedesignedSwitchRow(
                      label: 'Vibration',
                      icon: Icons.vibration_rounded,
                      value: _vibration,
                      onChanged: (v) => setState(() => _vibration = v),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RedesignedSwitchRow extends StatelessWidget {
  const _RedesignedSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: servio.backgroundSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : ServioColors.navyDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: servio.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: servio.accent,
          ),
        ],
      ),
    );
  }
}

