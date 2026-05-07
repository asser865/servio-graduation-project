# Mobile Time Off / Blocked Dates Calendar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Time Off calendar block to the technician availability page that lets workers block specific dates via `PATCH /api/v1/users/me/blocked-dates`, matching the website behavior.

**Architecture:** A new `TimeOffCalendarCard` widget in its own file reads `blockedDates` and `availability` from its constructor, manages optimistic local state, and calls `SessionProvider.toggleBlockedDate()` on cell tap. The screen passes live `account` data from `SessionProvider`. Two thin additions to `UsersApi` and `SessionProvider` wire the PATCH call through the existing API layer.

**Tech Stack:** Flutter, Dart, `intl` (already installed for `DateFormat`), `provider` (already installed), existing Servio design system tokens/widgets.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `mobile-app/lib/src/core/api/users_api.dart` | Modify | Add `toggleBlockedDate(date)` |
| `mobile-app/lib/src/core/state/app_state.dart` | Modify | Add `toggleBlockedDate(date)` to `SessionProvider` |
| `mobile-app/lib/src/features/technician/time_off_calendar.dart` | **Create** | Full calendar UI, month navigation, cell states, toggle logic |
| `mobile-app/lib/src/features/technician/availability_manager_screen.dart` | Modify | Add `TimeOffCalendarCard` below `_CoverageCard` |
| `mobile-app/test/features/technician/availability_manager_screen_test.dart` | Modify | Add three new widget tests |

> `api_endpoints.dart` already has `usersMeBlockedDates = '/users/me/blocked-dates'` — no change needed.

---

## Task 1: Add `toggleBlockedDate` to `UsersApi`

**Files:**
- Modify: `mobile-app/lib/src/core/api/users_api.dart`

- [ ] **Step 1.1 — Add the method**

Open `mobile-app/lib/src/core/api/users_api.dart` and add this method after `updateAvailableNow`:

```dart
Future<List<String>> toggleBlockedDate(String date) async {
  final response = await _client.patch(
    ApiEndpoints.usersMeBlockedDates,
    <String, dynamic>{'date': date},
  );
  final data = _client.unwrapData(response);
  return ((data['blockedDates'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();
}
```

The full updated `users_api.dart` method block (after `updateAvailableNow`, before `updateProfile`):

```dart
Future<bool> updateAvailableNow(bool isAvailable) async {
  final response = await _client.patch(
    ApiEndpoints.usersMeAvailable,
    <String, dynamic>{'isAvailable': isAvailable},
  );
  final data = _client.unwrapData(response);
  return (data['isAvailable'] as bool?) ?? isAvailable;
}

Future<List<String>> toggleBlockedDate(String date) async {
  final response = await _client.patch(
    ApiEndpoints.usersMeBlockedDates,
    <String, dynamic>{'date': date},
  );
  final data = _client.unwrapData(response);
  return ((data['blockedDates'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();
}

Future<UserAccount> updateProfile(Map<String, dynamic> fields) async {
```

- [ ] **Step 1.2 — Commit**

```bash
cd mobile-app
git add lib/src/core/api/users_api.dart
git commit -m "feat(api): add toggleBlockedDate to UsersApi"
```

---

## Task 2: Add `toggleBlockedDate` to `SessionProvider`

**Files:**
- Modify: `mobile-app/lib/src/core/state/app_state.dart`

- [ ] **Step 2.1 — Add the method**

In `mobile-app/lib/src/core/state/app_state.dart`, add this method to `SessionProvider` after `toggleAvailableNow`:

```dart
Future<String?> toggleBlockedDate(String date) async {
  try {
    final updated = await _usersApi.toggleBlockedDate(date);
    await _setAccount(_account!.copyWith(blockedDates: updated));
    return null;
  } on ApiException catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not update blocked dates. Check your connection.';
  }
}
```

- [ ] **Step 2.2 — Commit**

```bash
git add lib/src/core/state/app_state.dart
git commit -m "feat(state): add toggleBlockedDate to SessionProvider"
```

---

## Task 3: Create `time_off_calendar.dart`

**Files:**
- Create: `mobile-app/lib/src/features/technician/time_off_calendar.dart`

- [ ] **Step 3.1 — Create the file with full implementation**

Create `mobile-app/lib/src/features/technician/time_off_calendar.dart` with this content:

```dart
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
    return widget.availability
        .any((slot) => slot.day.toLowerCase() == key);
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
        bg = ServioColors.tint(servio.warning);
        border = servio.warning.withValues(alpha: 0.28);
        text = servio.warning;
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
                    isBlocked ? servio.warning : servio.accent,
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
  const _NoticeChip({required this.message, required this.color, super.key});

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
                border:
                    Border.all(color: item.color.withValues(alpha: 0.50)),
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
```

