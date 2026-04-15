import 'package:flutter/material.dart';

import '../servio_tokens.dart';

/// Full-width primary CTA button with the SERVIO brand gradient.
///
/// Implements the touch equivalent of the web's 3D-press hover effect:
/// scale presses down to 0.97 on tap, returning with the spring curve.
class ServioPrimaryButton extends StatefulWidget {
  const ServioPrimaryButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<ServioPrimaryButton> createState() => _ServioPrimaryButtonState();
}

class _ServioPrimaryButtonState extends State<ServioPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ServioMotion.fast,
      reverseDuration: ServioMotion.normal,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isEnabled ? widget.onPressed : null,
      child: ScaleTransition(
        scale: _scale,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ServioGradients.brand,
              borderRadius: BorderRadius.circular(ServioRadius.full),
              boxShadow: ServioShadows.rest,
            ),
            child: SizedBox(
              height: 52,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
