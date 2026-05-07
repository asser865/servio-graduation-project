import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../auth/auth_landing_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding – 3-slide flow (strictly follows UI spec)
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _iconPulse;
  int _currentIndex = 0;

  static const List<_OnboardingSlideData> _slides = <_OnboardingSlideData>[
    _OnboardingSlideData(
      title: 'Find Trusted Experts',
      body:
          'Access our vetted network of master electricians, certified plumbers, and elite designers — all background-checked and trade-licensed.',
      icon: Icons.search_rounded,
      secondaryIcon: Icons.verified_user_rounded,
      gradientColors: <Color>[Color(0xFF3C2415), Color(0xFF5C3D2E)],
    ),
    _OnboardingSlideData(
      title: 'Book with Confidence',
      body:
          'Secure escrow payments protect every transaction. Your money is held safely until the job is completed to your satisfaction.',
      icon: Icons.lock_outline_rounded,
      secondaryIcon: Icons.payments_outlined,
      gradientColors: <Color>[Color(0xFF222831), Color(0xFF393E46)],
    ),
    _OnboardingSlideData(
      title: 'AI Finds the Right Pro',
      body:
          'Describe your issue or snap a photo — our AI instantly matches you with the best-rated professional for the job.',
      icon: Icons.auto_awesome_rounded,
      secondaryIcon: Icons.smart_toy_outlined,
      gradientColors: <Color>[Color(0xFF9A8C73), Color(0xFFBFB09A)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _iconPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconPulse.dispose();
    super.dispose();
  }

  void _nextOrFinish() {
    if (_currentIndex == _slides.length - 1) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: ServioMotion.page,
          pageBuilder: (_, __, ___) => const AuthLandingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      return;
    }

    _pageController.nextPage(
      duration: ServioMotion.page,
      curve: ServioMotion.curve,
    );
  }

  void _skip() {
    _pageController.animateToPage(
      _slides.length - 1,
      duration: ServioMotion.page,
      curve: ServioMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Skip button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(ServioSpacing.screenPadding,
                  12, ServioSpacing.screenPadding, 0),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _currentIndex == _slides.length - 1 ? 0.0 : 1.0,
                    duration: ServioMotion.micro,
                    child: TextButton(
                      onPressed:
                          _currentIndex == _slides.length - 1 ? null : _skip,
                      child: Text(
                        'Skip',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: servio.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── PageView ─────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: _slides.length,
                itemBuilder: (BuildContext context, int index) {
                  final slide = _slides[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ServioSpacing.screenPadding),
                    child: Column(
                      children: <Widget>[
                        // ── Illustration area ────────────────
                        Expanded(
                          flex: 50,
                          child: Center(
                            child: _IconContainerMorphing(
                              slide: slide,
                              pulse: _iconPulse,
                              isDark: isDark,
                            ),
                          ),
                        ),

                        // ── Text + Controls ──────────────────
                        Expanded(
                          flex: 50,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SizedBox(height: 8),
                              // Title with AnimatedSwitcher
                              AnimatedSwitcher(
                                duration: ServioMotion.micro,
                                switchInCurve: ServioMotion.curve,
                                switchOutCurve: ServioMotion.curve,
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.15),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  slide.title,
                                  key: ValueKey<String>(slide.title),
                                  style: theme.textTheme.headlineLarge,
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Body with AnimatedSwitcher
                              AnimatedSwitcher(
                                duration: ServioMotion.micro,
                                switchInCurve: ServioMotion.curve,
                                switchOutCurve: ServioMotion.curve,
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  slide.body,
                                  key: ValueKey<String>(slide.body),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: servio.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Dot indicator (8px → 24px)
                              _DotIndicator(
                                count: _slides.length,
                                current: _currentIndex,
                              ),
                              const Spacer(),
                              ServioPrimaryButton(
                                label: _currentIndex == _slides.length - 1
                                    ? 'Get Started'
                                    : 'Continue',
                                onPressed: _nextOrFinish,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Indicator — animates width 8→24 per spec
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        count,
        (int index) => AnimatedContainer(
          duration: ServioMotion.micro,
          curve: ServioMotion.spring,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == current ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == current ? servio.accent : servio.border,
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon Container with gradient morphing + glow
// ─────────────────────────────────────────────────────────────────────────────

class _IconContainerMorphing extends StatelessWidget {
  const _IconContainerMorphing({
    required this.slide,
    required this.pulse,
    required this.isDark,
  });

  final _OnboardingSlideData slide;
  final AnimationController pulse;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ServioMotion.page,
      switchInCurve: ServioMotion.reveal,
      switchOutCurve: ServioMotion.reveal,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: ServioMotion.spring),
            ),
            child: child,
          ),
        );
      },
      child: SizedBox(
        key: ValueKey<String>(slide.title),
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Outer glow ring
            AnimatedBuilder(
              animation: pulse,
              builder: (BuildContext context, Widget? child) {
                return Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color.lerp(
                        slide.gradientColors.first.withValues(alpha: 0.0),
                        slide.gradientColors.first.withValues(alpha: 0.2),
                        pulse.value,
                      )!,
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            // Mid ring
            AnimatedBuilder(
              animation: pulse,
              builder: (BuildContext context, Widget? child) {
                return Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.gradientColors.first
                        .withValues(alpha: 0.04 + 0.03 * pulse.value),
                  ),
                );
              },
            ),
            // Main icon container with gradient
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: slide.gradientColors,
                ),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: slide.gradientColors.first.withValues(alpha: 0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Icon(
                slide.icon,
                size: 64,
                color: Colors.white,
              ),
            ),
            // Secondary floating icon
            Positioned(
              bottom: 32,
              right: 16,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (BuildContext context, Widget? child) {
                  return Transform.translate(
                    offset: Offset(0, -4 * pulse.value),
                    child: child,
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        isDark ? ServioColors.surfaceRaisedDark : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: isDark
                        ? ServioShadows.restDark
                        : ServioShadows.elevated,
                  ),
                  child: Icon(
                    slide.secondaryIcon,
                    size: 24,
                    color: slide.gradientColors.first,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.body,
    required this.icon,
    required this.secondaryIcon,
    required this.gradientColors,
  });

  final String title;
  final String body;
  final IconData icon;
  final IconData secondaryIcon;
  final List<Color> gradientColors;
}
