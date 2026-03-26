import 'package:flutter/material.dart';

import '../servio_theme_extension.dart';
import '../servio_tokens.dart';

Future<T?> showServioBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color.fromRGBO(34, 40, 49, 0.40),
    transitionAnimationController: BottomSheet.createAnimationController(
      Navigator.of(context),
      sheetAnimationStyle: AnimationStyle(
        duration: ServioMotion.bottomSheet,
        reverseDuration: ServioMotion.micro,
      ),
    ),
    builder: (BuildContext context) {
      return ServioBottomSheet(
        child: builder(context),
      );
    },
  );
}

class ServioBottomSheet extends StatelessWidget {
  const ServioBottomSheet({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? servio.surfaceRaised : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ServioRadius.xl),
        ),
        border: Border.all(
          color: servio.border.withValues(alpha: isDark ? 0.45 : 1),
        ),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: servio.border,
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
