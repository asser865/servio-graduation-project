import 'package:flutter/material.dart';

import '../servio_tokens.dart';

/// Wraps any widget in a staggered fade + slide-up entrance animation.
///
/// Useful for cards, sections, and list items that should appear with
/// a subtle motion when first rendered. Use [delay] to stagger siblings.
///
/// Example:
/// ```dart
/// ServioAnimatedEntry(
///   delay: const Duration(milliseconds: 120),
///   child: MyCard(),
/// )
/// ```
class ServioAnimatedEntry extends StatefulWidget {
  const ServioAnimatedEntry({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.yOffset = 0.035,
    super.key,
  });

  final Widget child;

  /// How long to wait before starting the animation.
  final Duration delay;

  /// Total animation duration (not including the delay).
  final Duration duration;

  /// Fractional Y offset the widget slides from (0.035 ≈ 3.5% of height).
  final double yOffset;

  @override
  State<ServioAnimatedEntry> createState() => _ServioAnimatedEntryState();
}

class _ServioAnimatedEntryState extends State<ServioAnimatedEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: ServioMotion.spring);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.yOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: ServioMotion.spring));

    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
