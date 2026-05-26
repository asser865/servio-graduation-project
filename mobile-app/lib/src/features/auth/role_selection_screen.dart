import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';
import 'auth_role.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  AuthRole _selectedRole = AuthRole.customer;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: ServioMotion.page,
  )..forward();

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignUpScreen(role: _selectedRole),
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 700 ? 32.0 : 20.0;
            final maxWidth = constraints.maxWidth >= 700 ? 520.0 : 480.0;
            final compactHeight = constraints.maxHeight < 720;
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
                    compactHeight ? 14 : 20,
                    horizontalPadding,
                    20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _Reveal(
                          controller: _entranceController,
                          intervalStart: 0,
                          child: _TopBar(
                            onBack: () => Navigator.of(context).pop(),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 22 : 34),
                        _Reveal(
                          controller: _entranceController,
                          intervalStart: 0.08,
                          child: const _Heading(),
                        ),
                        SizedBox(height: compactHeight ? 24 : 32),
                        _Reveal(
                          controller: _entranceController,
                          intervalStart: 0.18,
                          child: _RoleOptionCard(
                            icon: Icons.home_rounded,
                            title: 'I need a service',
                            subtitle:
                                'Find trusted professionals for home repairs, maintenance, and projects.',
                            isSelected: _selectedRole == AuthRole.customer,
                            onTap: () => setState(
                              () => _selectedRole = AuthRole.customer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Reveal(
                          controller: _entranceController,
                          intervalStart: 0.28,
                          child: _RoleOptionCard(
                            icon: Icons.construction_rounded,
                            title: 'Offer my skills',
                            subtitle:
                                'Connect with homeowners, manage jobs, and grow your service business.',
                            isSelected: _selectedRole == AuthRole.technician,
                            onTap: () => setState(
                              () => _selectedRole = AuthRole.technician,
                            ),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 24 : 40),
                        _Reveal(
                          controller: _entranceController,
                          intervalStart: 0.40,
                          child: _BottomActions(
                            onContinue: _continue,
                            onLogin: _openLogin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(ServioSpacing.tapTarget, ServioSpacing.tapTarget),
            backgroundColor: const Color(0xFFF5F3F0),
            foregroundColor: ServioColors.navyDark,
          ),
        ),
        const Spacer(),
        const _ProgressPills(),
        const Spacer(),
        const SizedBox(width: ServioSpacing.tapTarget),
      ],
    );
  }
}

class _ProgressPills extends StatelessWidget {
  const _ProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _pill(active: true),
        const SizedBox(width: 8),
        _pill(active: false),
        const SizedBox(width: 8),
        _pill(active: false),
      ],
    );
  }

  Widget _pill({required bool active}) {
    return AnimatedContainer(
      duration: ServioMotion.normal,
      curve: ServioMotion.spring,
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: active ? ServioColors.navyDark : const Color(0xFFE4E2DF),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'How do you want to use SERVIO?',
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
          'Select an account type to customize your experience.',
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

class _RoleOptionCard extends StatefulWidget {
  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_RoleOptionCard> createState() => _RoleOptionCardState();
}

class _RoleOptionCardState extends State<_RoleOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final borderColor =
        selected ? ServioColors.navyDark : const Color(0xFFE4E2DF);
    final cardColor =
        selected ? const Color(0xFFF3EDE7) : const Color(0xFFFFFFFF);

    return Semantics(
      button: true,
      selected: selected,
      label: widget.title,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: ServioMotion.fast,
          curve: ServioMotion.spring,
          child: AnimatedContainer(
            duration: ServioMotion.normal,
            curve: ServioMotion.spring,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color.fromRGBO(26, 29, 35, 0.08),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _RoleIcon(icon: widget.icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: ServioColors.navyDark,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _RadioIndicator(selected: selected),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ServioColors.textSecondaryLight,
                              fontFamily: 'Inter',
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleIcon extends StatelessWidget {
  const _RoleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF3EDE7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: ServioColors.navyDark,
        size: 28,
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ServioMotion.normal,
      curve: ServioMotion.spring,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? ServioColors.navyDark : Colors.transparent,
        border: Border.all(
          color: selected ? ServioColors.navyDark : const Color(0xFFC6C6CB),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onContinue,
    required this.onLogin,
  });

  final VoidCallback onContinue;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFFFBF9F6).withValues(alpha: 0),
            const Color(0xFFFBF9F6),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ContinueButton(onPressed: onContinue),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Already have an account? ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ServioColors.textSecondaryLight,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton(
                onPressed: onLogin,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: ServioColors.navyDark,
                ),
                child: const Text('Log in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatefulWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: ServioColors.navyDark,
            borderRadius: BorderRadius.all(Radius.circular(999)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(26, 29, 35, 0.10),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                'Continue',
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
        (intervalStart + 0.45).clamp(0.0, 1.0).toDouble(),
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
