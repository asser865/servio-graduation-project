# Design: Mobile Time Off / Blocked Dates Calendar

**Date:** 2026-05-07
**Feature:** Add Time Off calendar block to Flutter mobile availability page
**Branch:** mostafabdelaal/mobile-backend-test

---

## Overview

Add a "Time Off" section below the weekly schedule block on the technician availability page (`AvailabilityManagerScreen`). Workers tap dates to mark them as blocked (time off); tapping again unblocks. The mobile implementation uses the existing backend route `PATCH /api/v1/users/me/blocked-dates` and `blockedDates[]` field already on the user model — no new backend work required.

---

## Architecture

### Files Modified
| File | Change |
|---|---|
| `mobile-app/lib/src/core/api/api_endpoints.dart` | Add `usersMeBlockedDates` constant |
| `mobile-app/lib/src/core/api/users_api.dart` | Add `toggleBlockedDate(date)` method |
| `mobile-app/lib/src/core/state/app_state.dart` | Add `toggleBlockedDate(date)` to `SessionProvider` |
| `mobile-app/lib/src/features/technician/availability_manager_screen.dart` | Add `TimeOffCalendarCard` below `_CoverageCard` in the scroll column |

### Files Created
| File | Purpose |
|---|---|
| `mobile-app/lib/src/features/technician/time_off_calendar.dart` | `TimeOffCalendarCard` widget — full calendar UI and toggle logic |

### No changes to
- `user_account.dart` — already parses `blockedDates: List<String>` correctly
- Backend — route, controller, and model already exist and are correct

---

## Data Flow

### Screen load
1. `AvailabilityManagerScreen.initState` calls `_loadCurrentWorkerProfile()`
2. `SessionProvider._refreshAccount()` calls `GET /users/me`
3. `UserAccount.fromBackend` parses `blockedDates` and `availability`
4. Screen passes both to `TimeOffCalendarCard` as constructor params

### Date tap
1. User taps a valid (selectable) date cell
2. `TimeOffCalendarCard` optimistically flips the cell state and adds date to `_inFlightDates`
3. Calls `SessionProvider.toggleBlockedDate(date)`
4. `UsersApi.toggleBlockedDate(date)` sends `PATCH /users/me/blocked-dates` with `{ "date": "YYYY-MM-DD" }`
5. On success: backend returns `{ blockedDates: [...] }` → `SessionProvider._setAccount(account.copyWith(blockedDates: updated))` → `notifyListeners()`
6. On failure: cell reverts to pre-tap state, SnackBar shows error message
7. `_inFlightDates` is cleared for that date in both cases

---

## API & State Layer

### `api_endpoints.dart`
```dart
static const String usersMeBlockedDates = '/users/me/blocked-dates';
```

### `users_api.dart`
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

### `app_state.dart` — SessionProvider
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

---

## Calendar Widget — `TimeOffCalendarCard`

### File: `time_off_calendar.dart`

**Widget signature:**
```dart
class TimeOffCalendarCard extends StatefulWidget {
  const TimeOffCalendarCard({
    required this.availability,   // List<AvailabilitySlot> — weekly schedule
    required this.blockedDates,   // List<String> — initial YYYY-MM-DD strings
    required this.locale,
    super.key,
  });
}
```

**Internal state:**
```dart
late DateTime _today;           // normalized to midnight, set once in initState
late DateTime _currentMonth;    // first day of displayed month
Set<String> _blocked = {};      // local mirror of blockedDates, updated optimistically
Set<String> _inFlight = {};     // dates currently awaiting API response
```

**Date window:** `_today` to `_today.add(const Duration(days: 60))`, computed once in `initState`.

**Month navigation:** `PageView` with `PageController`. Maximum 2 pages (current month + next month if day 60 extends into it). Chevron buttons call `_pageController.animateToPage(...)` with `ServioMotion.normal` duration and `ServioMotion.spring` curve.

---

## Card Layout

