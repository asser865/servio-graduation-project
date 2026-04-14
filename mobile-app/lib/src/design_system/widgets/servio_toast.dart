import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

enum ServioToastType { success, warning, info, danger }

void showServioToast(
  BuildContext context, {
  required String message,
  required ServioToastType type,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (BuildContext context) {
      return _ServioToastOverlay(
        message: message,
        type: type,
        onDismissed: () => entry.remove(),
      );
    },
  );

  overlay.insert(entry);
}

class _ServioToastOverlay extends StatefulWidget {
  const _ServioToastOverlay({
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  final String message;
  final ServioToastType type;
  final VoidCallback onDismissed;

  @override
  State<_ServioToastOverlay> createState() => _ServioToastOverlayState();
}

class _ServioToastOverlayState extends State<_ServioToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ServioMotion.toast,
      reverseDuration: ServioMotion.toast,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: ServioMotion.curve));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: ServioMotion.curve);

    _controller.forward();
    Future<void>.delayed(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final palette = _paletteFor(servio, widget.type);

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: servio.surfaceRaised,
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                      border: Border.all(color: servio.border),
                      boxShadow: ServioShadows.rest,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(palette.$1, color: palette.$2),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _paletteFor(ServioThemeExtension servio, ServioToastType type) {
    return switch (type) {
      ServioToastType.success => (Icons.check_circle_rounded, servio.success),
      ServioToastType.warning => (Icons.warning_amber_rounded, servio.warning),
      ServioToastType.info => (Icons.info_rounded, servio.info),
      ServioToastType.danger => (Icons.error_rounded, servio.danger),
    };
  }
}
