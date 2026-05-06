# Report a Problem Screen — Design Spec

**Date:** 2026-05-06  
**Status:** Approved

---

## Overview

Add a dedicated "Report a Problem" screen so users can submit bug reports and technical issues directly from the app. Both customer and technician profiles already show a "Report a Problem" `_NavTile` — currently wired to wrong/placeholder destinations. This spec replaces those stubs with a real screen.

---

## Architecture

**Single shared screen** at `lib/src/features/shared/report_problem_screen.dart`.  
Both roles use the same form — no functional difference warrants duplication.

Class: `ReportProblemScreen extends StatefulWidget`

No new state provider needed. The screen is self-contained (local `StatefulWidget` state only, mirrors `ContactScreen` pattern).

---

## Components

### Hero Header
- Background: `context.servio.warning` (orange) with soft opacity overlay circles (same `_SoftDisc` technique as ContactScreen hero)
- Icon: `Icons.flag_outlined` (matches profile tile icon)
- Title: "Report a Problem"
- Subtitle: "Found a bug or experiencing an issue? Let us know so we can fix it."

### Form Card (`ServioCard`)
Fields:
1. **Problem Category** (required) — `DropdownButtonFormField` with options:
   - Bug / App Crash
   - Wrong Information
   - Payment Issue
   - Account Problem
   - Other
2. **Description** (required, min 20 chars) — `TextFormField` with `maxLines: 6`, hint "Describe the issue in detail…"

No screenshot upload — `image_picker` is not a project dependency.

### Validation
- Category: must be selected
- Description: must be ≥ 20 characters
- On failed validation: inline `_errorMessage` banner (red tinted, same as ContactScreen)

### Submit Button
- `ServioPrimaryButton(label: 'Submit Report', isLoading: _isSubmitting)`
- Simulated async: `Future.delayed(700ms)` (consistent with ContactScreen)
- On success: inline `_successMessage` green banner + form clears
- Error state: inline red banner if validation fails

### Success State
Inline confirmation banner (same pattern as ContactScreen):
> "Report submitted. Our team will investigate and follow up if needed."

---

## Navigation Wiring

| File | Line | Change |
|------|------|--------|
| `features/customer/customer_profile_screen.dart` | ~107 | Replace `const MessagesScreen()` → `const ReportProblemScreen()` |
| `features/technician/technician_profile_screen.dart` | ~95 | Replace `_showPlaceholder(context, 'Report a Problem')` → `Navigator.push(MaterialPageRoute(builder: (_) => const ReportProblemScreen()))` |

Add import in both files: `import '../shared/report_problem_screen.dart';`

---

## Styling Constraints

- Use `ServioCard` for the form container
- Use `ServioPrimaryButton` for submit
- Spacing from `ServioSpacing` tokens
- Typography via `theme.textTheme.*`
- Warning color: `context.servio.warning` (orange `#E67E22`)
- Follow identical `StatefulWidget` + `_formKey` + `TextEditingController.dispose()` pattern from `ContactScreen`

---

## Out of Scope

- Screenshot/image upload (requires `image_picker` which is not in project dependencies)
- Backend API integration (simulated submit, same as ContactScreen)
- Role-specific category differences

---

## Files Changed

| File | Action |
|------|--------|
| `lib/src/features/shared/report_problem_screen.dart` | Create |
| `lib/src/features/customer/customer_profile_screen.dart` | Update navigation |
| `lib/src/features/technician/technician_profile_screen.dart` | Update navigation |
