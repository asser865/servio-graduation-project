# Cost Estimator — Mobile Implementation Design

**Date:** 2026-05-07  
**Status:** Approved  
**Scope:** Flutter mobile app — `servio_graduation_project`

---

## Overview

Port the website's AI Finishing Cost Estimator to the mobile app. The website implementation at `servio_frontend/js/html/ai-estimator.js` uses a pure-frontend calculation (no backend endpoint). Mobile mirrors this: same formulas in Dart, same 4-step wizard, same results breakdown, same vendors.

---

## Source of Truth

| File | Role |
|------|------|
| `servio_frontend/html/ai-estimator.html` | 4-step wizard HTML layout |
| `servio_frontend/js/html/ai-estimator.js` | All calculation logic (RATES, ROOM_MULTIPLIERS, calcCosts, renderMaterials, renderVendors) |
| `mobile-app/lib/src/features/customer/ai_finishing_estimator_screen.dart` | Existing static mockup — full rewrite target |
| `mobile-app/lib/src/features/customer/customer_home_screen.dart` | Add navigation banner |

---

## Architecture

**Approach:** Option A — in-place rewrite of existing screen + home screen banner.  
No new files created. No backend changes. No feature folders.

**Files modified:**
1. `mobile-app/lib/src/features/customer/ai_finishing_estimator_screen.dart` — full rewrite
2. `mobile-app/lib/src/features/customer/customer_home_screen.dart` — add banner card

**Calculation:** Pure Dart, no API call. Formulas ported exactly from JS.  
**AI technicians:** Reuses existing `AiApi.recommend()` → `POST /api/v1/ai/recommend`.

---

## Navigation

Entry point: second banner card on home screen, below existing "AI Smart Match" banner.  
Same `_HeroBannerCard` widget, tap navigates to `AiFinishingEstimatorScreen`.

```
Home screen
├── AI Smart Match banner  (existing)
└── Cost Estimator banner  (NEW)
    icon: home_repair_service
    badge: AI POWERED
    title: Cost Estimator
    body: Estimate finishing materials, labor, and total project cost.
    cta: Try Estimator
```

---

## 4-Step Wizard Flow

### Step 1 — Room Type

6 room types matching website exactly:

| Display | Internal key | Multiplier |
|---------|-------------|------------|
| Living Room | `living-room` | 1.00 |
| Kitchen | `kitchen` | 1.35 |
| Bedroom | `bedroom` | 0.92 |
| Bathroom | `bathroom` | 1.55 |
| Office | `office` | 0.95 |
| Balcony | `balcony` | 1.20 |

- Grid 2×3 of tappable cards with room-specific icons
- Continue disabled until selection made

### Step 2 — Dimensions

- Unit toggle: Meters / Feet (existing `ServioCard` pill toggle)
- Fields: Length, Width, Ceiling Height
- Default ceiling height hint: 2.7 m
- Live preview card shows Floor Area and Wall Area, updates on each keystroke
- Validation: all three > 0; metric range 0.5–50m; ceiling 1–10m; ft converted via `× 0.3048`
- All calculations always done in metric internally
- Continue disabled until all valid

### Step 3 — Finishing Level

Three option cards (replace current budget/slider step entirely):

| Level | Internal | Labor/m² | Materials/m² | Logistics/m² | Variance |
|-------|----------|----------|--------------|--------------|----------|
| Economy | `economy` | 12 | 8 | 5 | 8% |
| Standard | `standard` | 28 | 18 | 9 | 10% |
| Premium | `premium` | 55 | 38 | 17 | 12% |

- Continue disabled until selection made

### Step 4 — Results

Calculated immediately on entering step 4. No loading state (pure math).

---

## Calculation Logic (Dart port of `calcCosts()`)

