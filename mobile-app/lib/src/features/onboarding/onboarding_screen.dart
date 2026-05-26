import 'dart:ui';
import 'package:flutter/material.dart';


import '../../design_system/servio_tokens.dart';

import '../auth/auth_landing_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: ServioMotion.page,
        pageBuilder: (_, __, ___) => const AuthLandingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    
    // Theme colors from the HTML
    const surfaceColor = Color(0xFFFBF9F8);
    const primaryFixedColor = Color(0xFFF0DFD9);
    const primaryColor = Color(0xFF170F0C);
    const secondaryColor = Color(0xFF6C5B50);
    const onSurfaceVariant = Color(0xFF4E4541);
    const surfaceTint = Color(0xFF685C57);
    const tertiaryFixed = Color(0xFFFFE088);
    const outlineVariant = Color(0xFFD1C4BE);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          // Radial Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -1.0),
                  radius: 1.5,
                  colors: [
                    primaryFixedColor.withValues(alpha: 0.4),
                    surfaceColor,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header (Skip Button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ServioSpacing.screenPadding, 12, ServioSpacing.screenPadding, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          textStyle: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(color: onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Hero Image Card
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Glowing background pulse
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.2 + (_pulseController.value * 0.3),
                                      child: Container(
                                        width: 280,
                                        height: 280,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primaryFixedColor.withValues(alpha: 0.2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryFixedColor.withValues(alpha: 0.3),
                                              blurRadius: 60,
                                              spreadRadius: 20,
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                // Main Card
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    color: surfaceColor.withValues(alpha: 0.8),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromRGBO(45, 36, 32, 0.05),
                                        blurRadius: 40,
                                        offset: Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Background Image
                                        Image.asset(
                                          'assets/images/onboarding_premium.jpg',
                                          fit: BoxFit.cover,
                                          color: Colors.white.withValues(alpha: 0.8),
                                          colorBlendMode: BlendMode.dstIn, // Mix blend multiply effect approximation
                                        ),
                                        
                                        // Gradient Overlay
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                surfaceTint.withValues(alpha: 0.6),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Badges
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 24),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              // Shield Icon
                                              _GlassContainer(
                                                width: 64,
                                                height: 64,
                                                shape: BoxShape.circle,
                                                child: Icon(
                                                  Icons.verified_user_rounded,
                                                  size: 32,
                                                  color: primaryColor,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              
                                              // "Active Pros" Badge
                                              _GlassContainer(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                borderRadius: BorderRadius.circular(32),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: tertiaryFixed,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: tertiaryFixed.withValues(alpha: 0.8),
                                                            blurRadius: 8,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Text(
                                                      '142 Active Pros',
                                                      style: TextStyle(
                                                        fontFamily: 'Montserrat',
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 1.2,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                          
                          // Text Content
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 34,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      color: primaryColor,
                                    ),
                                    children: [
                                      TextSpan(text: 'Find '),
                                      TextSpan(
                                        text: 'Trusted',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: secondaryColor,
                                        ),
                                      ),
                                      TextSpan(text: ' Experts'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Access an elite network of verified professionals dedicated to impeccable home care.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    height: 1.6,
                                    color: onSurfaceVariant,
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

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        surfaceColor,
                        surfaceColor.withValues(alpha: 0.8),
                        surfaceColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Progress Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 8,
                            height: 6,
                            decoration: BoxDecoration(
                              color: outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 8,
                            height: 6,
                            decoration: BoxDecoration(
                              color: outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _finishOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: primaryColor.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const _GlassContainer({
    required this.child,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? (shape == BoxShape.circle ? BorderRadius.circular(100) : BorderRadius.zero),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            shape: shape,
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
