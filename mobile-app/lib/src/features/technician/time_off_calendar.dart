import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

/// Calendar card that lets a technician mark specific dates as time off.
///
/// Displays a 60-day forward window. Dates whose weekday is absent from
/// [availability] are shown disabled. Tapping a selectable date calls
/// PATCH /users/me/blocked-dates via [SessionProvider.toggleBlockedDate].
/// Uses optimistic UI: the cell flips immediately and reverts on error.
class TimeOffCalendarCard extends StatefulWidget {
  const TimeOffCalendarCard({
    required this.availability,
    required this.blockedDates,
    required this.locale,
    super.key,
  });

  final List<AvailabilitySlot> availability;
  final List<String> blockedDates;
  final String locale;

  @override
  State<TimeOffCalendarCard> createState() => _TimeOffCalendarCardState();
}

class _TimeOffCalendarCardState extends State<TimeOffCalendarCard> {
  late final DateTime _today;
  late final DateTime _maxDate;
  late final List<DateTime> _months;
  late final PageController _pageController;

  late Set<String> _blocked;
  final Set<String> _inFlight = {};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _maxDate = _today.add(const Duration(days: 60));
    _months = _buildMonths();
    _pageController = PageController();
    _blocked = Set<String>.from(widget.blockedDates);
  }

  @override
  void didUpdateWidget(TimeOffCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from parent only when no toggle is in-flight to avoid
    // overwriting the optimistic UI while the PATCH is pending.
    if (_inFlight.isEmpty && widget.blockedDates != oldWidget.blockedDates) {
      setState(() {
        _blocked = Set<String>.from(widget.blockedDates);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<DateTime> _buildMonths() {
    final first = DateTime(_today.year, _today.month, 1);
    final last = DateTime(_maxDate.year, _maxDate.month, 1);
    return first == last ? <DateTime>[first] : <DateTime>[first, last];
  }

  static String _fmt(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _weekdayKey(DateTime date) {
    const keys = <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return keys[date.weekday - 1]; // DateTime.weekday: Mon=1 … Sun=7
  }

  bool _isInSchedule(DateTime date) {
    final key = _weekdayKey(date);
    return widget.availability.any((slot) => slot.day.toLowerCase() == key);
  }

  bool get _hasOffScheduleBlocked => _blocked.any((s) {
        try {
          final parts = s.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          return !_isInSchedule(date);
        } catch (_) {
          return false;
        }
      });

  // ── Toggle ───────────────────────────────────────────────────────────────

  Future<void> _onDateTap(DateTime date) async {
    final key = _fmt(date);
    if (_inFlight.contains(key)) return;

    final wasBlocked = _blocked.contains(key);

    // Optimistic update.
    setState(() {
      if (wasBlocked) {
        _blocked.remove(key);
      } else {
        _blocked.add(key);
      }
      _inFlight.add(key);
    });

    final session = context.read<SessionProvider>();
    final error = await session.toggleBlockedDate(key);
    if (!mounted) return;

    setState(() {
      _inFlight.remove(key);
      if (error != null) {
        // Revert the optimistic update.
        if (wasBlocked) {
          _blocked.add(key);
        } else {
          _blocked.remove(key);
        }
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: context.servio.danger,
      ));
    } else {
      final msg = wasBlocked
          ? 'Date restored to working schedule.'
          : 'Date marked as time off.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Header ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ServioColors.tint(servio.accent),
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                ),
                child: Icon(
                  Icons.event_busy_rounded,
                  color: servio.accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Time off',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Block specific dates when you cannot accept bookings.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a date to mark it as time off. Showing next 60 days.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 14),

          // ── Empty schedule guard ────────────────────────────────────────
          if (widget.availability.isEmpty)
            _NoticeChip(
              message:
                  'Set your weekly schedule above before blocking specific dates.',
              color: servio.info,
            )
          else ...<Widget>[
            // ── Month navigation ─────────────────────────────────────────
            _MonthNav(
              months: _months,
              currentPage: _currentPage,
              controller: _pageController,
              onChanged: (p) => setState(() => _currentPage = p),
            ),
            const SizedBox(height: 10),

            // ── Weekday labels ───────────────────────────────────────────
            _WeekdayRow(secondary: servio.textSecondary),
            const SizedBox(height: 6),

            // ── Calendar grid pages ──────────────────────────────────────
            SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _months.length,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemBuilder: (_, index) => _MonthGrid(
                  month: _months[index],
                  today: _today,
                  maxDate: _maxDate,
                  blocked: _blocked,
                  inFlight: _inFlight,
                  isInSchedule: _isInSchedule,
                  onTap: _onDateTap,
                ),
              ),
            ),

            // ── Off-schedule notice ───────────────────────────────────────
            AnimatedSwitcher(
              duration: ServioMotion.normal,
              child: _hasOffScheduleBlocked
                  ? Padding(
                      key: const ValueKey<String>('notice'),
                      padding: const EdgeInsets.only(top: 12),
                      child: _NoticeChip(
                        message:
                            'Some blocked dates fall outside your current schedule — they still apply on the backend.',
                        color: servio.warning,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey<String>('empty')),
            ),
            const SizedBox(height: 12),

            // ── Legend ────────────────────────────────────────────────────
            _Legend(servio: servio),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month navigation row
// ─────────────────────────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.months,
    required this.currentPage,
    required this.controller,
    required this.onChanged,
  });

  final List<DateTime> months;
  final int currentPage;
  final PageController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canBack = currentPage > 0;
    final canFwd = currentPage < months.length - 1;
    final label = DateFormat('MMMM yyyy').format(months[currentPage]);

    return Row(
      children: <Widget>[
        AnimatedOpacity(
          opacity: canBack ? 1.0 : 0.35,
          duration: ServioMotion.fast,
          child: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            visualDensity: VisualDensity.compact,
            onPressed: canBack
                ? () => controller.animateToPage(
                      currentPage - 1,
                      duration: ServioMotion.normal,
                      curve: ServioMotion.spring,
                    )
                : null,
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: ServioMotion.fast,
            child: Text(
              label,
              key: ValueKey<String>(label),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: canFwd ? 1.0 : 0.35,
          duration: ServioMotion.fast,
          child: IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            visualDensity: VisualDensity.compact,
            onPressed: canFwd
                ? () => controller.animateToPage(
                      currentPage + 1,
                      duration: ServioMotion.normal,
                      curve: ServioMotion.spring,
                    )
                : null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekday header row  (S M T W T F S)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.secondary});

  final Color secondary;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Text(
                l,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month grid (one PageView page)
// ─────────────────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.maxDate,
    required this.blocked,
    required this.inFlight,
    required this.isInSchedule,
    required this.onTap,
  });

  final DateTime month;
  final DateTime today;
  final DateTime maxDate;
  final Set<String> blocked;
  final Set<String> inFlight;
  final bool Function(DateTime) isInSchedule;
  final Future<void> Function(DateTime) onTap;

  static String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    // Leading blank cells so day 1 lands on the correct weekday column.
    // DateTime.weekday: Mon=1…Sun=7. We want Sun=col0, so Sun maps to 0.
    final leadingBlanks = month.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        mainAxisExtent: 34, // fixed cell height — fits 6 rows in 240px
      ),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (_, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();
        final day = index - leadingBlanks + 1;
        final date = DateTime(month.year, month.month, day);
        final key = _fmt(date);
        return _DateCell(
          date: date,
          today: today,
          maxDate: maxDate,
          isBlocked: blocked.contains(key),
          isInFlight: inFlight.contains(key),
          inSchedule: isInSchedule(date),
          onTap: () => onTap(date),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual date cell
// ─────────────────────────────────────────────────────────────────────────────

enum _CellState { past, offSchedule, working, timeOff }

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.today,
    required this.maxDate,
    required this.isBlocked,
    required this.isInFlight,
    required this.inSchedule,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final DateTime maxDate;
  final bool isBlocked;
  final bool isInFlight;
  final bool inSchedule;
  final VoidCallback onTap;

  _CellState get _state {
    if (date.isBefore(today) || date.isAfter(maxDate)) return _CellState.past;
    if (!inSchedule) return _CellState.offSchedule;
    if (isBlocked) return _CellState.timeOff;
    return _CellState.working;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final state = _state;
    final tappable = !isInFlight &&
        (state == _CellState.working || state == _CellState.timeOff);

    final Color bg;
    final Color border;
    final Color text;

    switch (state) {
      case _CellState.past:
        bg = servio.backgroundSoft;
        border = servio.border.withValues(alpha: 0.40);
        text = servio.textSecondary.withValues(alpha: 0.50);
      case _CellState.offSchedule:
        bg = servio.backgroundSoft;
        border = servio.border.withValues(alpha: 0.55);
        text = servio.textSecondary.withValues(alpha: 0.65);
      case _CellState.working:
        bg = theme.colorScheme.surface;
        border = servio.accent.withValues(alpha: 0.36);
        text = theme.colorScheme.onSurface;
      case _CellState.timeOff:
        bg = const Color(0xFFF1C40F);
        border = const Color(0xFFF1C40F);
        text = Colors.white;
    }

    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ServioRadius.sm),
          border: Border.all(color: border),
          boxShadow: state == _CellState.timeOff
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color.fromRGBO(241, 196, 15, 0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text(
              '${date.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: text,
                fontWeight:
                    state == _CellState.working || state == _CellState.timeOff
                        ? FontWeight.w700
                        : FontWeight.w400,
              ),
            ),
            if (isInFlight)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    // spinner color reflects the transition direction
                    isBlocked ? const Color(0xFFF1C40F) : servio.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notice chip (info / warning)
// ─────────────────────────────────────────────────────────────────────────────

class _NoticeChip extends StatelessWidget {
  const _NoticeChip({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.servio});

  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <({Color color, String label})>[
      (color: servio.accent, label: 'Working'),
      (color: servio.warning, label: 'Time off'),
      (color: servio.textSecondary, label: 'Not in schedule'),
      (color: servio.border, label: 'Past'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: item.color.withValues(alpha: 0.50)),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ],
        );
      }).toList(),
    );
  }
}