```
floorArea = length × width
wallArea  = 2 × (length + width) × height

rate      = RATES[level]
mult      = ROOM_MULTIPLIERS[roomType]

labor     = floorArea × rate.labor     × mult
materials = floorArea × rate.materials × mult
logistics = floorArea × rate.logistics × mult
total     = labor + materials + logistics
variance  = total × rate.variance

low       = (total - variance).round()
high      = (total + variance).round()
```

All values in EGP. Format: `"3,250 EGP – 3,800 EGP"`.

---

## Materials Quantities (Dart port of `renderMaterials()`)

| Material | Formula | Unit | Condition |
|----------|---------|------|-----------|
| Floor Tiles | `floorArea × 1.1` | m² | Always |
| Wall Tiles | `wallArea × 1.1` | m² | kitchen / bathroom only |
| Paint | `wallArea / 10 × 2` | L | Always (2 coats) |
| Primer | `wallArea / 12` | L | Always |
| Grout | `floorArea × 0.5` | kg | Always |
| Adhesive | `floorArea × 5` | kg | Always |

---

## Vendor Cards (Static, port of `renderVendors()`)

3 static vendors, sorted by discount descending. First is always "Best Deal".

| Vendor | Rating | Stock | Discount | Price formula |
|--------|--------|-------|----------|---------------|
| CraftHub | 4.7★ | In Stock | 8% | `materials × 0.92` |
| EliteFinish | 4.8★ | In Stock | 5% | `materials × 0.95` |
| ProBuild | 4.6★ | Limited Stock | 2% | `materials × 0.98` |

CraftHub gets accent border + `ServioStatusChip("BEST DEAL")`.

---

## AI Recommended Technicians

- Calls `POST /api/v1/ai/recommend` with `{ description: "Finishing a {roomType} with {level} quality at {floorArea} sqm" }`
- Uses existing `AiApi.recommend()` method
- Show up to 3 tech cards (name, rating, hourly rate, View button)
- Show skeleton placeholder while loading
- Hide section silently on error (matches website behavior)

---

## Results Screen Layout

```
[ServioStatusChip: ESTIMATE READY]
[Total range — large text, fade-in]
[Meta chips: room · level · area]
─────────────────────────────────
Cost Breakdown
  [Labor]     EGP xxxx  [animated bar]
  [Materials] EGP xxxx  [animated bar]
  [Logistics] EGP xxxx  [animated bar]
─────────────────────────────────
Estimated Materials
  [table rows: material · qty · note]
─────────────────────────────────
Vendor Quotes
  [CraftHub - BEST DEAL][EliteFinish][ProBuild]
─────────────────────────────────
Recommended Technicians    (if API returns results)
  [TechCard][TechCard][TechCard]
─────────────────────────────────
[disclaimer text]
[Reset button]
```

---

## Animations

All Flutter built-ins, no new packages.

| Element | Animation | Trigger |
|---------|-----------|---------|
| Step transitions | `AnimatedSwitcher` (existing) | Step change |
| Progress bar | `AnimatedContainer` (existing) | Step change |
| Results card entry | `FadeTransition` + `SlideTransition` (y +20→0) | Enter step 4 |
| Breakdown bars | `TweenAnimationBuilder` (0→target, 600ms, easeOut, stagger 100ms) | After 300ms delay |
| Finish level chips | `AnimatedContainer` (color/gradient) | Selection |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Room type | Required — one of 6 |
| Length / Width | Required, > 0, ≤ 50m (or ≤ 164ft) |
| Height | Required, > 0, 1–10m (or 3.3–33ft) |
| Finish level | Required — one of 3 |
| Numeric fields | `double.tryParse` — reject invalid text inline |

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| AI recommend API fails | Hide technician section silently |
| Numeric input invalid | Inline validation message, block Continue |
| Network error on techs | Snackbar: "Could not load recommended technicians." |

---

## Out of Scope

- Backend cost estimation endpoint (not needed — pure client calculation)
- Multiple rooms (website does not support it)
- Real vendor pricing (website uses static mock data — mobile matches this)
- Currency conversion (EGP only, matches website)
