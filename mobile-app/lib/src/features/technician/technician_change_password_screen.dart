import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class TechnicianChangePasswordScreen extends StatefulWidget {
  const TechnicianChangePasswordScreen({super.key});

  @override
  State<TechnicianChangePasswordScreen> createState() =>
      _TechnicianChangePasswordScreenState();
}

class _TechnicianChangePasswordScreenState
    extends State<TechnicianChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isValid() {
    return _currentCtrl.text.isNotEmpty &&
        _newCtrl.text.length >= 8 &&
        _newCtrl.text == _confirmCtrl.text;
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 16),
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Password must be at least 8 characters long.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ServioPrimaryButton(
              label: 'Update Password',
              onPressed: _isValid()
                  ? () {
                      Navigator.pop(context);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
