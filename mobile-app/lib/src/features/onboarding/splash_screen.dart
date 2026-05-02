import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/models/user_account.dart';
import '../../design_system/servio_tokens.dart';
import '../auth/role_selection_screen.dart';
import '../customer/customer_dashboard_screen.dart';
import '../technician/technician_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _progressController;
  late final AnimationController _fadeOutController;

  static const String _word = 'SERVIO';

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _logoController.forward().then((_) {
      _progressController.forward().then((_) {
        _navigateToNextScreen();
      });
    });
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    final session = context.read<SessionProvider>();
    Widget nextScreen = const RoleSelectionScreen();

    if (session.isLoggedIn) {
      if (session.account!.role == UserRole.technician) {
        nextScreen = const TechnicianDashboardScreen();
      } else {
        nextScreen = const CustomerDashboardScreen();
      }
    }

    _fadeOutController.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: ServioMotion.page,
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _fadeOutController,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: 1.0 - _fadeOutController.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: isDark
            ? ServioColors.backgroundDark
            : ServioColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // ── Animated word "SERVIO" ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_word.length, (int index) {
                  final double start = index * 0.10;
                  final double end = (start + 0.35).clamp(0.0, 1.0);

                  final Animation<double> letterAnim =
                      Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(
                      parent: _logoController,
                      curve: Interval(start, end, curve: ServioMotion.spring),
                    ),
                  );

                  return AnimatedBuilder(
                    animation: letterAnim,
                    builder: (BuildContext context, Widget? child) {
                      return Transform.translate(
                        offset: Offset(0, 12 * (1 - letterAnim.value)),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * letterAnim.value,
                          child: Opacity(
                            opacity: letterAnim.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) =>
                            ServioGradients.brand.createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          _word[index],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 10),

              // ── Tagline ──────────────────────────────────
              AnimatedBuilder(
                animation: _logoController,
                builder: (BuildContext context, Widget? child) {
                  final double opacity = CurvedAnimation(
                    parent: _logoController,
                    curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
                  ).value;
                  return Opacity(opacity: opacity, child: child);
                },
                child: Text(
                  'Premium Home Services',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    color: isDark
                        ? ServioColors.textSecondaryDark
                        : ServioColors.textSecondaryLight,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Gradient progress bar ────────────────────
              AnimatedBuilder(
                animation: _progressController,
                builder: (BuildContext context, Widget? _) {
                  return SizedBox(
                    width: 160,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: <Widget>[
                          Container(
                            color: isDark
                                ? ServioColors.backgroundSoftDark
                                : ServioColors.backgroundSoftLight,
                          ),
                          FractionallySizedBox(
                            widthFactor: _progressController.value,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: ServioGradients.loader,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
