import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'auth_role.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_background.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  AuthRole? _selectedRole;
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

  void _continue() {
    if (_selectedRole == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SignUpScreen(role: _selectedRole!)));
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
            child: AuthBackground(lightHeaderHeight: 210),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),

                  // ── Back button ──────────────────────────────
                  _AuthBackButton(onTap: () => Navigator.of(context).pop()),

                  const SizedBox(height: 20),

                  // ── Heading ──────────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve:
                          const Interval(0.0, 0.55, curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _entranceController,
                          curve: const Interval(0.0, 0.45)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'How will you\nuse SERVIO?',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose your role to get started.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Role cards ───────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve:
                          const Interval(0.2, 0.75, curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _entranceController,
                          curve: const Interval(0.2, 0.65)),
                      child: Column(
                        children: <Widget>[
                          _RoleCard(
                            icon: Icons.home_repair_service_rounded,
                            title: 'I need a service',
                            subtitle: 'Book trusted home professionals',
                            isSelected: _selectedRole == AuthRole.customer,
                            isDark: isDark,
                            onTap: () => setState(
                                () => _selectedRole = AuthRole.customer),
                          ),
                          const SizedBox(height: 14),
                          _RoleCard(
                            icon: Icons.handyman_rounded,
                            title: "I'm a technician",
                            subtitle: 'Offer your skills and earn',
                            isSelected: _selectedRole == AuthRole.technician,
                            isDark: isDark,
                            onTap: () => setState(
                                () => _selectedRole = AuthRole.technician),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  AnimatedOpacity(
                    opacity: _selectedRole == null ? 0.45 : 1.0,
                    duration: ServioMotion.micro,
                    child: ServioPrimaryButton(
                      label: 'Continue',
                      onPressed: _selectedRole == null ? null : _continue,
                    ),
                  ),

                  const SizedBox(height: 28),
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
// Frosted back button
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Go back',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: ServioSpacing.tapTarget,
          height: ServioSpacing.tapTarget,
          alignment: Alignment.center,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role selection card
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isDark
        ? (isSelected
            ? ServioColors.accentLight.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06))
        : (isSelected
            ? ServioColors.accent.withValues(alpha: 0.07)
            : Colors.white);
    final borderColor = isDark
        ? (isSelected
            ? ServioColors.accentLight.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.10))
        : (isSelected ? ServioColors.accent : ServioColors.borderLight);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: isSelected ? 0.95 : 0.75)
        : (isSelected ? ServioColors.deepBrown : ServioColors.textPrimaryLight);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : ServioColors.textSecondaryLight;
    final checkColor = isDark ? ServioColors.accentLight : ServioColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(ServioRadius.lg),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? ServioColors.accentLight.withValues(alpha: 0.18)
                    : ServioColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 22,
                  color:
                      isDark ? ServioColors.accentLight : ServioColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: subtitleColor)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: ServioMotion.micro,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? checkColor.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? checkColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : ServioColors.borderLight),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 12, color: checkColor)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
