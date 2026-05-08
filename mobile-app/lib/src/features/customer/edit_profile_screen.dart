import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _nameCtrl = TextEditingController(text: account?.name ?? '');
    _emailCtrl = TextEditingController(text: account?.email ?? '');
    _phoneCtrl = TextEditingController(text: account?.phone ?? '');
    _bioCtrl = TextEditingController(text: account?.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = context.read<SessionProvider>();
    final account = session.account;

    final newEmail = _emailCtrl.text.trim().toLowerCase();
    final emailChanged = newEmail != (account?.email ?? '');

    if (emailChanged) {
      setState(() => _saving = false);
      await _handleEmailChange(newEmail);
      return;
    }

    final fields = <String, dynamic>{};
    if (_nameCtrl.text.trim() != (account?.name ?? '')) {
      fields['name'] = _nameCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim() != (account?.phone ?? '')) {
      fields['phone'] = _phoneCtrl.text.trim();
    }
    if (_bioCtrl.text.trim() != (account?.bio ?? '')) {
      fields['bio'] = _bioCtrl.text.trim();
    }
    if (fields.isEmpty) {
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      return;
    }
    final error = await session.updateProfile(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleEmailChange(String newEmail) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm Email Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('New email: $newEmail'),
              const SizedBox(height: 16),
              const Text('Enter your current password to confirm:'),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || confirmed != true) return;
    if (passwordCtrl.text.isEmpty) return;

    setState(() => _saving = true);
    final error = await context.read<SessionProvider>().updateEmail(
          newEmail: newEmail,
          currentPassword: passwordCtrl.text,
        );
    passwordCtrl.dispose();
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Email updated. Please log in again with your new email.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            Stack(
              children: <Widget>[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.warm,
                    shape: BoxShape.circle,
                    border: Border.all(color: servio.accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      account?.initials ?? 'U',
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(color: ServioColors.deepBrown),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: servio.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            ServioPrimaryButton(
              label: _saving ? 'Saving…' : 'Save Changes',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: servio.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
