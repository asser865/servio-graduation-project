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
                    _SwitchRow(
                      label: 'Push Notifications',
                      value: prefs.push,
                      onChanged: (v) =>
                          provider.updatePreferences(prefs.copyWith(push: v)),
                    ),
                    const SizedBox(height: 12),
                    _SwitchRow(
                      label: 'Email Notifications',
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
                    _SwitchRow(
                      label: 'New Job Requests',
                      value: prefs.inApp,
                      onChanged: (v) =>
                          provider.updatePreferences(prefs.copyWith(inApp: v)),
                    ),
                    const SizedBox(height: 12),
                    _SwitchRow(
                      label: 'Messages',
                      value: _messages,
                      onChanged: (v) => setState(() => _messages = v),
                    ),
                    const SizedBox(height: 12),
                    _SwitchRow(
                      label: 'System Updates',
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
                    _SwitchRow(
                      label: 'Sound',
                      value: _sound,
                      onChanged: (v) => setState(() => _sound = v),
                    ),
                    const SizedBox(height: 12),
                    _SwitchRow(
                      label: 'Vibration',
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: servio.accent,
        ),
      ],
    );
  }
}
