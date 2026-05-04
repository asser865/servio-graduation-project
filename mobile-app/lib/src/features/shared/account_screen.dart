import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                children: <Widget>[
                  _AccountTile(
                    label: 'Deactivate Account',
                    icon: Icons.pause_circle_outline_rounded,
                    description: 'Temporarily disable your account.',
                    onTap: () => _showDeactivateDialog(context),
                  ),
                  Divider(
                    height: 1,
                    color: servio.border.withValues(alpha: 0.5),
                  ),
                  _AccountTile(
                    label: 'Delete Account',
                    icon: Icons.delete_outline_rounded,
                    description: 'Permanently delete your account and all data.',
                    isDestructive: true,
                    onTap: () => _showDeleteDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deleting your account is permanent and cannot be undone. '
              'All bookings, reviews, and personal data will be removed.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Deactivate Account'),
        content: const Text(
          'Your account will be temporarily deactivated. '
          'You can reactivate it by logging in again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // TODO: call deactivate API when available
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final servio = ctx.servio;
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action is permanent and cannot be undone. '
            'All your data will be permanently deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: servio.danger),
              onPressed: () {
                Navigator.of(ctx).pop();
                // TODO: call delete account API when available
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.label,
    required this.icon,
    required this.description,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final String description;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = isDestructive ? servio.danger : null;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: color ?? servio.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color ?? servio.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
