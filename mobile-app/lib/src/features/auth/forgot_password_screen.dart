import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_tokens.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    )..forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final errorMsg =
        await context.read<SessionProvider>().forgotPassword(email);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (errorMsg == null) {
        _sent = true;
      } else {
        _error = errorMsg;
      }
    });
  }

  void _showFormAgain() {
    setState(() {
      _sent = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth >= 700 ? 32.0 : 20.0;
                final maxWidth = constraints.maxWidth >= 700 ? 480.0 : 440.0;
                final minHeight = (constraints.maxHeight - 24)
                    .clamp(0.0, double.infinity)
                    .toDouble();

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: _Reveal(
                          controller: _entranceController,
                          child: AnimatedSwitcher(
                            duration: ServioMotion.micro,
                            switchInCurve: ServioMotion.curve,
                            switchOutCurve: ServioMotion.standard,
                            child: _sent
                                ? _SuccessState(
                                    email: _emailCtrl.text.trim(),
                                    onBackToLogin: () =>
                                        Navigator.of(context).pop(),
                                    onTryAnotherEmail: _showFormAgain,
                                  )
                                : _ForgotPasswordForm(
                                    emailCtrl: _emailCtrl,
                                    loading: _loading,
                                    error: _error,
                                    onSubmit: _loading ? null : _submit,
                                    onBackToLogin: () =>
                                        Navigator.of(context).pop(),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            PositionedDirectional(
              top: 12,
              start: 14,
              child: _BackButton(onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordForm extends StatelessWidget {
  const _ForgotPasswordForm({
    required this.emailCtrl,
    required this.loading,
    required this.onSubmit,
    required this.onBackToLogin,
    this.error,
  }) : super(key: const ValueKey<String>('forgot-password-form'));

  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback? onSubmit;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _HeaderIcon(icon: Icons.lock_reset_rounded),
        const SizedBox(height: 20),
        Text(
          'Reset Password',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: ServioColors.navyDark,
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.28,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email associated with your account and we will send instructions to reset your password.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                fontFamily: 'Inter',
                height: 1.45,
              ),
        ),
        const SizedBox(height: 32),
        _EmailField(
          controller: emailCtrl,
          onSubmitted: (_) => onSubmit?.call(),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 14),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 28),
        _PrimaryActionButton(
          label: 'Send Reset Link',
          loading: loading,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 12),
        _SecondaryActionButton(
          label: 'Back to Login',
          onPressed: onBackToLogin,
        ),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.email,
    required this.onBackToLogin,
    required this.onTryAnotherEmail,
  }) : super(key: const ValueKey<String>('forgot-password-success'));

  final String email;
  final VoidCallback onBackToLogin;
  final VoidCallback onTryAnotherEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _HeaderIcon(icon: Icons.mark_email_read_rounded, filled: true),
        const SizedBox(height: 24),
        Text(
          'Check your mail',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: ServioColors.navyDark,
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.28,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We have sent password recovery instructions to $email.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                fontFamily: 'Inter',
                height: 1.45,
              ),
        ),
        const SizedBox(height: 32),
        _PrimaryActionButton(
          label: 'Back to Login',
          onPressed: onBackToLogin,
        ),
        const SizedBox(height: 12),
        _SecondaryActionButton(
          label: 'Try another email address',
          onPressed: onTryAnotherEmail,
        ),
        const SizedBox(height: 28),
        Text(
          'Did not receive the email? Check your spam folder first.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ServioColors.textSecondaryLight,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    this.filled = false,
  });

  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: filled ? 96 : 64,
        height: filled ? 96 : 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EDE7),
          shape: BoxShape.circle,
          border: Border.all(
            color: ServioColors.accent.withValues(alpha: 0.20),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(26, 29, 35, 0.06),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: filled ? ServioColors.navyDark : ServioColors.accent,
          size: filled ? 48 : 42,
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Email Address',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ServioColors.navyDark,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            prefixIcon: const Icon(
              Icons.mail_outline_rounded,
              color: Color(0xFFC6C6CB),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: ServioColors.accent.withValues(alpha: 0.20),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ServioColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    return GestureDetector(
      onTap: enabled ? widget.onPressed : null,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ServioColors.navyDark,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(26, 29, 35, 0.10),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: ServioSpacing.tapTarget,
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(ServioSpacing.tapTarget),
        foregroundColor: ServioColors.navyDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        minimumSize:
            const Size(ServioSpacing.tapTarget, ServioSpacing.tapTarget),
        foregroundColor: ServioColors.navyDark,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ServioColors.tint(ServioColors.danger),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ServioColors.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 15,
              color: ServioColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ServioColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.child,
  });

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final animation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, 0.75, curve: ServioMotion.spring),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
