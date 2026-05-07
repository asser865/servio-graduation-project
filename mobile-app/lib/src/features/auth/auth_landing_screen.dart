import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    )..forward();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldReduceMotion = MediaQuery.of(context).disableAnimations;
    if (shouldReduceMotion) {
      _motionController.stop();
      return;
    }
    if (!_motionController.isAnimating) {
      _motionController.repeat();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _openRoleSelection() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shouldReduceMotion = MediaQuery.of(context).disableAnimations;
    final motion = shouldReduceMotion
        ? const AlwaysStoppedAnimation<double>(0)
        : _motionController;

    return Scaffold(
      backgroundColor:
          isDark ? ServioColors.backgroundDark : ServioColors.backgroundLight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: AuthBackground(fullBleed: true),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTightHeight = constraints.maxHeight < 640;
                final isCompactHeight = constraints.maxHeight < 720;
                final horizontalPadding = constraints.maxWidth < 360
                    ? 16.0
                    : ServioSpacing.screenPadding;
                final topGap = isTightHeight
                    ? 18.0
                    : isCompactHeight
                        ? 24.0
                        : 30.0;
                final sectionGap = isTightHeight
                    ? 16.0
                    : isCompactHeight
                        ? 18.0
                        : 22.0;
                final bottomGap = 22 + MediaQuery.paddingOf(context).bottom;
                final minContentHeight =
                    (constraints.maxHeight - topGap - bottomGap)
                        .clamp(0.0, double.infinity)
                        .toDouble();

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topGap,
                    horizontalPadding,
                    bottomGap,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        minHeight: minContentHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _Reveal(
                                controller: _entranceController,
                                intervalStart: 0,
                                child: _BrandBar(
                                  isDark: isDark,
                                  motion: motion,
                                ),
                              ),
                              SizedBox(height: sectionGap),
                              _Reveal(
                                controller: _entranceController,
                                intervalStart: 0.08,
                                slideOffset: const Offset(0, 0.16),
                                child: _HeroIntro(
                                  isCompact: isCompactHeight,
                                  isTight: isTightHeight,
                                  motion: motion,
                                ),
                              ),
                              SizedBox(height: sectionGap),
                              _ServiceHighlights(
                                controller: _entranceController,
                                isDark: isDark,
                                isCompact: isCompactHeight,
                                motion: motion,
                              ),
                              SizedBox(height: sectionGap),
                              _TrustGrid(
                                controller: _entranceController,
                                isDark: isDark,
                                isCompact: isCompactHeight,
                                motion: motion,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(height: isCompactHeight ? 20 : 26),
                              _Reveal(
                                controller: _entranceController,
                                intervalStart: 0.42,
                                slideOffset: const Offset(0, 0.12),
                                child: _ActionPanel(
                                  isDark: isDark,
                                  onLogin: _openLogin,
                                  onCreateAccount: _openRoleSelection,
                                  motion: motion,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
    this.slideOffset = const Offset(0, 0.08),
  });

  final AnimationController controller;
  final double intervalStart;
  final Widget child;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    final end = (intervalStart + 0.38).clamp(0.0, 1.0).toDouble();
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(intervalStart, end, curve: ServioMotion.spring),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: slideOffset,
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

double _wave(Animation<double> motion, [double phase = 0]) {
  return math.sin((motion.value * math.pi * 2) + phase);
}

double _pulse(Animation<double> motion, [double multiplier = 1]) {
  final value = (motion.value * multiplier) % 1.0;
  return Curves.easeOut.transform(value);
}

class _BrandBar extends StatelessWidget {
  const _BrandBar({
    required this.isDark,
    required this.motion,
  });

  final bool isDark;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'SERVIO',
      child: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: motion,
            builder: (context, _) {
              final float = _wave(motion) * 1.8;
              final glow = 0.30 + ((_wave(motion, math.pi / 2) + 1) / 2) * 0.18;

              return Transform.translate(
                offset: Offset(0, float),
                child: Transform.rotate(
                  angle: _wave(motion, math.pi / 3) * 0.025,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.accent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: ServioColors.accent.withValues(alpha: glow),
                          blurRadius: 24 + glow * 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home_repair_service_rounded,
                      color: ServioColors.navyDark,
                      size: 23,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SERVIO',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PREMIUM HOME SERVICES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: isDark ? 0.48 : 0.58),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro({
    required this.isCompact,
    required this.isTight,
    required this.motion,
  });

  final bool isCompact;
  final bool isTight;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontFamily: 'PlayfairDisplay',
      fontWeight: FontWeight.w800,
      height: 1.02,
      letterSpacing: 0,
      fontSize: isTight
          ? 33
          : isCompact
              ? 38
              : 42,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ActiveBadge(isTight: isTight, motion: motion),
        SizedBox(height: isTight ? 8 : 10),
        _HeroKicker(theme: theme),
        SizedBox(height: isTight ? 6 : 8),
        AnimatedBuilder(
          animation: motion,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _wave(motion, math.pi / 2) * 1.4),
              child: child,
            );
          },
          child: Text.rich(
            TextSpan(
              text: 'Refined\n',
              children: <InlineSpan>[
                TextSpan(
                  text: 'Home Services\n',
                  style: titleStyle?.copyWith(
                    color: ServioColors.accentLight,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: 'at Your Command.'),
              ],
            ),
            style: titleStyle,
          ),
        ),
        SizedBox(height: isTight ? 8 : 10),
        Text(
          'Transform your home with verified technicians for repair, maintenance, and finishing.',
          maxLines: isTight ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
            fontFamily: 'Inter',
            height: 1.42,
          ),
        ),
      ],
    );
  }
}

