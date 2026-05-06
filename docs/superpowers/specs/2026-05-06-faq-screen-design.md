# FAQ Screen — Design Spec

**Date:** 2026-05-06  
**Status:** Approved

---

## Overview

The FAQ accordion currently lives at the bottom of the Contact Us page (`contact_screen.dart`). This spec moves it to a dedicated `FaqScreen` accessible from the Legal section of both customer and technician profile pages, and removes it from Contact Us.

---

## Architecture

**New file:** `lib/src/features/marketing/faq_screen.dart` → `class FaqScreen extends StatefulWidget`

Placed in `features/marketing/` alongside `AboutScreen`, `TermsOfServiceScreen`, `PrivacyPolicyScreen` — the existing pattern for shared legal/info screens accessed from both profile pages.

No new state provider needed. Screen is self-contained (`StatefulWidget` with local `Set<int> _openIndexes` for accordion state).

---

## New FaqScreen Components

### AppBar
- Title: `'FAQ'`
- `backgroundColor: theme.scaffoldBackgroundColor` (matches other marketing screens)

### Header Section
- Kicker label: `'QUICK ANSWERS'` (styled: accent color, `labelSmall`, weight 700, letterSpacing 1.2)
- Heading: `'Frequently Asked Questions'` (`headlineLarge`)

### FAQ Items (4 items — moved from `_FaqSection`)

| Question | Answer (updated) |
|----------|-----------------|
| Booking or account issue? | "Log in to your account and use Report a Problem in your profile, or contact us via the Contact Us page. Our team will investigate and get back to you within 24 hours." *(removed "describe the issue in the contact form above" — no longer accurate on a standalone page)* |
| Want to join as a professional? | "Sign up as a technician and we will guide you through verification. It typically takes 2-3 business days to get verified." *(unchanged)* |
| How does SERVIO verify professionals? | "Every professional goes through profile review, identity verification, and skill assessment before accepting bookings." *(unchanged)* |
| Just browsing? | "Explore services and book when you are ready. You can compare professionals, read reviews, and get estimates before signing up." *(unchanged)* |

### Accordion Style
- Reuse exact `ServioCard` + `InkWell` + `AnimatedRotation` chevron pattern from `_FaqSection` in `contact_screen.dart`
- `borderColor: expanded ? servio.accent.withValues(alpha: 0.42) : null`
- Expanded answer shown in `AnimatedSize` (or equivalent) below question row

---

## Changes to `contact_screen.dart`

**Remove:**
1. `const _FaqSection()` widget call and its preceding `SizedBox(height: ServioSpacing.sectionGap)` spacer (lines ~110–112)
2. `class _FaqSection extends StatefulWidget` and `_FaqSectionState` (~lines 456–608)
3. `class _FaqItemData` (~lines 811–816)

**Do not touch** any other part of `contact_screen.dart`.

---

## Navigation Wiring — Both Profile Screens

Add a new `_NavTile` to the Legal `_MenuGroup` in both files, **after** the Privacy Policy tile:

```dart
_NavTile(
  icon: Icons.quiz_outlined,
  iconColor: context.servio.accent,
  label: 'FAQ',
  subtitle: 'Frequently asked questions',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const FaqScreen(),
    ),
  ),
),
```

Add import in both files:
```dart
import '../marketing/faq_screen.dart';
```

**Files modified:**
- `lib/src/features/customer/customer_profile_screen.dart`
- `lib/src/features/technician/technician_profile_screen.dart`

---

## Files Changed

| File | Action |
|------|--------|
| `lib/src/features/marketing/faq_screen.dart` | **Create** |
| `lib/src/features/marketing/contact_screen.dart` | **Modify** — remove `_FaqSection` and related classes |
| `lib/src/features/customer/customer_profile_screen.dart` | **Modify** — add FAQ nav tile |
| `lib/src/features/technician/technician_profile_screen.dart` | **Modify** — add FAQ nav tile |

---

## Out of Scope

- Adding new FAQ items
- Role-specific FAQ content (same 4 items for both customer and technician)
- Search or filtering within FAQ
