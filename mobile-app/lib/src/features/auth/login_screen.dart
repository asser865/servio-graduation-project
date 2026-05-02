import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_home_screen.dart';
import '../technician/technician_dashboard_screen.dart';
import 'auth_role.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.role,
    super.key,
  });

  final AuthRole role;

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

    // Pre-fill remembered email
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

    // Pending technician block
    if (account.role == UserRole.technician && account.status == 'pending') {
      _showPendingDialog();
      return;
    }

    final Widget destination = account.role == UserRole.customer
        ? const CustomerHomeScreen()
        : const TechnicianDashboardScreen();

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
      body: Stack(
        children: <Widget>[
          // ── Gradient Header ──────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
              ),
            ),
          ),
          // ── Content ──────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 28),
                  // Back button + brand
                  Row(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(ServioRadius.full),
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
                        'SERVIO',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: isDark ? ServioColors.navyDark : Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Title
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.0, 0.6, curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.0, 0.5),
                      ),
                      child: Text(
                        'Welcome\nback',
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: isDark ? ServioColors.navyDark : Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your ${widget.role == AuthRole.customer ? 'customer' : 'technician'} account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: (isDark ? ServioColors.navyDark : Colors.white).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Form Card ──────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.2, 0.8, curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.2, 0.7),
                      ),
                      child: Container(
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
                            // Error message
                            if (_errorMsg != null) ...<Widget>[
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
                                        _errorMsg!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: ServioColors.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Email
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Password
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Remember / Forgot
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) =>
                                            setState(() => _rememberMe = v ?? false),
                                        activeColor: servio.accent,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember me',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: servio.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ForgotPasswordScreen(),
                                    ),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Login button
                            ServioPrimaryButton(
                              label: _loading ? 'Signing in…' : 'Log In',
                              isLoading: _loading,
                              onPressed: _loading ? null : _login,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // ── Social auth ────────────────────────────
                  Row(
                    children: <Widget>[
                      Expanded(child: Divider(color: servio.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      ),
                      Expanded(child: Divider(color: servio.border)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                          label: const Text('Google'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.apple_rounded),
                          label: const Text('Apple'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // ── Sign up link ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        "Don't have an account?",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: servio.textSecondary),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SignUpScreen(role: widget.role),
                            ),
                          );
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
