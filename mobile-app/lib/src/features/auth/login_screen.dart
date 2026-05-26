import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_tokens.dart';
import '../customer/customer_shell.dart';
import '../technician/technician_shell.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loading = false;
  String? _errorMsg;

  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = context.read<SessionProvider>().savedEmail;
      if (saved.isNotEmpty && mounted) {
        _emailCtrl.text = saved;
        setState(() => _rememberMe = true);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter your email and password.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorMsg = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMsg = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final error = await context.read<SessionProvider>().login(
          email,
          password,
          rememberEmail: _rememberMe,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    final account = context.read<SessionProvider>().account!;

    if (account.role == UserRole.technician && account.status == 'pending') {
      _showPendingDialog();
      return;
    }

    final Widget destination = account.role == UserRole.customer
        ? const CustomerShell()
        : const TechnicianShell();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (Route<dynamic> route) => false,
    );
  }

  void _showPendingDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Account Under Review'),
        content: const Text(
          'Your technician account is pending verification. '
          'Our team will review your documents and notify you within 24-48 hours.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _openCreateAccount() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EDE7),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth >= 700 ? 32.0 : 20.0;
                final topPadding = constraints.maxHeight < 720 ? 18.0 : 32.0;
                final minHeight = (constraints.maxHeight - topPadding - 24)
                    .clamp(0.0, double.infinity)
                    .toDouble();

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _Reveal(
                          controller: _entranceController,
                          intervalStart: 0,
                          child: _LoginCard(
                            emailCtrl: _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            passwordFocusNode: _passwordFocusNode,
                            obscurePassword: _obscurePassword,
                            rememberMe: _rememberMe,
                            loading: _loading,
                            errorMsg: _errorMsg,
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onRememberChanged: (value) =>
                                setState(() => _rememberMe = value),
                            onForgotPassword: _openForgotPassword,
                            onLogin: _loading ? null : _login,
                            onCreateAccount: _openCreateAccount,
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

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loading,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onForgotPassword,
    required this.onLogin,
    required this.onCreateAccount,
    this.errorMsg,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final String? errorMsg;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;
  final VoidCallback? onLogin;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final isTight = MediaQuery.sizeOf(context).height < 720;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 35, 0.08),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTight ? 22 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _LoginHeader(),
            SizedBox(height: isTight ? 24 : 32),
            if (errorMsg != null) ...<Widget>[
              _ErrorBanner(message: errorMsg!),
              const SizedBox(height: 18),
            ],
            _InputField(
              controller: emailCtrl,
              label: 'Email Address',
              hintText: 'name@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 18),
            _InputField(
              controller: passwordCtrl,
              focusNode: passwordFocusNode,
              label: 'Password',
              hintText: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onLogin?.call(),
              trailing: IconButton(
                tooltip:
                    obscurePassword ? 'Show password' : 'Hide password',
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: ServioColors.textSecondaryLight,
                  size: 21,
                ),
              ),
              labelTrailing: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: ServioColors.accent,
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 12),
            _RememberRow(
              value: rememberMe,
              onChanged: onRememberChanged,
            ),
            const SizedBox(height: 18),
            _LoginButton(
              loading: loading,
              onPressed: onLogin,
            ),
            const SizedBox(height: 24),
            const _DividerLabel(),
            const SizedBox(height: 20),
            const _SocialButtons(),
            const SizedBox(height: 28),
            _FooterLink(onCreateAccount: onCreateAccount),
          ],
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'SERVIO',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: ServioColors.navyDark,
                fontFamily: 'Poppins',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back. Enter your details to access your sanctuary.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                fontFamily: 'Inter',
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.trailing,
    this.labelTrailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? trailing;
  final Widget? labelTrailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: ServioColors.navyDark,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (labelTrailing != null) labelTrailing!,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: ServioColors.textSecondaryLight),
            suffixIcon: trailing,
            filled: true,
            fillColor: const Color(0xFFF5F3F0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: const Color(0xFFC6C6CB).withValues(alpha: 0.30),
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

class _RememberRow extends StatelessWidget {
  const _RememberRow({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AnimatedCheckbox(value: value, onChanged: onChanged),
            const SizedBox(width: 8),
            Text(
              'Remember me',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ServioColors.textSecondaryLight,
                    fontFamily: 'Inter',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCheckbox extends StatelessWidget {
  const _AnimatedCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? ServioColors.accent : Colors.transparent,
          border: Border.all(
            color: value ? ServioColors.accent : ServioColors.borderLight,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : null,
      ),
    );
  }
}

class _LoginButton extends StatefulWidget {
  const _LoginButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
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
        scale: _pressed ? 0.98 : 1,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ServioColors.navyDark,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(26, 29, 35, 0.15),
                blurRadius: 14,
                offset: Offset(0, 4),
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
                      'Login',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontFamily: 'Poppins',
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

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _line()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or continue with',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ServioColors.textSecondaryLight,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        Expanded(child: _line()),
      ],
    );
  }

  Widget _line() {
    return Container(
      height: 1,
      color: const Color(0xFFC6C6CB).withValues(alpha: 0.30),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SocialButton(
          label: 'Google',
          icon: Icons.g_mobiledata_rounded,
          backgroundColor: Colors.white,
          foregroundColor: ServioColors.navyDark,
          borderColor: const Color(0xFFEAE8E5),
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: 'Apple',
          icon: Icons.apple_rounded,
          backgroundColor: ServioColors.navyDark,
          foregroundColor: Colors.white,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(ServioSpacing.tapTarget),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor ?? backgroundColor, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          'New to SERVIO?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                fontFamily: 'Inter',
              ),
        ),
        TextButton(
          onPressed: onCreateAccount,
          child: const Text('Create account'),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        foregroundColor: ServioColors.navyDark,
        minimumSize: const Size(44, 44),
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
        borderRadius: BorderRadius.circular(12),
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
    required this.intervalStart,
    required this.child,
  });

  final AnimationController controller;
  final double intervalStart;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        intervalStart,
        (intervalStart + 0.55).clamp(0.0, 1.0).toDouble(),
        curve: ServioMotion.spring,
      ),
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
