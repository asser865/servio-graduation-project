# Auth UI Redesign — Dark Immersion

**Date:** 2026-05-06  
**Branch:** mostafabdelaal/mobile-app-test-enhancements  
**Status:** Approved — ready for implementation

---

## Summary

Redesign the five auth screens to a "Dark Immersion" style — a full dark gradient background in dark mode and a dark brand gradient header anchoring a warm cream body in light mode. All five screens share identical layout structure; only the card surface, text colours, and button style swap between modes.

Business logic, navigation, state management, and existing provider calls are **not changed**.

---

## Screens in Scope

| # | File | Current State |
|---|------|---------------|
| 1 | `auth_landing_screen.dart` | Gradient header + empty cream body + 2 buttons |
| 2 | `role_selection_screen.dart` | Gradient header + light role cards + Continue |
| 3 | `login_screen.dart` | Gradient header + ServioCard form |
| 4 | `sign_up_screen.dart` Step 0 (basic info) | Light card, 4 fields |
| 5 | `sign_up_screen.dart` Step 1 (OTP) | Light card, OTP input |

Sign Up Steps 2+ (city/terms, skills, service area, rate, docs, confirmation) are **out of scope** — they stay on the existing light cream theme.

---

## Light / Dark Mode Strategy

### Dark mode
- **Background:** Full-screen gradient `ServioGradients.brand` (deepBrown `#3C2415` → navyDark `#222831`) extended with a deep blue-dark bottom fade
- **Card surface:** `rgba(255,255,255,0.07)` + `1px rgba(255,255,255,0.11)` border + `borderRadius: ServioRadius.lg` (18)
- **Input fields:** `rgba(255,255,255,0.07)` fill, `rgba(255,255,255,0.10)` border; active state → `rgba(154,140,115,0.10)` fill, `rgba(154,140,115,0.60)` border
- **Primary text:** `Colors.white`
- **Secondary text:** `rgba(255,255,255,0.40)`
- **Accent / links:** `ServioColors.accentLight` (`#BFB09A`)
- **CTA button:** `ServioGradients.accent` (existing `ServioPrimaryButton`)
- **Outline button:** `1px rgba(255,255,255,0.22)` border, white text 0.75 opacity

### Light mode
- **Background:** `ServioColors.backgroundLight` (`#FAF8F5`) — cream
- **Header:** `ServioGradients.brand` (same dark gradient) occupies the top section, curves into the cream body with a 22px rounded bottom edge
- **Card surface:** `Colors.white` + `1px ServioColors.borderLight` border + `ServioShadows.elevated`
- **Input fields:** standard `ServioTheme` `InputDecoration` (already styled for light)
- **Primary text:** `ServioColors.textPrimaryLight` (`#222831`)
- **Secondary text:** `ServioColors.textSecondaryLight` (`#6B6560`)
- **Accent / links:** `ServioColors.accent` (`#9A8C73`)
- **CTA button:** `background: ServioColors.deepBrown` (`#3C2415`), white text
- **Outline button:** `1.5px ServioColors.deepBrown` border, deepBrown text

Both modes share: progress bar gradient, animation curves, role card shape, back button shape, section label style.

---

## Screen-by-Screen Design

### 1. `auth_landing_screen.dart`

**Dark mode layout (top → bottom):**
1. Status bar area
2. Brand mark — 52×52 frosted circle, person icon, `SERVIO` in `headlineLarge w900 letterSpacing:3.5`, `PREMIUM HOME SERVICES` caption
3. Two trust-pill rows — glass pill (`rgba(255,255,255,0.06)`, 1px border, 8px radius), 20×20 icon box left, text right
   - "Verified professionals" (shield icon)
   - "Top-rated every time" (star icon)
4. CTA group — `ServioPrimaryButton` ("SIGN IN"), then outline button ("CREATE ACCOUNT")

**Light mode layout:**  
Same structure. Brand mark + tagline sit inside the dark gradient header. Trust pills render below the curve in the cream body using `pill-l` style (white fill, `#E8DDD5` border). CTA uses deepBrown fill + deepBrown outline.

**Entrance animation:** existing `_entranceController` SlideTransition + FadeTransition retained unchanged.

---

### 2. `role_selection_screen.dart`

**Dark mode layout:**
1. Status bar
2. Back button (28×28 frosted circle, chevron icon)
3. Bold heading — `"How will you\nuse SERVIO?"` `headlineLarge w900`, subtitle `bodySmall 0.40 opacity`
4. Two role cards (glass `rgba(255,255,255,0.07)`) — icon box 36×36, title `titleMedium w800`, subtitle `bodySmall 0.40`, radio check circle right edge
   - Selected: `border-color rgba(154,140,115,0.55)`, `background rgba(154,140,115,0.10)`, check filled with `#BFB09A` checkmark
   - Unselected: default glass, empty circle
5. Continue CTA — `ServioPrimaryButton`, 50% opacity when no role selected (existing `AnimatedOpacity` kept)

