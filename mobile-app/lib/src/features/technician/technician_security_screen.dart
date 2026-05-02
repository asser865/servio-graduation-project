import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import 'technician_change_password_screen.dart';

class TechnicianSecurityScreen extends StatelessWidget {
  const TechnicianSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: _SecurityGroup(
          children: <Widget>[
            _SecurityTile(
              label: 'Change Password',
              icon: Icons.lock_outline_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TechnicianChangePasswordScreen(),
                ),
              ),
            ),
            _SecurityTile(
              label: 'Two-Factor Authentication',
              icon: Icons.verified_user_outlined,
              onTap: () => _showPlaceholder(context, 'Two-Factor Authentication'),
            ),
            _SecurityTile(
              label: 'Enable SMS Authentication',
              icon: Icons.sms_outlined,
              onTap: () => _showPlaceholder(context, 'SMS Authentication'),
            ),
            _SecurityTile(
              label: 'Login Activity',
              icon: Icons.history_rounded,
              onTap: () => _showPlaceholder(context, 'Login Activity'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String feature) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(feature),
        content: Text('$feature is coming soon.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SecurityGroup extends StatelessWidget {
  const _SecurityGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                color: context.servio.border.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: servio.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Icon(Icons.chevron_right_rounded, color: servio.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
