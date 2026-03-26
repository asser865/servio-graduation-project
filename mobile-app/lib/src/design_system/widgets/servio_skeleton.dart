import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

class ServioSkeleton extends StatefulWidget {
  const ServioSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = ServioRadius.sm,
    this.margin = EdgeInsets.zero,
  });

  final double height;
  final double width;
  final double radius;
  final EdgeInsetsGeometry margin;

  @override
  State<ServioSkeleton> createState() => _ServioSkeletonState();
}

class _ServioSkeletonState extends State<ServioSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 2), 0),
              end: Alignment(1.0 + (_controller.value * 2), 0),
              colors: <Color>[
                servio.backgroundSoft,
                servio.neutralWarm,
                servio.backgroundSoft,
              ],
              stops: const <double>[0.1, 0.45, 0.9],
            ),
          ),
        );
      },
    );
  }
}
