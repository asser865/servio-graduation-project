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
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: ServioMotion.page,
  )..forward();
  late final Animation<double> _bgGlow = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.0, 0.7, curve: ServioMotion.spring),
  );

  @override
  void initState() {
    super.initState();
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
            child: AuthBackground(lightHeaderHeight: 260),
          ),
          // Decorative accent glow blob top-right
          Positioned(
            top: -80,
            right: -60,
            child: AnimatedBuilder(
              animation: _bgGlow,
              builder: (BuildContext ctx, Widget? child) {
                return Opacity(
                  opacity: 0.55 * _bgGlow.value,
                  child: child,
                );
              },
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      ServioColors.accent.withValues(alpha: 0.35),
                      ServioColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      _AuthBackButton(onTap: () => Navigator.of(context).pop()),
                      const Spacer(),
                      _StepBadge(controller: _entranceController),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Heading ──────────────────────────────────
                  _AnimatedSection(
                    controller: _entranceController,
                    interval: const Interval(0.0, 0.55,
                        curve: ServioMotion.spring),
                    fadeInterval: const Interval(0.0, 0.45),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'How will you\nuse SERVIO?',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick the option that fits you best — you can always switch later.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Role cards ───────────────────────────────
                  _AnimatedSection(
                    controller: _entranceController,
                    interval:
                        const Interval(0.15, 0.7, curve: ServioMotion.spring),
                    fadeInterval: const Interval(0.15, 0.6),
                    child: _RoleCard(
                      icon: Icons.home_repair_service_rounded,
                      title: 'I need a service',
                      subtitle: 'Book trusted home professionals',
                      features: const <String>[
                        'Verified pros',
                        'Same-day booking',
                        'Cash or card',
                      ],
                      isSelected: _selectedRole == AuthRole.customer,
                      isDark: isDark,
                      onTap: () => setState(
                          () => _selectedRole = AuthRole.customer),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AnimatedSection(
                    controller: _entranceController,
                    interval:
                        const Interval(0.25, 0.8, curve: ServioMotion.spring),
                    fadeInterval: const Interval(0.25, 0.7),
                    child: _RoleCard(
                      icon: Icons.handyman_rounded,
                      title: "I'm a technician",
                      subtitle: 'Offer your skills and earn',
                      features: const <String>[
                        'Flexible hours',
                        'Weekly payouts',
                        'Build reviews',
                      ],
                      badge: 'Most popular',
                      isSelected: _selectedRole == AuthRole.technician,
                      isDark: isDark,
                      onTap: () => setState(
                          () => _selectedRole = AuthRole.technician),
                    ),
                  ),

                  const Spacer(),

                  _AnimatedSection(
                    controller: _entranceController,
                    interval:
                        const Interval(0.45, 1.0, curve: ServioMotion.spring),
                    fadeInterval: const Interval(0.45, 0.85),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AnimatedOpacity(
                          opacity: _selectedRole == null ? 0.5 : 1.0,
                          duration: ServioMotion.micro,
                          child: ServioPrimaryButton(
                            label: _selectedRole == null
                                ? 'Choose a role'
                                : 'Continue',
                            onPressed:
                                _selectedRole == null ? null : _continue,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Your information is private and secure.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
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
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({
    required this.controller,
    required this.interval,
    required this.fadeInterval,
    required this.child,
  });

  final AnimationController controller;
  final Interval interval;
  final Interval fadeInterval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: interval)),
      child: FadeTransition(
        opacity:
            CurvedAnimation(parent: controller, curve: fadeInterval),
        child: child,
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: const Interval(0.05, 0.55),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ServioColors.accentLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Step 1 of 3',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role selection card
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final String? badge;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: ServioMotion.fast,
      reverseDuration: ServioMotion.normal,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    final selected = widget.isSelected;

    final cardColor = isDark
        ? (selected
            ? ServioColors.accentLight.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.05))
        : (selected
            ? ServioColors.accent.withValues(alpha: 0.08)
            : Colors.white);
    final borderColor = isDark
        ? (selected
            ? ServioColors.accentLight.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.10))
        : (selected ? ServioColors.accent : ServioColors.borderLight);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: selected ? 1.0 : 0.80)
        : (selected
            ? ServioColors.deepBrown
            : ServioColors.textPrimaryLight);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : ServioColors.textSecondaryLight;
    final checkColor =
        isDark ? ServioColors.accentLight : ServioColors.accent;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: ServioMotion.normal,
          curve: ServioMotion.spring,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: (isDark
                              ? ServioColors.accentLight
                              : ServioColors.accent)
                          .withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _IconBadge(
                    icon: widget.icon,
                    selected: selected,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (widget.badge != null) ...<Widget>[
                              const SizedBox(width: 8),
                              _BadgePill(
                                label: widget.badge!,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  _RadioRing(
                    selected: selected,
                    color: checkColor,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String f in widget.features)
                    _FeatureChip(
                      label: f,
                      selected: selected,
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.selected,
    required this.isDark,
  });

  final IconData icon;
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = selected
        ? Colors.white
        : (isDark ? ServioColors.accentLight : ServioColors.accent);

    return AnimatedContainer(
      duration: ServioMotion.normal,
      curve: ServioMotion.spring,
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: selected
            ? (isDark ? ServioGradients.brandDark : ServioGradients.brand)
            : null,
        color: selected
            ? null
            : (isDark
                ? ServioColors.accentLight.withValues(alpha: 0.16)
                : ServioColors.accent.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: ServioColors.accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: 24, color: iconColor),
    );
  }
}

class _RadioRing extends StatelessWidget {
  const _RadioRing({
    required this.selected,
    required this.color,
    required this.isDark,
  });

  final bool selected;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ServioMotion.normal,
      curve: ServioMotion.spring,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected
              ? color
              : (isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : ServioColors.borderLight),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.label,
    required this.selected,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color textColor = selected
        ? (isDark ? ServioColors.accentLight : ServioColors.accent)
        : (isDark
            ? Colors.white.withValues(alpha: 0.6)
            : ServioColors.textSecondaryLight);
    final Color bg = selected
        ? (isDark
            ? ServioColors.accentLight.withValues(alpha: 0.14)
            : ServioColors.accent.withValues(alpha: 0.10))
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : ServioColors.backgroundSoftLight);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(
          color: selected
              ? (isDark ? ServioColors.accentLight : ServioColors.accent)
                  .withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_rounded, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient:
            isDark ? ServioGradients.brandDark : ServioGradients.accent,
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