**Light mode layout:**  
Heading + back button live inside the gradient header. Role cards render below the curve on cream, using white fill + `#E8DDD5` border. Selected card gets `#9A8C73` border + `rgba(154,140,115,0.07)` tint.

**Existing animation:** `_entranceController` SlideTransition retained.

---

### 3. `login_screen.dart`

**Dark mode layout:**
1. Status bar
2. Back button (28×28 frosted circle)
3. Bold heading — `"Welcome\nback."` `displayLarge w900` (or headlineLarge), subtitle `bodySmall 0.40 opacity`
4. Glass credentials card:
   - Section label `"YOUR CREDENTIALS"` — `labelSmall uppercase letterSpacing:0.9, accent 0.65 opacity`
   - Email field (prefix: mail icon) — dark field style
   - Password field (prefix: lock icon, suffix: visibility toggle) — dark field style
   - Remember me row (animated checkbox) + "Forgot password?" link (`#BFB09A`)
   - `ServioPrimaryButton` ("LOG IN")
5. "or continue with" divider row
6. Social buttons row (Google + Apple) — ghost buttons with `rgba(255,255,255,0.05)` fill
7. "New to SERVIO?" + "Create account" link row

**Light mode layout:**  
Heading + back button inside gradient header. White elevated card below the curve. Social buttons use white fill + `#DDD5CC` border. Links use `#3C2415`.

**Retained:** `_AnimatedCheckbox`, `_ErrorBanner`, `_login()` logic, `SessionProvider` calls, `_showPendingDialog()`.

---

### 4. `sign_up_screen.dart` — Step 0 (Basic Info)

**Dark mode layout:**
1. Status bar
2. Progress bar — full width, 2px, `rgba(255,255,255,0.07)` track, gradient fill at `1/totalSteps * 100%`
3. Back button
4. Heading — `"Create your\naccount."` + step label `"Step 1 of N — Basic information"`
5. Glass form card:
   - Full name field
   - Phone field
   - Email field
   - Password field + visibility toggle
   - Password strength bar (4 segments, red→orange→green)
   - `ServioPrimaryButton` ("CONTINUE")
6. "or sign up with" divider
7. Social buttons row
8. "Already have an account? Sign in" link

**Light mode layout:**  
Heading inside gradient header. Progress bar below the curve in cream body. White card. deepBrown CTA.

**Retained:** All `_validateStep()`, `_continue()`, `_onFormChanged()`, controller listeners.

---

### 5. `sign_up_screen.dart` — Step 1 (OTP)

**Dark mode layout:**
1. Status bar
2. Progress bar at `2/totalSteps * 100%`
3. Back button
4. Heading — `"Verify your\nemail."` + masked email in `#BFB09A`
5. Glass OTP card:
   - Section label `"ENTER CODE"`
   - 6 OTP boxes — `_otpCtrl` driven; active box gets `rgba(154,140,115,0.12)` + accent border
   - Countdown text — `"Expires in MM:SS"` with accent colour on time
   - `ServioPrimaryButton` ("VERIFY")
6. "Didn't receive it? Resend code" link

**Light mode layout:**  
Heading + masked email inside gradient header. White OTP card below the curve. deepBrown CTA. OTP boxes: white fill, `#DDD5CC` border; active → `#3C2415` border.

**Retained:** OTP countdown timer, resend logic, `_otpCtrl`.

---

## Shared New Widget: `_DarkAuthBackground`

A `Stack`-based background widget that:
- Fills the screen with the dark gradient (dark mode) OR cream (light mode)
- In light mode: renders the gradient header as a `Positioned` top region with a rounded-bottom cutout, at a configurable height
- Accepts a `headerHeight` parameter so Landing (taller) vs Login/SignUp (shorter) can tune the header area

This replaces the copy-pasted `Positioned` gradient block in each screen.

---

## Shared New Widget: `_GlassCard` / `_ElevatedCard`

A mode-aware card that renders:
- Dark mode: `rgba(255,255,255,0.07)` fill, `rgba(255,255,255,0.11)` border, `ServioRadius.lg` radius
- Light mode: white fill, `ServioColors.borderLight` border, `ServioShadows.elevated` shadow, `ServioRadius.lg` radius

Wraps the existing `ServioCard` or replaces inline containers.

---

## Animation

All existing entrance animations (`_entranceController`, `SlideTransition`, `FadeTransition`, `Interval` curves) are **retained unchanged**. No new animations are added.

---

## Accessibility

- All interactive elements maintain ≥ 44px touch targets (existing `ServioSpacing.tapTarget`)
- Contrast ratios: white on dark gradient ≥ 4.5:1; `#222831` on `#FAF8F5` ≥ 7:1
- `_ErrorBanner` retained unchanged

---

## Out of Scope

- Sign Up Steps 2–6 (unchanged)
- `forgot_password_screen.dart` (unchanged)
- Any business logic, API calls, or state management
- Dark-mode `ServioGradients.brandDark` warm gradient — not used in auth screens (auth always uses `ServioGradients.brand`)
