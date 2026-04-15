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

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  AuthRole? _selectedRole;

  void _continue() {
    if (_selectedRole == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(role: _selectedRole!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 32),
              // Brand header — gradient text matching web primary-gradient
              ShaderMask(
                shaderCallback: (Rect bounds) =>
                    ServioGradients.brand.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  'SERVIO',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How will you use SERVIO?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your role to get started.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 32),
              _RoleOptionCard(
                role: AuthRole.customer,
                isSelected: _selectedRole == AuthRole.customer,
                icon: Icons.home_repair_service_rounded,
                onTap: () => setState(() => _selectedRole = AuthRole.customer),
              ),
              const SizedBox(height: 16),
              _RoleOptionCard(
                role: AuthRole.technician,
                isSelected: _selectedRole == AuthRole.technician,
                icon: Icons.handyman_rounded,
                onTap: () => setState(() => _selectedRole = AuthRole.technician),
              ),
              const Spacer(),
              Opacity(
                opacity: _selectedRole == null ? 0.6 : 1,
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
                  color: isSelected ? Colors.white.withValues(alpha: 0.14) : servio.backgroundSoft,
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
                        color: isSelected ? Colors.white.withValues(alpha: 0.82) : servio.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
