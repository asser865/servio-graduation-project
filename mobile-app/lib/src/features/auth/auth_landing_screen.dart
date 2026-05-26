import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen>
    with TickerProviderStateMixin {
  static const String _heroImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD8HIV0pwJ26X2SZwenTmbkhiXpPgA37Wgj8akNKQScgMZyPI7-4rJ-aN2yygBbWrWEva7fixVvIiyal8zfRVq6J7jiWsv9gAvRyRkxBFesd131BV4zBwbvEM9Ute_bhJaHZYBETKtmm03Pp52Zp76_X808AlKcdWgrVamI8M1H6nBN0It9mdmAQn-UHhLePsCHQbtEN4LhASPWtmwPNU8PUyqi0q2er7QHdZfxPvkYbFkjNuY85FFMtIh7rgt5S7oadRICFZ8veD17';

  late final AnimationController _entranceController;
  late final AnimationController _imageController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _imageController.stop();
      return;
    }
    if (!_imageController.isAnimating) {
      _imageController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _imageController.dispose();
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
    final media = MediaQuery.of(context);
    final viewportHeight = media.size.height;
    final heroHeight = viewportHeight < 700 ? (viewportHeight * 0.46) : 486.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFFBF9F6),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color.fromRGBO(26, 29, 35, 0.18),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: SizedBox.expand(
                child: Column(
                  children: <Widget>[
                    _HeroPanel(
                      imageUrl: _heroImageUrl,
                      height: heroHeight,
                      imageController: _imageController,
                      entranceController: _entranceController,
                    ),
                    Expanded(
                      child: _ContentPanel(
                        controller: _entranceController,
                        bottomPadding: media.padding.bottom,
                        onCreateAccount: _openRoleSelection,
                        onSignIn: _openLogin,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.imageUrl,
    required this.height,
    required this.imageController,
    required this.entranceController,
  });

  final String imageUrl;
  final double height;
  final Animation<double> imageController;
  final AnimationController entranceController;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedBuilder(
              animation: imageController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1 + imageController.value * 0.08,
                  child: child,
                );
              },
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, _, __) => const _HeroFallback(),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    const Color(0xFFFBF9F6).withValues(alpha: 0.38),
                    const Color(0xFFFBF9F6),
                  ],
                  stops: const <double>[0.32, 0.68, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _Reveal(
                controller: entranceController,
                intervalStart: 0,
                child: const _BrandLockup(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE4E2DF),
            Color(0xFFF3EDE7),
            Color(0xFFBFB09A),
          ],
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'SERVIO',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: ServioColors.navyDark,
                fontFamily: 'Poppins',
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: ServioColors.accent,
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
        ),
      ],
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({
    required this.controller,
    required this.bottomPadding,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final AnimationController controller;
  final double bottomPadding;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        compactHeight ? 16 : 20,
        20,
        24 + bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Reveal(
            controller: controller,
            intervalStart: 0.10,
            child: Text(
              'Transform your home with verified technicians.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: ServioColors.navyDark,
                    fontFamily: 'Poppins',
                    fontSize: compactHeight ? 26 : 28,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                    letterSpacing: 0,
                  ),
            ),
          ),
          SizedBox(height: compactHeight ? 16 : 22),
          _ServiceChips(controller: controller),
          const Spacer(),
          _Reveal(
            controller: controller,
            intervalStart: 0.52,
            child: _ActionButtons(
              onCreateAccount: onCreateAccount,
              onSignIn: onSignIn,
            ),
          ),
          const SizedBox(height: 18),
          _Reveal(
            controller: controller,
            intervalStart: 0.64,
            child: Center(
              child: Text.rich(
                TextSpan(
                  text: 'By continuing, you agree to our ',
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: ServioColors.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: ServioColors.accent,
                        decorationThickness: 1.4,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ServioColors.textSecondaryLight,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceChips extends StatelessWidget {
  const _ServiceChips({required this.controller});

  final AnimationController controller;

  static const List<_ChipData> _items = <_ChipData>[
    _ChipData(Icons.plumbing_rounded, 'Plumbing', 0.20),
    _ChipData(Icons.electrical_services_rounded, 'Electrical', 0.27),
    _ChipData(Icons.hvac_rounded, 'HVAC', 0.34),
    _ChipData(Icons.cleaning_services_rounded, 'Cleaning', 0.40),
    _ChipData(Icons.format_paint_rounded, 'Painting', 0.46),
    _ChipData(Icons.handyman_rounded, 'Carpentry', 0.52),
    _ChipData(Icons.pest_control_rounded, 'Pest Control', 0.58),
    _ChipData(Icons.local_shipping_rounded, 'Moving', 0.66),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _items
          .map(
            (item) => _Reveal(
              controller: controller,
              intervalStart: item.intervalStart,
              child: _ServiceChip(item: item),
            ),
          )
          .toList(),
    );
  }
}

class _ChipData {
  const _ChipData(this.icon, this.label, this.intervalStart);

  final IconData icon;
  final String label;
  final double intervalStart;
}

class _ServiceChip extends StatefulWidget {
  const _ServiceChip({required this.item});

  final _ChipData item;

  @override
  State<_ServiceChip> createState() => _ServiceChipState();
}

class _ServiceChipState extends State<_ServiceChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3EDE7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ServioColors.accent.withValues(alpha: 0.20)),
          ),
          child: SizedBox(
            height: ServioSpacing.tapTarget,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(widget.item.icon, color: ServioColors.navyDark, size: 20),
                  const SizedBox(width: 7),
                  Text(
                    widget.item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ServioColors.navyDark,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEAE8E5)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PressableButton(
              label: 'Create Account',
              onPressed: onCreateAccount,
              backgroundColor: ServioColors.navyDark,
              foregroundColor: Colors.white,
              shadowColor: ServioColors.navyDark.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            _PressableButton(
              label: 'Sign In',
              onPressed: onSignIn,
              backgroundColor: Colors.transparent,
              foregroundColor: ServioColors.navyDark,
              borderColor: ServioColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.shadowColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: widget.borderColor == null
                ? null
                : Border.all(color: widget.borderColor!, width: 2),
            boxShadow: widget.shadowColor == null
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: widget.shadowColor!,
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: SizedBox(
            height: ServioSpacing.tapTarget,
            child: Center(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: widget.foregroundColor,
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return child;

    final end = (intervalStart + 0.34).clamp(0.0, 1.0).toDouble();

    // Fade + slide: spring curve for smooth entry
    final entranceAnim = CurvedAnimation(
      parent: controller,
      curve: Interval(intervalStart, end, curve: ServioMotion.spring),
    );

    // Scale: elasticOut for a satisfying pop-bounce
    final scaleAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(intervalStart, end, curve: Curves.elasticOut),
      ),
    );

    return FadeTransition(
      opacity: entranceAnim,
      child: ScaleTransition(
        scale: scaleAnim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).animate(entranceAnim),
          child: child,
        ),
      ),
    );
  }
}
