import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'auth_role.dart';
import 'login_screen.dart';

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

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(role: _selectedRole!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Gradient background top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 260,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 36),
                  // Brand
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.0, 0.5,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.0, 0.4),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            'SERVIO',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: isDark ? ServioColors.navyDark : Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Premium Home Services',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (isDark ? ServioColors.navyDark : Colors.white)
                                  .withValues(alpha: 0.7),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Question
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.15, 0.65,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.15, 0.55),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            'How will you use SERVIO?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: isDark ? ServioColors.navyDark : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose your role to get started.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: (isDark ? ServioColors.navyDark : Colors.white)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Cards
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.3, 0.85,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.3, 0.75),
                      ),
                      child: Column(
                        children: <Widget>[
                          _RoleOptionCard(
                            role: AuthRole.customer,
                            isSelected: _selectedRole == AuthRole.customer,
                            icon: Icons.home_repair_service_rounded,
                            onTap: () => setState(
                                () => _selectedRole = AuthRole.customer),
                          ),
                          const SizedBox(height: 16),
                          _RoleOptionCard(
                            role: AuthRole.technician,
                            isSelected: _selectedRole == AuthRole.technician,
                            icon: Icons.handyman_rounded,
                            onTap: () => setState(
                                () => _selectedRole = AuthRole.technician),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _selectedRole == null ? 0.5 : 1.0,
                    duration: ServioMotion.micro,
                    child: ServioPrimaryButton(
                      label: 'Continue',
                      onPressed: _selectedRole == null ? null : _continue,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.role,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  final AuthRole role;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.curve,
        decoration: BoxDecoration(
          gradient: isSelected ? ServioGradients.brand : null,
          borderRadius: BorderRadius.circular(ServioRadius.lg),
        ),
        child: ServioCard(
          radius: ServioRadius.lg,
          elevated: isSelected,
          backgroundColor: isSelected ? Colors.transparent : null,
          borderColor: isSelected ? Colors.transparent : servio.border,
          child: Row(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.14)
                      : servio.backgroundSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected ? Colors.white : servio.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      role.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      role.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.82)
                            : servio.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: ServioMotion.micro,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : servio.border,
                    width: 2,
                  ),
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