- [ ] **Step 3.2 — Commit**

```bash
git add lib/src/features/technician/time_off_calendar.dart
git commit -m "feat(ui): add TimeOffCalendarCard widget"
```

---

## Task 4: Wire `TimeOffCalendarCard` into the availability screen

**Files:**
- Modify: `mobile-app/lib/src/features/technician/availability_manager_screen.dart`

- [ ] **Step 4.1 — Add import**

At the top of `availability_manager_screen.dart`, add this import alongside the existing feature imports:

```dart
import 'time_off_calendar.dart';
```

- [ ] **Step 4.2 — Add card to the scroll column**

In the `build` method of `_AvailabilityManagerScreenState`, locate the `Column` children inside `SingleChildScrollView`. It currently ends with `_CoverageCard(...)`. Add the `TimeOffCalendarCard` after it:

Find this block (around line 368–378):
```dart
                          _CoverageCard(
                            account: account,
                            locale: locale,
                            serviceAreaController: _serviceAreaCtrl,
                            saving: _isBusy,
                            onServiceAreaChanged: () {
                              setState(() => _error = null);
                            },
                          ),
```

Replace with:
```dart
                          _CoverageCard(
                            account: account,
                            locale: locale,
                            serviceAreaController: _serviceAreaCtrl,
                            saving: _isBusy,
                            onServiceAreaChanged: () {
                              setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: 18),
                          TimeOffCalendarCard(
                            availability: account?.availability ??
                                const <AvailabilitySlot>[],
                            blockedDates: account?.blockedDates ??
                                const <String>[],
                            locale: locale,
                          ),
```

- [ ] **Step 4.3 — Hot restart the app and confirm the card renders**

Run the app on a device or simulator, log in as a technician, open the Availability tab, and scroll to the bottom. Confirm:
- "Time off" card appears below the service area card
- Current month label shows (e.g. "May 2026")
- Weekday row "S M T W T F S" is visible
- Working days (from the schedule) have accent-bordered cells
- "Save Availability" button is still pinned at the bottom

- [ ] **Step 4.4 — Commit**

```bash
git add lib/src/features/technician/availability_manager_screen.dart
git commit -m "feat(screen): wire TimeOffCalendarCard into availability screen"
```

---

## Task 5: Update tests

**Files:**
- Modify: `mobile-app/test/features/technician/availability_manager_screen_test.dart`

- [ ] **Step 5.1 — Replace the test file with the updated version**

Replace `mobile-app/test/features/technician/availability_manager_screen_test.dart` with:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servio_mobile_app/src/core/api/api_client.dart';
import 'package:servio_mobile_app/src/core/services/storage_service.dart';
import 'package:servio_mobile_app/src/core/state/app_state.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/servio_tokens.dart';
import 'package:servio_mobile_app/src/features/technician/availability_manager_screen.dart';

