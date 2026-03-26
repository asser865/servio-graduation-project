import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../auth/role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  static const List<_OnboardingSlideData> _slides = <_OnboardingSlideData>[
    _OnboardingSlideData(
      title: 'Find Trusted Experts',
      body: 'Verified technicians at your fingertips.',
      icon: Icons.plumbing_rounded,
      accentIcon: Icons.search_rounded,
    ),
    _OnboardingSlideData(
      title: 'Book with Confidence',
      body: 'Escrow payments protect every transaction.',
      icon: Icons.verified_user_rounded,
      accentIcon: Icons.home_rounded,
    ),
    _OnboardingSlideData(
      title: 'AI Finds the Right Pro',
      body: 'Describe your issue. We handle the match.',
      icon: Icons.auto_awesome_rounded,
      accentIcon: Icons.smartphone_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextOrFinish() {
    if (_currentIndex == _slides.length - 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const RoleSelectionScreen(),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(
                    onPressed: _currentIndex == _slides.length - 1 ? null : _skip,
                    child: Text(
                      'Skip',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (BuildContext context, int index) {
                    final slide = _slides[index];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 55,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: ServioGradients.warm,
                                borderRadius: BorderRadius.circular(ServioRadius.xl),
                                border: Border.all(
                                  color: servio.border.withValues(alpha: isDark ? 0.45 : 1),
                                ),
                              ),
                              child: _OnboardingIllustration(data: slide),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 45,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              AnimatedSwitcher(
                                duration: ServioMotion.micro,
                                switchInCurve: ServioMotion.curve,
                                switchOutCurve: ServioMotion.curve,
                                child: Text(
                                  slide.title,
                                  key: ValueKey<String>(slide.title),
                                  style: theme.textTheme.headlineLarge,
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: ServioMotion.micro,
                                switchInCurve: ServioMotion.curve,
                                switchOutCurve: ServioMotion.curve,
                                child: Text(
                                  slide.body,
                                  key: ValueKey<String>(slide.body),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: servio.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List<Widget>.generate(
                                  _slides.length,
                                  (int dotIndex) => AnimatedContainer(
                                    duration: ServioMotion.micro,
                                    curve: ServioMotion.curve,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: dotIndex == _currentIndex ? 26 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: dotIndex == _currentIndex
                                          ? servio.accent
                                          : servio.border,
                                      borderRadius: BorderRadius.circular(ServioRadius.full),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ServioPrimaryButton(
                                label: _currentIndex == _slides.length - 1
                                    ? 'Get Started'
                                    : 'Continue',
                                onPressed: _nextOrFinish,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.body,
    required this.icon,
    required this.accentIcon,
  });

  final String title;
  final String body;
  final IconData icon;
  final IconData accentIcon;
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({
    required this.data,
  });

  final _OnboardingSlideData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            Positioned(
              top: 28,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _IllustrationBubble(
                    size: 72,
                    icon: data.accentIcon,
                    gradient: ServioGradients.accent,
                    iconColor: Colors.white,
                  ),
                  _IllustrationBubble(
                    size: 48,
                    icon: Icons.verified_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    iconColor: ServioColors.accent,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 34,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: constraints.maxHeight * 0.52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: constraints.maxWidth * 0.26,
                    height: constraints.maxHeight * 0.44,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.brand,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: ServioShadows.rest,
                    ),
                    child: Icon(
                      data.icon,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 44,
              right: 96,
              bottom: 70,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: ServioShadows.rest,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0x26FFFFFF),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(ServioRadius.xl),
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 600),
                curve: ServioMotion.curve,
                scale: 1,
                child: Icon(
                  data.icon,
                  size: 108,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IllustrationBubble extends StatelessWidget {
  const _IllustrationBubble({
    required this.size,
    required this.icon,
    required this.iconColor,
    this.gradient,
    this.color,
  });

  final double size;
  final IconData icon;
  final Color iconColor;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        icon,
        color: iconColor,
      ),
    );
  }
}
