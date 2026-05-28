// mobile-app/lib/src/features/booking/widgets/time_slot_grid.dart

import 'package:flutter/material.dart';

import '../../../design_system/servio_theme_extension.dart';
import '../../../design_system/servio_tokens.dart';
import '../booking_strings.dart';

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
    required this.isDateAvailable,
  });

  final List<String> slots;
  final String selectedSlot;
  final ValueChanged<String> onSlotSelected;
  final bool isDateAvailable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navyAnchor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.backgroundDark;
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Section heading + timezone badge
        Row(
          children: <Widget>[
            Text(
              BookingStrings.timeSlots,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: navyAnchor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? ServioColors.backgroundSoftDark
                    : const Color(0xFFF3EDE7),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: const Text(
                BookingStrings.timezoneLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A8C73),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!isDateAvailable || slots.isEmpty)
          _AvailabilityNotice(servio: servio)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: ServioSpacing.tapTarget,
            ),
            itemCount: slots.length,
            itemBuilder: (BuildContext context, int index) {
              final String slot = slots[index];
              final bool selected = slot == selectedSlot;
              return _TimeChip(
                slot: slot,
                selected: selected,
                onTap: () => onSlotSelected(slot),
                navyAnchor: navyAnchor,
                servio: servio,
                isDark: isDark,
              );
            },
          ),
      ],
    );
  }
}

class _TimeChip extends StatefulWidget {
  const _TimeChip({
    required this.slot,
    required this.selected,
    required this.onTap,
    required this.navyAnchor,
    required this.servio,
    required this.isDark,
  });

  final String slot;
  final bool selected;
  final VoidCallback onTap;
  final Color navyAnchor;
  final ServioThemeExtension servio;
  final bool isDark;

  @override
  State<_TimeChip> createState() => _TimeChipState();
}

class _TimeChipState extends State<_TimeChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: AnimatedContainer(
          duration: ServioMotion.fast,
          curve: ServioMotion.spring,
          constraints: const BoxConstraints(
            minWidth: 100,
            minHeight: ServioSpacing.tapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
            color: widget.selected
                ? ServioColors.backgroundDark
                : (widget.isDark
                    ? const Color(0xFF1E2229)
                    : Colors.white),
            borderRadius: BorderRadius.circular(ServioRadius.md),
            border: Border.all(
              color: widget.selected
                  ? Colors.transparent
                  : const Color(0xFF9A8C73).withValues(alpha: 0.3),
            ),
            boxShadow: widget.selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color.fromRGBO(26, 29, 37, 0.15),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              _slotLabel(widget.slot),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.selected
                    ? Colors.white
                    : widget.navyAnchor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityNotice extends StatelessWidget {
  const _AvailabilityNotice({required this.servio});

  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.warning),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.event_busy_rounded, color: servio.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              BookingStrings.technicianUnavailable,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: servio.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _slotLabel(String value) {
  final hour = int.tryParse(value.split(':').first) ?? 0;
  final nextHour = hour + 1;
  return '${_hourLabel(hour)} - ${_hourLabel(nextHour)}';
}

String _hourLabel(int hour) {
  final normalizedHour = hour % 24;
  final suffix = normalizedHour >= 12 ? 'PM' : 'AM';
  final displayHour = normalizedHour == 0
      ? 12
      : (normalizedHour > 12 ? normalizedHour - 12 : normalizedHour);
  return '$displayHour:00 $suffix';
}