// Mock backend response seeded with a worker who has monday availability
// and no blocked dates.
final _workerJson = jsonEncode(<String, Object?>{
  'success': true,
  'data': <String, Object?>{
    '_id': 'worker1',
    'name': 'Test Worker',
    'email': 'test@example.com',
    'phone': '01000000000',
    'role': 'worker',
    'isAvailable': false,
    'availability': <Object?>[
      <String, String>{'day': 'monday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'tuesday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'wednesday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'thursday', 'from': '09:00', 'to': '17:00'},
      <String, String>{'day': 'friday', 'from': '09:00', 'to': '17:00'},
    ],
    'blockedDates': <String>[],
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Existing tests ────────────────────────────────────────────────────────

  testWidgets('shows one availability page title', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump();

    expect(find.text('Availability'), findsOneWidget);
  });

  testWidgets('shows day and working hours on one compact row', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump();

    final dayTop = tester.getTopLeft(find.text('Mon')).dy;
    final fromTop = tester.getTopLeft(find.text('From').first).dy;
    final untilTop = tester.getTopLeft(find.text('Until').first).dy;

    expect((fromTop - dayTop).abs(), lessThan(18));
    expect((untilTop - dayTop).abs(), lessThan(18));
  });

  // ── New Time Off tests ────────────────────────────────────────────────────

  testWidgets('Time off card appears below weekly schedule', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    // Let initState async load complete.
    await tester.pump(const Duration(milliseconds: 100));

    // Scroll until the Time off card is visible.
    await tester.scrollUntilVisible(
      find.text('Time off'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Time off'), findsOneWidget);
  });

  testWidgets('Time off card shows current month label', (tester) async {
    await tester.pumpWidget(await _wrap(const AvailabilityManagerScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.text('Time off'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final expectedLabel = DateFormat('MMMM yyyy').format(DateTime.now());
    expect(find.text(expectedLabel), findsOneWidget);
  });

  testWidgets('Time off card shows empty-schedule notice when no availability',
      (tester) async {
    // Use the empty-response mock so account has no availability slots.
    await tester.pumpWidget(
      await _wrap(const AvailabilityManagerScreen(), emptyAccount: true),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.text('Time off'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text(
        'Set your weekly schedule above before blocking specific dates.',
      ),
      findsOneWidget,
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<Widget> _wrap(
  Widget child, {
  bool emptyAccount = false,
}) async {
  final storage = await StorageService.init();
  final responseBody =
      emptyAccount ? _emptyJson : _workerJson;

  final client = ApiClient(
    storage: storage,
    httpClient: MockClient((http.Request request) async {
      return http.Response(
        responseBody,
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
    baseUrl: 'http://localhost',
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider(storage, client),
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(storage),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          ServioThemeExtension(
            backgroundSoft: Color(0xFFF5F5F5),
            surfaceAlt: Color(0xFFEEEEEE),
            surfaceRaised: Color(0xFFFFFFFF),
            textSecondary: Color(0xFF888888),
            border: Color(0xFFDDDDDD),
            accent: ServioColors.accent,
            accentLight: ServioColors.accentLight,
            neutralWarm: ServioColors.neutralWarm,
            success: ServioColors.success,
            warning: ServioColors.warning,
            info: ServioColors.info,
            danger: ServioColors.danger,
          ),
        ],
      ),
      home: child,
    ),
  );
}

final _emptyJson = jsonEncode(<String, Object?>{
  'success': true,
  'data': <String, Object?>{},
});
```

- [ ] **Step 5.2 — Run the tests**

```bash
cd mobile-app
flutter test test/features/technician/availability_manager_screen_test.dart --reporter expanded
```

Expected output:
```
✓ shows one availability page title
✓ shows day and working hours on one compact row
✓ Time off card appears below weekly schedule
✓ Time off card shows current month label
✓ Time off card shows empty-schedule notice when no availability
All tests passed!
```

- [ ] **Step 5.3 — Commit**

```bash
git add test/features/technician/availability_manager_screen_test.dart
git commit -m "test: add Time Off calendar widget tests"
```

---

## Task 6: Format, analyze, and final verification

**Files:** All modified/created files.

- [ ] **Step 6.1 — Format**

```bash
cd mobile-app
dart format lib/src/features/technician/time_off_calendar.dart \
            lib/src/features/technician/availability_manager_screen.dart \
            lib/src/core/api/users_api.dart \
            lib/src/core/state/app_state.dart
```

Expected: files formatted with no errors.

- [ ] **Step 6.2 — Analyze**

```bash
flutter analyze
```

Expected: `No issues found!`
If issues are reported, fix them before continuing.

- [ ] **Step 6.3 — Run full test suite**

```bash
flutter test
```

Expected: all tests pass. Fix any regressions before continuing.

- [ ] **Step 6.4 — Final commit**

```bash
git add -A
git commit -m "chore: format and verify Time Off calendar implementation"
```

---

## Self-Review Checklist

- [x] **`UsersApi.toggleBlockedDate`** — Task 1 ✓
- [x] **`SessionProvider.toggleBlockedDate`** — Task 2 ✓
- [x] **`TimeOffCalendarCard` widget** — Task 3 ✓
  - [x] 60-day window
  - [x] Past dates disabled
  - [x] Off-schedule dates disabled
  - [x] Working / time-off / in-flight cell states
  - [x] Optimistic toggle with revert on error
  - [x] `PATCH /users/me/blocked-dates` via existing API layer
  - [x] Month navigation with `PageView`
  - [x] `AnimatedContainer` per cell
  - [x] `AnimatedSwitcher` on month label and off-schedule notice
  - [x] `AnimatedOpacity` on chevrons
  - [x] SnackBar messages ("Date marked as time off." / "Date restored to working schedule.")
  - [x] Empty schedule notice
  - [x] Off-schedule blocked dates notice
  - [x] Legend row
  - [x] `didUpdateWidget` sync when no in-flight requests
  - [x] `_inFlight` guard prevents duplicate PATCH on rapid tap
- [x] **Screen wired** — Task 4 ✓
- [x] **Tests** — Task 5 ✓ (3 new tests + 2 existing preserved)
- [x] **Format + analyze** — Task 6 ✓
- [x] **`api_endpoints.dart`** — already had `usersMeBlockedDates`, no change needed ✓
- [x] **`user_account.dart`** — already parses `blockedDates`, no change needed ✓
- [x] **Backend** — no changes required ✓
