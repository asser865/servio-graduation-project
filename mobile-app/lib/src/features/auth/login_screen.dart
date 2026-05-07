import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_shell.dart';
import '../technician/technician_shell.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
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
      if (saved.isNotEmpty) {
        _emailCtrl.text = saved;
        setState(() => _rememberMe = true);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    if (!mounted) return;
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
          'Our team will review your documents and notify you within 24–48 hours.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : ServioColors.backgroundLight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: AuthBackground(fullBleed: true),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth >= 700 ? 32.0 : 20.0;
                final minContentHeight = constraints.maxHeight > 116
                    ? constraints.maxHeight - 116
                    : 0.0;

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 86),

                            // ── Brand icon mark ────────────────────────────
                            FadeTransition(
                              opacity: CurvedAnimation(
                                parent: _entranceController,
                                curve: const Interval(0.0, 0.45),
                              ),
                              child: Center(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Welcome heading ────────────────────────────
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _entranceController,
                                curve: const Interval(0.1, 0.6,
                                    curve: ServioMotion.spring),
                              )),
                              child: FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entranceController,
                                  curve: const Interval(0.1, 0.55),
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Text(
                                      'Welcome back',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.displayLarge
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sign in to continue.',
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Form card ──────────────────────────────────
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _entranceController,
                                curve: const Interval(0.25, 0.85,
                                    curve: ServioMotion.spring),
                              )),
                              child: FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entranceController,
                                  curve: const Interval(0.25, 0.75),
                                ),
                                child: AuthCard(
                                  frosted: true,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      // Section label
                                      Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.lock_outline_rounded,
                                            size: 13,
                                            color: servio.accent,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'YOUR CREDENTIALS',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: isDark
                                                  ? ServioColors.accentLight
                                                      .withValues(alpha: 0.65)
                                                  : ServioColors.accent,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Divider(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.10)
                                            : ServioColors.borderLight,
                                      ),
                                      const SizedBox(height: 18),

                                      // Error banner
                                      if (_errorMsg != null) ...<Widget>[
                                        _ErrorBanner(message: _errorMsg!),
                                        const SizedBox(height: 14),
                                      ],

                                      // Email field
                                      TextField(
                                        controller: _emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Email address',
                                          prefixIcon:
                                              Icon(Icons.mail_outline_rounded),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Password field
                                      TextField(
                                        controller: _passwordCtrl,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _login(),
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(
                                              Icons.lock_outline_rounded),
                                          suffixIcon: IconButton(
                                            onPressed: () => setState(() =>
                                                _obscurePassword =
                                                    !_obscurePassword),
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Remember me / Forgot password row
                                      Row(
                                        children: <Widget>[
                                          _AnimatedCheckbox(
                                            value: _rememberMe,
                                            accent: servio.accent,
                                            border: servio.border,
                                            onChanged: (v) =>
                                                setState(() => _rememberMe = v),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Remember me',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: servio.textSecondary,
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const ForgotPasswordScreen(),
                                              ),
                                            ),
                                            child:
                                                const Text('Forgot password?'),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // Primary CTA
                                      ServioPrimaryButton(
                                        label:
                                            _loading ? 'Signing in…' : 'Log In',
                                        isLoading: _loading,
                                        onPressed: _loading ? null : _login,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Social auth ────────────────────────────────
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : ServioColors.borderLight,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'or continue with',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: servio.textSecondary),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : ServioColors.borderLight,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    style: isDark
                                        ? OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Color(0x1CFFFFFF)),
                                            backgroundColor:
                                                const Color(0x0DFFFFFF),
                                            foregroundColor: Colors.white
                                                .withValues(alpha: 0.60),
                                          )
                                        : null,
                                    icon: const Icon(Icons.g_mobiledata_rounded,
                                        size: 22),
                                    label: const Text('Google'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    style: isDark
                                        ? OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Color(0x1CFFFFFF)),
                                            backgroundColor:
                                                const Color(0x0DFFFFFF),
                                            foregroundColor: Colors.white
                                                .withValues(alpha: 0.60),
                                          )
                                        : null,
                                    icon: const Icon(Icons.apple_rounded,
                                        size: 22),
                                    label: const Text('Apple'),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            Divider(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : ServioColors.borderLight,
                            ),

                            // ── Sign-up row ────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'New to SERVIO?',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.35)
                                        : ServioColors.textSecondaryLight,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const RoleSelectionScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Create account'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                18,
                ServioSpacing.screenPadding,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated custom checkbox — matches brand accent, exceeds 20px minimum
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedCheckbox extends StatelessWidget {
  const _AnimatedCheckbox({
    required this.value,
    required this.accent,
    required this.border,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final Color border;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value ? accent : Colors.transparent,
          border: Border.all(
            color: value ? accent : border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner — consistent styling across auth screens
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ServioColors.tint(ServioColors.danger),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: ServioColors.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded,
                size: 15, color: ServioColors.danger),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: servio.danger,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
