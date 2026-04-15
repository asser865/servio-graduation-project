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
    builder: (BuildContext ctx) {
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
    // Slides up from bottom, same direction as web's translateX slide-in
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: ServioMotion.spring));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: ServioMotion.spring,
    );

    _controller.forward();
    Future<void>.delayed(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
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
    final (IconData icon, Color accentColor) = _paletteFor(widget.type);

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: servio.surfaceRaised,
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                      // 4px left-border accent strip — matches web toast design
                      border: Border(
                        left: BorderSide(color: accentColor, width: 4),
                        top: BorderSide(color: servio.border),
                        right: BorderSide(color: servio.border),
                        bottom: BorderSide(color: servio.border),
                      ),
                      boxShadow: ServioShadows.elevated,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(icon, color: accentColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style:
                                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        height: 1.4,
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
      ),
    );
  }

  (IconData, Color) _paletteFor(ServioToastType type) {
    return switch (type) {
      ServioToastType.success => (Icons.check_circle_rounded,  ServioColors.success),
      ServioToastType.warning => (Icons.warning_amber_rounded, ServioColors.warning),
      ServioToastType.info    => (Icons.info_rounded,          ServioColors.info),
      ServioToastType.danger  => (Icons.error_rounded,         ServioColors.danger),
    };
  }
}
