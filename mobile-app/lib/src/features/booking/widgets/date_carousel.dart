// mobile-app/lib/src/features/booking/widgets/date_carousel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/servio_theme_extension.dart';
import '../../../design_system/servio_tokens.dart';

class DateCarousel extends StatelessWidget {
  const DateCarousel({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isAvailable,
    required this.monthLabel,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.canGoPrevWeek,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime) isAvailable;
  final String monthLabel;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final bool canGoPrevWeek;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navyAnchor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.backgroundDark;
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Month heading + chevrons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              monthLabel,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: navyAnchor,
              ),
            ),
            Row(
              children: <Widget>[
                _ChevronButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: canGoPrevWeek ? onPrevWeek : null,
                  navyAnchor: navyAnchor,
                ),
                const SizedBox(width: 8),
                _ChevronButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: onNextWeek,
                  navyAnchor: navyAnchor,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Date bubbles
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days.map((DateTime day) {
              final available = isAvailable(day);
              final selected = available && _isSameDate(day, selectedDate);
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: _DateBubble(
                  day: day,
                  available: available,
                  selected: selected,
                  onTap: available ? () => onDateSelected(day) : null,
                  navyAnchor: navyAnchor,
                  servio: servio,
                  isDark: isDark,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({
    required this.icon,
    required this.navyAnchor,
    this.onPressed,
  });

  final IconData icon;
  final Color navyAnchor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed != null ? 1.0 : 0.3,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF9A8C73).withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, size: 18, color: navyAnchor),
        ),
      ),
    );
  }
}

class _DateBubble extends StatefulWidget {
  const _DateBubble({
    required this.day,
    required this.available,
    required this.selected,
    required this.onTap,
    required this.navyAnchor,
    required this.servio,
    required this.isDark,
  });

  final DateTime day;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;
  final Color navyAnchor;
  final ServioThemeExtension servio;
  final bool isDark;

  @override
  State<_DateBubble> createState() => _DateBubbleState();
}

class _DateBubbleState extends State<_DateBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateKeyStr = _dateKey(widget.day);
    final stateLabel = widget.available ? 'available' : 'unavailable';

    return Semantics(
      button: true,
      enabled: widget.available,
      selected: widget.selected,
      label:
          '${DateFormat('EEE, MMM d').format(widget.day)}'
          '${widget.available ? '' : ' unavailable'}',
      child: GestureDetector(
        onTapDown:
            widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
        onTapUp:
            widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: ServioMotion.fast,
          curve: ServioMotion.spring,
          child: AnimatedContainer(
            key: ValueKey<String>('booking-date-$dateKeyStr-$stateLabel'),
            duration: ServioMotion.fast,
            curve: ServioMotion.spring,
            width: 46,
            height: 68,
            decoration: BoxDecoration(
              gradient: widget.selected ? ServioGradients.brand : null,
              color: widget.selected
                  ? null
                  : widget.available
                      ? (widget.isDark
                          ? theme.colorScheme.surface
                          : Colors.white)
                      : widget.servio.backgroundSoft,
              borderRadius: BorderRadius.circular(ServioRadius.full),
              border: Border.all(
                color: widget.selected
                    ? Colors.transparent
                    : widget.available
                        ? const Color(0xFF9A8C73).withValues(alpha: 0.2)
                        : widget.servio.border.withValues(alpha: 0.35),
              ),
              boxShadow: widget.selected
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color.fromRGBO(26, 29, 37, 0.12),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Opacity(
              opacity: widget.available ? 1.0 : 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      DateFormat('E').format(widget.day),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: widget.selected
                            ? Colors.white.withValues(alpha: 0.8)
                            : widget.servio.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.day.day}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: widget.selected
                            ? Colors.white
                            : widget.navyAnchor,
                      ),
                    ),
                    if (!widget.available) ...<Widget>[
                      const SizedBox(height: 1),
                      Text(
                        'Off',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: widget.servio.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
