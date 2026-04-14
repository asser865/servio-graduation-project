import 'package:flutter/material.dart';

import '../servio_tokens.dart';

enum ServioStatusChipType { success, warning, info, danger, neutral }

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
    final scheme = switch (type) {
      ServioStatusChipType.success => (ServioColors.success, ServioColors.tint(ServioColors.success)),
      ServioStatusChipType.warning => (ServioColors.warning, ServioColors.tint(ServioColors.warning)),
      ServioStatusChipType.info => (ServioColors.info, ServioColors.tint(ServioColors.info)),
      ServioStatusChipType.danger => (ServioColors.danger, ServioColors.tint(ServioColors.danger)),
      ServioStatusChipType.neutral => (ServioColors.accent, ServioColors.tint(ServioColors.accent)),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: ServioSpacing.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.$2,
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.$1,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