class _HeroKicker extends StatelessWidget {
  const _HeroKicker({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'THE STANDARD OF EXCELLENCE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({
    required this.isTight,
    required this.motion,
  });

  final bool isTight;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTight ? 12 : 14,
        vertical: isTight ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: motion,
            builder: (context, _) {
              final pulse = _pulse(motion, 2.6);

              return SizedBox(
                width: 18,
                height: 18,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Opacity(
                      opacity: (1 - pulse) * 0.34,
                      child: Transform.scale(
                        scale: 1 + pulse * 1.9,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ServioColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: ServioColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          Text(
            isTight ? '142 Pros Active Now' : '142 Professionals Active Now',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ServiceHighlights extends StatelessWidget {
  const _ServiceHighlights({
    required this.controller,
    required this.isDark,
    required this.isCompact,
    required this.motion,
  });

  final AnimationController controller;
  final bool isDark;
  final bool isCompact;
  final Animation<double> motion;

  static const List<_ServiceChipData> _items = <_ServiceChipData>[
    _ServiceChipData(Icons.plumbing_rounded, 'Plumbing', ServioColors.accent),
    _ServiceChipData(
        Icons.electrical_services_rounded, 'Electrical', Color(0xFFD4AF37)),
    _ServiceChipData(Icons.ac_unit_rounded, 'AC Repair', Color(0xFF64A5D2)),
    _ServiceChipData(Icons.auto_awesome_rounded, 'Cleaning', Color(0xFF5AAA9B)),
    _ServiceChipData(Icons.format_paint_rounded, 'Painting', Color(0xFFC86E50)),
    _ServiceChipData(Icons.handyman_rounded, 'Carpentry', Color(0xFF8C5F32)),
  ];

  @override
  Widget build(BuildContext context) {
    return _Reveal(
      controller: controller,
      intervalStart: 0.22,
      slideOffset: const Offset(0, 0.10),
      child: Wrap(
        spacing: isCompact ? 8 : 9,
        runSpacing: isCompact ? 8 : 9,
        children: _items.asMap().entries.map(
          (entry) {
            return _ServiceChip(
              data: entry.value,
              isDark: isDark,
              isCompact: isCompact,
              index: entry.key,
              motion: motion,
            );
          },
        ).toList(),
      ),
    );
  }
}

class _ServiceChipData {
  const _ServiceChipData(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.data,
    required this.isDark,
    required this.isCompact,
    required this.index,
    required this.motion,
  });

  final _ServiceChipData data;
  final bool isDark;
  final bool isCompact;
  final int index;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: motion,
      builder: (context, child) {
        final wave = _wave(motion, index * 0.72);
        final lift = wave * 1.7;

        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: 1 + ((wave + 1) / 2) * 0.012,
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 8 : 9,
          isCompact ? 8 : 9,
          isCompact ? 11 : 13,
          isCompact ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: isCompact ? 27 : 30,
              height: isCompact ? 27 : 30,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: data.color.withValues(alpha: 0.28)),
              ),
              child: Icon(
                data.icon,
                size: isCompact ? 14 : 16,
                color: data.color,
              ),
            ),
            SizedBox(width: isCompact ? 7 : 8),
            Text(
              data.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustGrid extends StatelessWidget {
  const _TrustGrid({
    required this.controller,
    required this.isDark,
    required this.isCompact,
    required this.motion,
  });

  final AnimationController controller;
  final bool isDark;
  final bool isCompact;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    return _Reveal(
      controller: controller,
      intervalStart: 0.32,
      slideOffset: const Offset(0, 0.08),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _TrustPill(
              icon: Icons.shield_outlined,
              title: 'Verified professionals',
              isDark: isDark,
              isCompact: isCompact,
              index: 0,
              motion: motion,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TrustPill(
              icon: Icons.star_outline_rounded,
              title: 'Top-rated every time',
              isDark: isDark,
              isCompact: isCompact,
              index: 1,
              motion: motion,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.isCompact,
    required this.index,
    required this.motion,
  });

  final IconData icon;
  final String title;
  final bool isDark;
  final bool isCompact;
  final int index;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.86);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : ServioColors.borderLight.withValues(alpha: 0.76);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : ServioColors.textPrimaryLight;

    return AnimatedBuilder(
      animation: motion,
      builder: (context, child) {
        final glow = (_wave(motion, index * math.pi) + 1) / 2;
        final animatedBorder = Color.lerp(
          borderColor,
          ServioColors.accentLight,
          glow * 0.28,
        );

        return Container(
          constraints: BoxConstraints(minHeight: isCompact ? 64 : 70),
          padding: EdgeInsets.all(isCompact ? 13 : 15),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border.all(color: animatedBorder ?? borderColor),
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            boxShadow: <BoxShadow>[
              ...(isDark ? ServioShadows.restDark : ServioShadows.rest),
              BoxShadow(
                color: ServioColors.accent.withValues(alpha: glow * 0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: <Widget>[
          Container(
            width: isCompact ? 34 : 38,
            height: isCompact ? 34 : 38,
            decoration: BoxDecoration(
              gradient: ServioGradients.accent,
              borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
            ),
            child: Icon(
              icon,
              size: isCompact ? 17 : 19,
              color: ServioColors.navyDark,
            ),
          ),
          SizedBox(width: isCompact ? 9 : 11),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (isCompact
                      ? theme.textTheme.labelMedium
                      : theme.textTheme.titleSmall)
                  ?.copyWith(
                color: titleColor,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.isDark,
    required this.onLogin,
    required this.onCreateAccount,
    required this.motion,
  });

  final bool isDark;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : ServioColors.deepBrown.withValues(alpha: 0.42);
    final foregroundColor =
        isDark ? Colors.white.withValues(alpha: 0.86) : ServioColors.deepBrown;

    final baseBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : ServioColors.borderLight.withValues(alpha: 0.86);

    return AnimatedBuilder(
      animation: motion,
      builder: (context, child) {
        final glow = (_wave(motion, math.pi / 2) + 1) / 2;
        final borderColor = Color.lerp(
          baseBorder,
          ServioColors.accentLight,
          glow * 0.32,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? ServioColors.surfaceDark.withValues(alpha: 0.58)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(ServioRadius.xxl),
            border: Border.all(color: borderColor ?? baseBorder),
            boxShadow: <BoxShadow>[
              ...(isDark ? ServioShadows.elevatedDark : ServioShadows.elevated),
              BoxShadow(
                color: ServioColors.accentLight.withValues(alpha: glow * 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ServioPrimaryButton(
              label: 'Sign In',
              onPressed: onLogin,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onCreateAccount,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(color: outlineColor, width: 1.4),
                foregroundColor: foregroundColor,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Create Account'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
