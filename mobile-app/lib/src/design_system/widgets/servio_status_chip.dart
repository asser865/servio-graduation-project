import 'package:flutter/material.dart';

import '../servio_tokens.dart';

enum ServioStatusChipType { success, warning, info, danger, neutral }

/// Inline status label chip. Sized to its text — not a tap target.
/// For touch targets, wrap in a GestureDetector with a min 44×44 area.
class ServioStatusChip extends StatelessWidget {
  const ServioStatusChip({
    required this.label,
    super.key,
    this.type = ServioStatusChipType.neutral,
  });

  final String label;
  final ServioStatusChipType type;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (type) {
      ServioStatusChipType.success => (ServioColors.success, ServioColors.tint(ServioColors.success)),
      ServioStatusChipType.warning => (ServioColors.warning, ServioColors.tint(ServioColors.warning)),
      ServioStatusChipType.info    => (ServioColors.info,    ServioColors.tint(ServioColors.info)),
      ServioStatusChipType.danger  => (ServioColors.danger,  ServioColors.tint(ServioColors.danger)),
      ServioStatusChipType.neutral => (ServioColors.accent,  ServioColors.tint(ServioColors.accent)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
