import 'package:flutter/material.dart';

import 'servio_bottom_navigation_bar.dart';

/// Shared tab shell that floats the bottom navigation bar over tab content.
///
/// Only [IndexedStack.index] changes on tab taps, so tab pages stay alive and
/// the navigation bar remains in one persistent parent scaffold.
class ServioTabShell extends StatefulWidget {
  const ServioTabShell({
    required this.items,
    required this.pages,
    this.initialIndex = 0,
    super.key,
  })  : assert(items.length == pages.length),
        assert(initialIndex >= 0),
        assert(initialIndex < items.length);

  final List<ServioBottomNavItem> items;
  final List<Widget> pages;
  final int initialIndex;

  static double bottomOverlayInsetOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_ServioTabShellScope>()
            ?.bottomOverlayInset ??
        0;
  }

  static bool isPageActiveOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_ServioTabPageScope>()
            ?.active ??
        true;
  }

  @override
  State<ServioTabShell> createState() => _ServioTabShellState();
}

class _ServioTabShellState extends State<ServioTabShell> {
  static const double _navHeight = 64;
  static const double _navMarginH = 16;
  static const double _navMarginBottom = 12;
  static const double _maxNavWidth = 560;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant ServioTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeBottom = mq.padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: 0),
            ),
            child: _ServioTabShellScope(
              bottomOverlayInset: safeBottom + _navMarginBottom + _navHeight,
              child: IndexedStack(
                index: _currentIndex,
                children: List<Widget>.generate(widget.pages.length, (index) {
                  return _ServioTabPageScope(
                    active: index == _currentIndex,
                    child: widget.pages[index],
                  );
                }),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: safeBottom + _navMarginBottom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _navMarginH),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxNavWidth),
                  child: RepaintBoundary(
                    child: ServioBottomNavigationBar(
                      items: widget.items,
                      currentIndex: _currentIndex,
                      onTap: _setCurrentIndex,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setCurrentIndex(int index) {
    if (index == _currentIndex) {
      return;
    }

    setState(() => _currentIndex = index);
  }
}

class _ServioTabShellScope extends InheritedWidget {
  const _ServioTabShellScope({
    required this.bottomOverlayInset,
    required super.child,
  });

  final double bottomOverlayInset;

  @override
  bool updateShouldNotify(_ServioTabShellScope oldWidget) {
    return bottomOverlayInset != oldWidget.bottomOverlayInset;
  }
}

class _ServioTabPageScope extends InheritedWidget {
  const _ServioTabPageScope({
    required this.active,
    required super.child,
  });

  final bool active;

  @override
  bool updateShouldNotify(_ServioTabPageScope oldWidget) {
    return active != oldWidget.active;
  }
}
