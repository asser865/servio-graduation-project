import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    )..forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animController.dispose();
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
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Gradient header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 180,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 20),
                  // App bar row
                  Row(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? ServioColors.navyDark : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Reset Password',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? ServioColors.navyDark : Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 48),
                  // Content
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animController,
                      curve: const Interval(0.2, 0.8,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animController,
                        curve: const Interval(0.2, 0.7),
                      ),
                      child: AnimatedSwitcher(
                        duration: ServioMotion.micro,
                        switchInCurve: ServioMotion.curve,
                        child: _sent
                            ? _buildSuccessView(context)
                            : _buildFormView(theme, servio, isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(
      ThemeData theme, ServioThemeExtension servio, bool isDark) {
    return Container(
      key: const ValueKey<String>('form'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(
          color: servio.border.withValues(alpha: isDark ? 0.45 : 1),
        ),
        boxShadow: isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.lg),
            ),
            child: Icon(Icons.lock_reset_rounded,
                color: servio.accent, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'Forgot your password?',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the email address associated with your account and we\'ll send you a reset link.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ServioColors.tint(ServioColors.danger),
                borderRadius: BorderRadius.circular(ServioRadius.md),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: ServioColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: ServioColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ServioPrimaryButton(
            label: 'Send Reset Link',
            isLoading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const ValueKey<String>('success'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(
          color: servio.border.withValues(alpha: isDark ? 0.45 : 1),
        ),
        boxShadow: isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ServioColors.tint(ServioColors.success),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 36,
              color: ServioColors.success,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Check your inbox',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'A password reset link has been sent to ${_emailCtrl.text.trim()}. Check your email and follow the instructions.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ServioPrimaryButton(
            label: 'Back to Login',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