```
ServioCard (radius: ServioRadius.lg, padding: all(16))
  ├─ Header row
  │    ├─ Icon container (36×36, calendar_today_rounded, accent tint bg)
  │    ├─ "Time off" — titleMedium, w800
  │    └─ "Block specific dates…" — bodySmall, textSecondary
  ├─ SizedBox(height: 4)
  ├─ Helper text: "Tap a date to mark it as time off. Showing next 60 days."
  │    bodySmall, textSecondary
  ├─ SizedBox(height: 14)
  ├─ Month navigation row
  │    ├─ IconButton < (chevron_left_rounded)
  │    ├─ AnimatedSwitcher → "May 2026" (titleMedium, w700, fade 180ms)
  │    └─ IconButton > (chevron_right_rounded)
  ├─ SizedBox(height: 10)
  ├─ Weekday header row: S M T W T F S (labelSmall, textSecondary, w700)
  ├─ SizedBox(height: 6)
  ├─ PageView (fixed height: 240px — accommodates max 6 week-rows × 36px + 5 × 4px gaps)
  │    └─ per page: 7-column grid of date cells, rows aligned to top
  ├─ SizedBox(height: 12)
  ├─ AnimatedSwitcher → off-schedule notice (if any blocked dates off-schedule)
  ├─ SizedBox(height: 12)
  └─ Legend row (4 chips: Working / Time off / Not in schedule / Past)
```

---

## Date Cell States

| State | Condition | Background | Border | Text color | Tappable |
|---|---|---|---|---|---|
| Past / out of range | before today or after day 60 | `backgroundSoft` | `border @ 40%` | `textSecondary @ 50%` | No |
| Not in schedule | weekday not in `availability[]` | `backgroundSoft` | `border @ 55%` | `textSecondary @ 65%` | No |
| Working | in schedule, not blocked | `surface` | `accent @ 36%` | `onSurface` | Yes |
| Time off | in `_blocked` set | `tint(warning)` | `warning @ 28%` | `warning` | Yes |
| In-flight | in `_inFlight` set | same as current optimistic state | same | same | No |

In-flight overlay: 12px `CircularProgressIndicator`, strokeWidth 1.5, centered via `Stack`.

All cells: `AnimatedContainer`, duration `ServioMotion.fast` (180ms), curve `ServioMotion.spring`.

---

## Date Helpers (inside `time_off_calendar.dart`)

```dart
String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _weekdayKey(DateTime date) {
  const keys = [
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];
  return keys[date.weekday - 1]; // DateTime.weekday: Mon=1, Sun=7
}

bool _isInSchedule(DateTime date, List<AvailabilitySlot> availability) {
  final key = _weekdayKey(date);
  return availability.any((slot) => slot.day.toLowerCase() == key);
}
```

---

## Edge Cases

| Case | Behavior |
|---|---|
| Rapid double-tap | Cell non-tappable while in `_inFlight` — no duplicate PATCH |
| Toggle failure | Revert cell optimistic state, show SnackBar with error message |
| No weekly schedule | All cells disabled; notice: "Set your weekly schedule above before blocking dates." |
| Blocked date now off-schedule | Cell shown disabled (not-in-schedule style); warning notice appears |
| Profile load failure | Calendar receives empty `blockedDates` and renders normally; retry is handled at screen level by existing `_loadCurrentWorkerProfile` logic |
| Weekly schedule saved | Parent calls `setState` → `TimeOffCalendarCard` receives new `availability` → recomputes disabled cells |

---

## Animation Summary

| Element | Technique | Duration | Curve |
|---|---|---|---|
| Month grid slide | `PageView` (built-in direction-aware) | 220ms | `ServioMotion.spring` |
| Month label text | `AnimatedSwitcher` fade | 180ms | default |
| Date cell color | `AnimatedContainer` | 180ms | `ServioMotion.spring` |
| Off-schedule notice | `AnimatedSwitcher` fade | 220ms | default |
| Chevron enabled/disabled | `AnimatedOpacity` 1.0↔0.35 | 180ms | default |

**External packages added:** none. `intl` (date formatting) already installed. All animations use Flutter built-ins.

---

## Disabled-Date Rules (matching website)

1. Date < today → disabled
2. Date > today + 60 days → disabled
3. Date's weekday key not present in `availability[]` → disabled (not in schedule)
4. Date in `_inFlight` → temporarily non-tappable
5. All other dates → selectable (working or time-off)

---

## SnackBar Messages

| Event | Message |
|---|---|
| Date blocked successfully | "Date marked as time off." |
| Date unblocked successfully | "Date restored to working schedule." |
| Toggle failed | Backend error message or fallback connection message |

---

## Files NOT Changed

- `user_account.dart` — `blockedDates` already implemented
- All backend files — route, controller, model already correct
- `booking.service.js` — already rejects bookings on blocked dates

---

## Out of Scope

- Bulk-clear all blocked dates UI
- Past blocked dates display
- Blocked date management from customer side
- Push notifications for time-off changes
