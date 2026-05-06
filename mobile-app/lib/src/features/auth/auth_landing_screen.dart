import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'widgets/auth_background.dart';

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen>
    with SingleTickerProviderStateMixin {
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
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : ServioColors.backgroundLight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: AuthBackground(lightHeaderHeight: 260),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 48),

                  // ── Brand ──────────────────────────────────────
                  _BrandMark(controller: _entranceController),

                  const SizedBox(height: 36),

                  // ── Trust pills ────────────────────────────────
                  _TrustPill(
                    controller: _entranceController,
                    intervalStart: 0.25,
                    icon: Icons.shield_outlined,
                    label: 'Verified professionals',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _TrustPill(
                    controller: _entranceController,
                    intervalStart: 0.35,
                    icon: Icons.star_outline_rounded,
                    label: 'Top-rated every time',
                    isDark: isDark,
                  ),

                  const Spacer(),

                  // ── CTAs ───────────────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.4, 0.9,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.4, 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ServioPrimaryButton(
                            label: 'Sign In',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen()),
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const RoleSelectionScreen()),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : ServioColors.deepBrown,
                                width: 1.5,
                              ),
                              foregroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : ServioColors.deepBrown,
                            ),
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: controller,
              curve:
                  const Interval(0.0, 0.5, curve: ServioMotion.spring))),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: controller, curve: const Interval(0.0, 0.4)),
        child: Column(
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  size: 26, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              'SERVIO',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'PREMIUM HOME SERVICES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 2.0,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.controller,
    required this.intervalStart,
    required this.icon,
    required this.label,
    required this.isDark,
  });
  final AnimationController controller;
  final double intervalStart;
  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: controller,
          curve: Interval(intervalStart, intervalStart + 0.3)),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.92),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : ServioColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(ServioRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? ServioColors.accentLight.withValues(alpha: 0.18)
                    : ServioColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 14,
                  color: isDark
                      ? ServioColors.accentLight
                      : ServioColors.accent),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : ServioColors.textPrimaryLight,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
