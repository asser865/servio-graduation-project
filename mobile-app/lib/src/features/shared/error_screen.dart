import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_home_screen.dart';

class ErrorScreen extends StatefulWidget {
  const ErrorScreen({
    super.key,
    this.title = 'Page Not Found',
    this.body = 'The screen you requested could not be found.',
    this.code = '404',
  });

  final String title;
  final String body;
  final String code;

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 2),

              // ── Error code ─────────────────────────────────
              ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _entranceController,
                    curve: const Interval(0.0, 0.5,
                        curve: ServioMotion.spring),
                  ),
                ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entranceController,
                    curve: const Interval(0.0, 0.4),
                  ),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) =>
                        ServioGradients.brand.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      widget.code,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 96,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Icon ───────────────────────────────────────
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(0.2, 0.6),
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 120),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.accent),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 32,
                    color: servio.accent,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(0.3, 0.7,
                      curve: ServioMotion.spring),
                )),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entranceController,
                    curve: const Interval(0.3, 0.6),
                  ),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Body ───────────────────────────────────────
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(0.4, 0.75),
                ),
                child: Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: servio.textSecondary),
                ),
              ),

              const Spacer(flex: 1),

              // ── Buttons ────────────────────────────────────
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(0.5, 0.9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ServioPrimaryButton(
                      label: 'Go Home',
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                              builder: (_) => const CustomerHomeScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Try Again'),
                    ),
                  ],
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
