import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!mounted) return;
      final errorMsg =
          await context.read<SessionProvider>().forgotPassword(email);
      if (!mounted) return;
      if (errorMsg == null) {
        setState(() => _sent = true);
      } else {
        setState(() => _error = errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: _sent ? _buildSuccessView(context) : _buildFormView(theme),
        ),
      ),
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: ServioSpacing.sectionGap),
        Text(
          'Reset your password',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email address associated with your account and we\'ll send you a reset link.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: ServioColors.accent,
          ),
        ),
        const SizedBox(height: ServioSpacing.sectionGap),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: ServioColors.danger,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: ServioSpacing.sectionGap),
        ServioPrimaryButton(
          label: 'Send Reset Link',
          isLoading: _loading,
          onPressed: _loading ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: ServioSpacing.sectionGap),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 72,
          color: ServioColors.success,
        ),
        const SizedBox(height: ServioSpacing.sectionGap),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A password reset link has been sent to ${_emailCtrl.text.trim()}. Check your email and follow the instructions.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: ServioColors.accent,
          ),
        ),
        const SizedBox(height: ServioSpacing.sectionGap),
        ServioPrimaryButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
