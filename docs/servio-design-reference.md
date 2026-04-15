# SERVIO — Complete Frontend Design Reference for Mobile Implementation

---

## 1. Executive Summary

SERVIO is a premium home-services marketplace with a warm, editorial brand identity rooted in deep-navy and earth-brown tones on a warm-white background. The design system is hand-built in vanilla CSS using a token-first architecture (`variables.css` as the canonical source of truth), with no third-party UI framework. It is production-quality with full light/dark mode switching, Arabic RTL support, scroll-driven animations, glassmorphism patterns, and a comprehensive component library.

The overarching aesthetic can be summarised in four words: **warm, premium, editorial, calm.**

---

## 2. Brand / Style Overview

### Brand personality
- **Warm and trustworthy** — earthy palette (brown, sand, beige) communicates reliability and craftsmanship
- **Premium without being cold** — not a minimalist white SaaS product; tactile warmth
- **Editorial depth** — uses Playfair Display for big display type, giving a magazine-quality feel to hero sections
- **Technologically capable** — dark glassmorphism panels on AI/dashboard pages signal sophistication
- **Accessible and bilingual** — English/Arabic with full RTL support baked in

### Visual style keywords
Warm minimalism · editorial serif display · frosted-glass navigation · earth-tone accent palette · dark-hero contrast sections · smooth easing animations · layered depth via shadows and blur

### Recurring brand motifs
1. **Floating pill navigation bar** — frosted glass, border-radius 999px, elevated on scroll
2. **Brand gradient** — `linear-gradient(135deg, #3C2415, #222831)` (dark mode inverts to warm beige gradient)
3. **Splash screen** — full-black, letter-by-letter "SERVIO" reveal with a gradient progress bar
4. **Animated blob backgrounds** — blurred radial gradients used on auth pages and CTA sections
5. **`data-reveal` scroll animations** — elements enter with opacity 0→1 + translateY(26px)→0 + blur(7px)→0

### Design principles (inferred)
- **Depth over flatness** — layers of blur, shadows, and transparency rather than hard flat surfaces
- **Motion as feedback** — every interactive element has a 3D push/pull transform on hover/active
- **Typography does the heavy lifting** — type scale is expressive enough that illustration is not needed
- **Dark sections as contrast beats** — hero, auth showcase, footer, and AI panels use near-black backgrounds to create visual rhythm in a predominantly light page

---

## 3. Color Palette

### Light Mode (canonical — variables.css)

| Token                  | Hex                      | Semantic role                                          |
|------------------------|--------------------------|--------------------------------------------------------|
| --color-primary        | #222831                  | Dark navy — primary brand, active nav, primary button fill |
| --color-secondary      | #393E46                  | Softer navy — hover states, secondary text elements    |
| --color-accent         | #9A8C73                  | Warm taupe/tan — active badges, hovers, lines          |
| --color-neutral        | #E3D5CA                  | Warm sand — chip bg, skeleton fills, decorative        |
| --color-navy           | #222831                  | Alias for primary                                      |
| --color-brown          | #3C2415                  | Deep brown — gradient start, auth showcase bg          |
| --color-brown-light    | #5C3D2E                  | Medium brown — gradient stops                          |
| --color-text           | #222831                  | Body text                                              |
| --color-text-light     | #6B6560                  | Muted/secondary text                                   |
| --color-bg             | #FAF8F5                  | Page background — warm off-white                       |
| --color-bg-soft        | #F3EDE7                  | Section backgrounds, slight differentiation            |
| --color-border         | #DDD5CC                  | All borders, dividers                                  |
| --color-surface        | #ffffff                  | Card/input/modal background                            |
| --color-surface-alt    | #F7F3EF                  | Slightly tinted surface                                |
| --color-surface-raised | #ffffff                  | Same as surface (elevated context)                     |

### Status / Semantic Colors

| Token               | Hex                      | Use                       |
|---------------------|--------------------------|---------------------------|
| --color-success     | #27ae60                  | Success state text/icon   |
| --color-success-bg  | rgba(39,174,96,0.12)     | Success chip/badge fill   |
| --color-warning     | #e67e22                  | Warning text/icon         |
| --color-warning-bg  | rgba(243,156,18,0.12)    | Warning chip fill         |
| --color-info        | #2980b9                  | Info text/icon            |
| --color-info-bg     | rgba(52,152,219,0.12)    | Info chip fill            |
| --color-danger      | #c0392b                  | Error/danger text         |
| --color-danger-bg   | rgba(192,57,43,0.12)     | Error chip fill           |

Hardcoded additions found in page-level CSS:
- Success: #22c55e (toast), #22c55e (utility) — slight inconsistency with #27ae60 in variables.css
- Error: #ef4444 (toast), #dc2626 (logout button)
- Info/verified: #3b82f6

### Gradients

| Token             | Value                                                                                           |
|-------------------|-------------------------------------------------------------------------------------------------|
| --gradient-brand  | linear-gradient(135deg, #3C2415, #222831)                                                      |
| --gradient-accent | linear-gradient(135deg, #9A8C73, #BFB09A)                                                      |
| --gradient-warm   | linear-gradient(135deg, #E3D5CA, #C8B9AA)                                                      |
| --gradient-hero   | linear-gradient(135deg, rgba(60,36,21,0.04), rgba(154,140,115,0.08))                           |
| --gradient-brown  | linear-gradient(135deg, #3C2415, #5C3D2E)                                                      |
| Scroll progress   | linear-gradient(90deg, #3C2415, #9A8C73)                                                       |
| Splash loader bar | linear-gradient(90deg, #3C2415, #5C3D2E, #9A8C73, #BFB09A, #E3D5CA, #BFB09A, #9A8C73)        |

### Glass / Overlay Tokens

| Token         | Light                          | Dark                         |
|---------------|--------------------------------|------------------------------|
| --glass-bg    | rgba(255,255,255,0.65)         | rgba(34,40,49,0.75)          |
| --glass-border| rgba(227,213,202,0.5)          | rgba(57,62,70,0.5)           |
| Header elevated| rgba(250,248,245,0.88)        | rgba(26,29,35,0.88)          |
| Mobile nav panel| rgba(250,248,245,0.97)       | rgba(26,29,35,0.98)          |

### Dark Mode Overrides ([data-theme="dark"])

| Token                  | Dark Hex    |
|------------------------|-------------|
| --color-primary        | #E3D5CA     |
| --color-secondary      | #9A8C73     |
| --color-accent         | #BFB09A     |
| --color-text           | #E3D5CA     |
| --color-text-light     | #9A8C73     |
| --color-bg             | #1A1D23     |
| --color-bg-soft        | #262B34     |
| --color-border         | #393E46     |
| --color-surface        | #222831     |
| --color-surface-alt    | #1E2229     |
| --color-surface-raised | #2D323B     |

### Dashboard-Specific Tokens

| Token              | Light      | Dark                      |
|--------------------|------------|---------------------------|
| --dash-page-bg     | #EDE8E2    | #17171C                   |
| --dash-card-bg     | #FFFFFF    | #222228                   |
| --dash-card-border | #E8E2DC    | rgba(255,255,255,0.07)    |
| --dash-shadow      | 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04) | 0 1px 3px rgba(0,0,0,0.3) |

---

## 4. Typography System

### Font Families

| Token            | Font              | Weights Loaded      | Use                                        |
|------------------|-------------------|---------------------|--------------------------------------------|
| --font-primary   | Inter (Google)    | 400,500,600,700,800 | Body, UI, labels, captions                 |
| --font-heading   | Poppins (Google)  | 600,700,800         | H1–H3, brand name, section titles          |
| --font-editorial | Playfair Display  | 400,500,600,700+ital| Hero display, editorial pull-quotes         |
| --font-body      | Inter (alias)     | —                   | Used in filter-bar as var(--font-body)     |
| RTL override     | Cairo (Google)    | 400,500,600,700,800 | Arabic language full override              |
| Fallback         | sans-serif / system-ui | —              | —                                          |

### Type Scale

| Role                    | Size                              | Weight | Font             | Notes                          |
|-------------------------|-----------------------------------|--------|------------------|--------------------------------|
| Splash / Brand Logo     | clamp(3rem, 6vw, 5.5rem)          | 800    | Poppins          | Splash loader only             |
| Hero H1 (editorial)     | clamp(3.2rem, 5.5vw, 4.8rem)      | 600    | Playfair Display | Marketplace / tech heroes      |
| Hero H1 (technicians)   | clamp(3rem, 5vw, 4.5rem)          | 800    | Playfair Display |                                |
| Section title           | clamp(1.6rem, 1.3rem+1.1vw, 2.2rem) | 700 | Poppins          | .section__title                |
| H1–H3 base              | Poppins                           | 700    | Poppins          | letter-spacing -0.02em         |
| Footer brand            | 1.5rem                            | 700    | Poppins          |                                |
| Brand name (header)     | 1.08rem                           | 800    | Poppins          | letter-spacing -0.04em         |
| Nav link                | 0.88rem                           | 500    | Inter            |                                |
| Body / paragraph        | 1rem (16px base)                  | 400    | Inter            | line-height 1.5                |
| Footer desc / small body| 0.85rem                           | 400    | Inter            | line-height 1.6                |
| Footer links            | 0.9rem                            | 500    | Inter            |                                |
| Label                   | —                                 | 700    | Inter            | .label class                   |
| Button (default)        | 17px                              | 600    | Inter            | mobile: 15px                   |
| Button small            | 0.875rem                          | 600    | Inter            |                                |
| Nav link (mobile)       | 0.9rem                            | 500    | Inter            |                                |
| Toast                   | 0.875rem                          | —      | Inter            |                                |
| Badge/chip label        | 0.65–0.72rem                      | 700    | Inter            | uppercase + letter-spacing     |
| Section eyebrow/overline| 0.72–0.76rem                      | 700    | Inter            | uppercase + 0.07–0.08em spacing|
| Muted/caption           | 0.85rem                           | 400    | Inter            | color: --color-text-light      |

### Special Rules
- Heading letter-spacing: -0.02em globally (Poppins headings)
- Brand name letter-spacing: -0.04em (tightest)
- Overlines/badges: UPPERCASE + letter-spacing: 0.07–0.1em
- Paragraphs: color: var(--color-text-light) by default
- Editorial display: Playfair Display italic for accent spans
- Numbers/data: use Inter weight 700

---

## 5. Spacing & Layout System

### Grid

| Token       | Value                            |
|-------------|----------------------------------|
| --container | 1200px max-width                 |
| --gutter    | 24px                             |
| Responsive  | clamp(16px, 2.5vw, 24px)        |

Grid column classes:
- .grid--2 → 2 columns, collapses to 1 at 720px
- .grid--3 → 3 columns, collapses to 2 at 720px, 1 at 520px
- .grid--4 → 4 columns, collapses to 2 at 900px, 1 at 520px

Dashboard layout:
- Sidebar expanded: 260px
- Sidebar collapsed: 72px
- Auth split: 38% / 62% (showcase / form)
- Footer grid: 2fr 1fr 1fr 1fr → 1fr 1fr at 900px → 1fr at 520px

### Section Spacing

| Context              | Padding        |
|----------------------|----------------|
| Default section      | 80px 0         |
| Mobile ≤768px        | 64px 0         |
| Mobile ≤480px        | 52px 0         |
| Hero with header     | 140px top / 80px bottom |

### Spacing Scale (from messages.css)

| Token    | Value |
|----------|-------|
| --space-1 | 4px  |
| --space-2 | 8px  |
| --space-3 | 12px |
| --space-4 | 16px |
| --space-5 | 20px |
| --space-6 | 24px |
| --space-7 | 32px |

### Border Radius Scale

| Token       | Value    | Use                                          |
|-------------|----------|----------------------------------------------|
| --radius-sm | 10px     | Inputs, small cards                          |
| --radius-md | 14px     | Toast, form fields, panels                   |
| --radius-lg | 18px     | Cards, modals                                |
| --radius-xl | 22px     | Larger panels, mobile nav                    |
| --radius-2xl| 28px     | Conversation panels (messages.css)           |
| 999px/100em | Pill     | Buttons, nav links, badges, FABs             |
| 10px        | Logo     | .brand__mark                                 |
| 12px        | Nav btns | Dashboard nav buttons                        |
| 24px        | Footer   |                                              |
| 50%         | Circle   | Avatars, social icons, FAB, back-to-top      |

### Shadows

| Token       | Value                                               | Use                   |
|-------------|-----------------------------------------------------|-----------------------|
| --shadow-sm | 0 8px 20px rgba(34,40,49,0.06)                      | Light cards           |
| --shadow-md | 0 14px 36px rgba(34,40,49,0.10)                     | Elevated cards, modals|
| --dash-shadow | 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04) | Dashboard cards |
| --dash-shadow-md | 0 4px 12px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.04) | Dashboard elevated |
| Dark shadow-sm | 0 8px 20px rgba(0,0,0,0.30)                      |                       |
| Dark shadow-md | 0 14px 36px rgba(0,0,0,0.40)                     |                       |
| Header blur | blur(22px) saturate(170%)                           | Header, mobile nav    |
| Filter bar blur | blur(16px)                                      |                       |

### Borders
- Default: 1px solid var(--color-border) (#DDD5CC)
- Input focus: 1px solid + 4px ring using color-mix(in srgb, primary 18%, transparent)
- Accent focus (filter): 1px solid var(--color-accent) + 3px ring
- Toast left accent: 4px solid (variant color)
- Hero lead border: 3px solid var(--color-accent) (left bar)

---

## 6. Component Library Breakdown

### 6.1 Buttons

Base anatomy: display: inline-flex; align-items: center; gap: 10px; border-radius: 10em (pill); font-size: 17px; font-weight: 600; padding: 1em 2em

The signature hover effect is a 3D offset press:
- Hover: translateY(-4px) translateX(-2px) + box-shadow: 2px 5px 0 0 var(--color-text)
- Active: translateY(2px) translateX(1px) + shadow removed
- Transition: all 0.3s ease-in-out

Variants:
- .btn--primary, .btn--secondary, .btn--ghost — all share same visual treatment (surface bg + text border)
- .btn--header-signup — filled with --color-primary, text --color-bg
- .btn--outline — transparent bg, 1.5px border, hover: accent border + text
- .btn--full — width: 100%
- Circle FAB (chat widget): 56×56px, radius 50%, same hover physics

Sizes:
- Default: padding: 1em 2em; font-size: 17px
- Small (.btn--sm): padding: 0.6em 1.4em; font-size: 0.875rem
- Header small: padding: 0.5em 1.2em; font-size: 0.82rem
- Mobile: font-size: 15px; padding: 0.9em 1.5em

Theme toggle button: 38×38px, border-radius: 12px, icon transitions with opacity/scale/rotate


### 6.2 Inputs & Forms

Input (.input):
- padding: 12px 12px; border-radius: 14px; border: 1px solid --color-border; background: --color-surface
- Focus: border-color tint + 4px box-shadow focus ring

Textarea: min-height: 120px; resize: vertical
Field: display: grid; gap: 6px — label above input
Form grid: gap: 12px
Label: font-weight: 700; color: var(--color-text)

Search input (filter bar):
- Full-width, pill shape border-radius: 100px
- Transparent bg, icon positioned at left: 1.5rem
- Placeholder: opacity: 0.7

Filter dropdowns (.filter-select):
- Borderless inside unified pill container
- font-size: 0.9rem; font-weight: 500


### 6.3 Cards

Technician card (.tech-card):
- Surface background, border 1px solid border
- Hover: border-color: --color-accent, translateY(-2px), heavier shadow
- Avatar: 64×64px, border-radius: 8px, grayscale filter → color on hover

Category cards: rounded panels, hover elevates and shifts border to accent
Dashboard cards: border-radius: 14px, border: 1px solid --dash-card-border, --dash-shadow
Profile cover: hero banner 420px tall, darkened overlay, avatar 150px circle with 5px border and -90px margin-top overlap


### 6.4 Navigation Bar (Header)

The floating pill header is the most recognisable SERVIO element:
- Container: fixed, full-width, transparent — pointer-events pass-through
- Inner pill (.header__inner): border-radius: 999px, glass bg rgba(250,248,245,0.68), backdrop-filter: blur(22px) saturate(170%)
- 3-column grid: 1fr auto 1fr (brand | nav | controls)
- Entrance: header-slide-in — slides down from translateY(-110%) with cubic-bezier spring
- Scroll elevated state: increases bg opacity to 0.88, heavier shadow
- Active nav pill: filled --color-primary, text --color-bg
- Mobile collapse (≤820px): hamburger appears, nav becomes fixed full-width panel border-radius: 22px that slides in with opacity + scale(0.98→1) animation


### 6.5 Dashboard Sidebar

- Expanded: 260px wide, collapses to 72px icon rail
- Transition: 0.5s cubic-bezier(0.22, 1, 0.36, 1)
- Nav buttons: padding: 12px 14px; border-radius: 12px; font-size: 0.83rem
- Active state: background: --color-primary; color: #fff
- Logout button: background: #fef2f2; color: #dc2626


### 6.6 Filter Bar / Chips

Unified pill search bar:
- Container: border-radius: 100px, glass background
- Search icon at left: 18×18px

Filter pills (.filter-pill):
- padding: 0.45rem 1.15rem; border-radius: 999px
- Inactive: transparent bg, border: 1px solid --color-border, text --color-text-light
- Active: background: --color-text; border-color: --color-text; color: --color-bg
- Hover: darkened border, slightly transparent bg

Active filter badge: 18×18px circle, background: --color-accent, white text, font-size: 0.65rem


### 6.7 Toasts

- Slide in from right: translateX(110%) → translateX(0)
- min-width: 280px; max-width: 380px; padding: 14px 16px; border-radius: 14px
- border-left-width: 4px — variant color strip
- Success: #22c55e | Error: #ef4444 | Info: --color-accent
- Stack gap: 10px
- Position: bottom-right, 24px from edges


### 6.8 Auth Screens

Layout: Split panel, 38% showcase / 62% form, full-bleed 100dvh
Showcase panel (left): Near-black #100806 with layered background — aurora ray texture + radial glow + vignette + particle network canvas animation
Form panel (right): Clean --color-bg, multi-step progress bar

Multi-step signup progress bar:
- Track: rgba(227,213,202,0.08); Fill: linear-gradient(90deg, #9A8C73, #BFB09A)

Ambient blobs: two blurred radial-gradient orbs animated with blobDrift keyframes at 18s / 22s


### 6.9 Modals / Overlays

Chat widget panel:
- Triggered by 56px circle FAB (bottom-right)
- Panel slides up from FAB, backdrop: blur(4px) + rgba(0,0,0,0.2)

Advanced filter panel:
- Expands inline via max-height 0 → 400px, opacity 0 → 1 over 320ms
- Inner card: border-radius: 14px; border: 1.5px solid --color-border; padding: 1.25rem 1.5rem


### 6.10 Badges / Status Chips

- Verified badge: background: #3B82F6; color: #fff; border-radius: 50%; 34×34px
- Filter badge count: background: --color-accent; border-radius: 99px; font-size: 0.65rem
- Status chips: semantic bg tokens at 12% opacity


### 6.11 Empty States

- text-align: center; padding: 5rem 2rem; flex-direction: column; gap: 0.75rem
- Icon opacity: 0.4
- Title: 1.1rem; font-weight: 700
- Description: 0.9rem; max-width: 340px


### 6.12 Splash / Loading Screen

- Black full-screen #000000
- SERVIO letters animate in one by one: translateY(12px) → 0 + opacity 0 → 1
- Duration: 320ms cubic-bezier(0.4, 0, 0.2, 1) per letter
- Gradient progress bar (animated gradient shift loop)
- Exit: letters morph toward header logo via CSS custom property + clip-path wipe


### 6.13 Messages / Chat UI

- App-level layout: 100dvh, no-scroll container, two-panel (contacts | chat)
- Message bubbles: max-width: min(46rem, 72%); avatar: 36px; gutter: 48px
- Top bar: border-radius: 24px; backdrop-filter: blur(18px), glass background


---

## 7. Interaction & Motion Rules

### Timing System

| Type                    | Duration | Easing                              |
|-------------------------|----------|-------------------------------------|
| Standard hover (bg/color)| 180–200ms | ease                               |
| Button hover/active     | 300ms    | ease-in-out                         |
| Scroll reveal           | 700ms    | cubic-bezier(0.2, 0.8, 0.2, 1)    |
| Sidebar collapse        | 500ms    | cubic-bezier(0.22, 1, 0.36, 1)    |
| Menu pop                | 180ms    | cubic-bezier(0.22, 1, 0.36, 1)    |
| Mobile nav open         | 220ms    | cubic-bezier(0.22, 1, 0.36, 1)    |
| Header slide-in         | 450ms    | cubic-bezier(0.22, 1, 0.36, 1)    |
| Toast slide-in          | 300ms    | cubic-bezier(0.22, 1, 0.36, 1)    |
| Theme switch            | 300ms    | ease                               |
| Filter panel expand     | 320ms / 240ms | ease                          |
| Splash letter reveal    | 320ms    | cubic-bezier(0.4, 0, 0.2, 1)      |

Dominant easing: cubic-bezier(0.22, 1, 0.36, 1) — a quick-start, overshoot-free spring.
This should be the default mobile spring curve.


### Hover States
- Buttons: 3D offset + shadow stamp effect
- Nav links: subtle translateY(-1px) lift + bg tint
- Cards: translateY(-2px) lift + heavier shadow + accent border
- Social links: translateY(-4px) scale(1.05) + accent fill
- Footer links: animated underline from left (width 0 → 100%)
- Back-to-top: expands from circle to pill with text reveal


### Scroll-Driven Behaviors
- [data-reveal] — fade + slide + blur-in on scroll intersection
  - default: translateY(26px) → 0
  - left: translateX(-26px) → 0
  - right: translateX(26px) → 0
  - scale: scale(0.96) + translateY(18px) → original
- Header elevates to frosted state on scroll
- Scroll progress bar fills at top of page


### Focus States
- Default inputs: 4px focus ring using color-mix() for adaptive tint
- Filter bar: 3px focus ring with primary at 15% opacity
- Chat FAB: 2px outline --color-accent with 2px offset

---

## 8. Screen Pattern Analysis

### 8.1 Homepage (editorial marketing)
Structure: Full-viewport dark hero → category grid → tech network dark section → metrics → CTA
Hierarchy: Big editorial headline → search bar → scroll indicator → section titles
Hero: Full-bleed image + rgba(15,10,5,0.82) gradient overlay left-to-right, text max-width 720px
Scroll progress bar: 3px top-fixed gradient strip
Side section indicators: Fixed left dots with hover-reveal labels


### 8.2 Marketplace / Technician Listing (discovery)
Structure: Hero banner → sticky filter bar → card grid → empty state
Filter bar: unified pill at top, sticky; chips row below
Card grid: 3–4 columns desktop, responsive
Results header: count left + sort dropdown right


### 8.3 Auth (login + signup)
Login: 38/62 split, showcase panel left = branding + particle canvas, form panel right
Signup: Same split, multi-step form with progress bar
Ambient animation: Blob drift in background
Mobile: showcase hidden, full-width form


### 8.4 Dashboard (customer + technician)
Layout: Sidebar rail (260px / 72px collapsed) + main content area
Background: Slightly warmer #EDE8E2 vs pure white page bg
Cards: Subtle border + very light shadow, border-radius: 14px
Sidebar nav: icon + label, active = primary fill, hover = subtle bg


### 8.5 Technician Profile
Structure: Cover photo 420px (dark overlay) → avatar overlapping cover → name/stats → content grid
Avatar: 150px circle, 5px surface border, drop shadow


### 8.6 Booking
Hero: Dark primary-coloured hero (--color-primary) with ambient glows
Breadcrumb: Translucent white on dark
Form steps: Clean white panel


### 8.7 Messages
Full-height app layout — no page scroll, internal scroll per panel
Glass top bar — workspace header
Chat bubbles — constrained max-width, avatar left


### 8.8 AI Tools (Estimator / Smart Match)
Hero: Always dark (#1e2229 / #141720), never affected by theme toggle — intentional
Header: Forced to dark context-aware variant on these pages

---

## 9. Mobile Adaptation Recommendations

### What Must Stay Visually Identical
- Brand gradient direction and colors
- Warm off-white page background (#FAF8F5)
- The 3D push/pull button effect (adapt: scale press on touch)
- Font pairing: Poppins headings + Inter body
- Glassmorphism pill patterns
- Earth-tone palette exactly as defined
- Status color semantics
- Editorial hero sections with dark overlays
- The cubic-bezier(0.22, 1, 0.36, 1) spring curve

### What to Simplify for Mobile

| Web pattern                          | Mobile equivalent                                      |
|--------------------------------------|--------------------------------------------------------|
| Floating pill header (fixed, 3-col)  | Standard app bar (surface+elevation)                   |
| Sidebar nav (260px expand/collapse)  | Bottom navigation bar (5 tabs max)                     |
| 38/62 auth split panel               | Full-screen form; optional intro screen before form    |
| Hover states (translateY, box-shadow)| Touch ripple + scale press (scale 0.96–0.97 on press)  |
| Scroll-reveal blur/fade              | Keep subtle; disable for prefers-reduced-motion        |
| Animated ambient blobs               | Static gradient on auth background (performance)       |
| 3-column filter bar                  | Horizontal scrollable chip row, search on separate row |
| Side section indicator dots          | Remove — no mobile equivalent                          |
| Back-to-top button                   | FAB or scroll-to-top gesture                           |
| Multi-column card grids              | Single column or 2 columns max on ≥414px               |
| Desktop footer grid                  | Stack all columns, accordion for links                 |


### Bottom Navigation Recommendation
5 tabs: Home | Services | Smart Match | Messages | Profile
Active tab: filled primary color icon + label.
Inactive: --color-text-light.
Background: --color-surface + subtle top border.
Height: 56–64px + env(safe-area-inset-bottom).


### Safe Area
- Always respect env(safe-area-inset-*) on iOS
- Header: add env(safe-area-inset-top) padding
- Bottom tabs: add env(safe-area-inset-bottom) padding


### Touch Targets
- Minimum 44×44pt (iOS HIG) / 48dp (Material)
- Dashboard nav items: min-height: 48dp
- Filter pills: at least 44dp tall
- Icon buttons: 44–48px minimum


### Typography Scaling for Mobile

| Web size                  | Mobile recommendation     |
|---------------------------|---------------------------|
| clamp(3.2rem–4.8rem) display | 2.4rem–3rem on small screens |
| Section title 2.2rem      | 1.8rem                    |
| Body 1rem / line-height 1.5 | Same — 16px minimum     |
| Button 17px               | 16px                      |
| Caption 0.85rem           | 0.8rem minimum (never below 12px) |


### Cards on Mobile
- Remove hover state; add pressed state
- Keep border-radius: 14–18px — same radius scale
- Use --dash-shadow level on mobile (lighter shadow)
- Maintain 1px border for surface definition


### Forms on Mobile
- Stack all fields vertically, single column
- Keep border-radius: 14px on inputs
- Keep 12px 12px padding
- Input font-size: 16px minimum (prevents iOS zoom)
- Labels above inputs (already the pattern)


### Modals / Bottom Sheets
- Modals → full-screen sheets or bottom sheets with border-radius: 22px top corners
- Advanced filter panel → full bottom sheet


---

## 10. Inferred Design Tokens (JSON)

```json
{
  "color": {
    "primary": "#222831",
    "secondary": "#393E46",
    "accent": "#9A8C73",
    "accentLight": "#BFB09A",
    "neutral": "#E3D5CA",
    "brown": "#3C2415",
    "brownLight": "#5C3D2E",
    "text": "#222831",
    "textMuted": "#6B6560",
    "bg": "#FAF8F5",
    "bgSoft": "#F3EDE7",
    "border": "#DDD5CC",
    "surface": "#ffffff",
    "surfaceAlt": "#F7F3EF",
    "success": "#22c55e",
    "successBg": "rgba(39,174,96,0.12)",
    "warning": "#e67e22",
    "warningBg": "rgba(243,156,18,0.12)",
    "info": "#2980b9",
    "infoBg": "rgba(52,152,219,0.12)",
    "danger": "#ef4444",
    "dangerBg": "rgba(192,57,43,0.12)",
    "dark": {
      "primary": "#E3D5CA",
      "secondary": "#9A8C73",
      "accent": "#BFB09A",
      "text": "#E3D5CA",
      "textMuted": "#9A8C73",
      "bg": "#1A1D23",
      "bgSoft": "#262B34",
      "border": "#393E46",
      "surface": "#222831",
      "surfaceAlt": "#1E2229",
      "surfaceRaised": "#2D323B"
    }
  },
  "gradient": {
    "brand": "linear-gradient(135deg, #3C2415, #222831)",
    "accent": "linear-gradient(135deg, #9A8C73, #BFB09A)",
    "warm": "linear-gradient(135deg, #E3D5CA, #C8B9AA)",
    "brandDark": "linear-gradient(135deg, #E3D5CA, #A68B7B)",
    "loader": "linear-gradient(90deg, #3C2415, #5C3D2E, #9A8C73, #BFB09A, #E3D5CA)"
  },
  "typography": {
    "fontHeading": "Poppins",
    "fontBody": "Inter",
    "fontEditorial": "Playfair Display",
    "fontRtl": "Cairo",
    "sizeDisplay": "40sp",
    "sizeH1": "32sp",
    "sizeH2": "24sp",
    "sizeH3": "20sp",
    "sizeBodyLg": "16sp",
    "sizeBody": "15sp",
    "sizeSm": "13sp",
    "sizeXs": "12sp",
    "sizeBadge": "10sp",
    "weightRegular": 400,
    "weightMedium": 500,
    "weightSemibold": 600,
    "weightBold": 700,
    "weightExtrabold": 800,
    "trackingTight": "-0.02em",
    "trackingTighter": "-0.04em",
    "trackingBadge": "0.08em",
    "leadingBody": 1.5,
    "leadingTight": 1.05
  },
  "spacing": {
    "s1": "4dp",
    "s2": "8dp",
    "s3": "12dp",
    "s4": "16dp",
    "s5": "20dp",
    "s6": "24dp",
    "s7": "32dp",
    "s8": "48dp",
    "sectionV": "64dp",
    "screenH": "16dp"
  },
  "radius": {
    "sm": "10dp",
    "md": "14dp",
    "lg": "18dp",
    "xl": "22dp",
    "xxl": "28dp",
    "pill": "9999dp",
    "circle": "50%",
    "card": "16dp",
    "navItem": "12dp"
  },
  "shadow": {
    "sm": "0 8 20 rgba(34,40,49,0.06)",
    "md": "0 14 36 rgba(34,40,49,0.10)",
    "card": "0 1 3 rgba(0,0,0,0.06)",
    "cardMd": "0 4 12 rgba(0,0,0,0.07)"
  },
  "motion": {
    "durationFast": "180ms",
    "durationDefault": "220ms",
    "durationMedium": "300ms",
    "durationSlow": "500ms",
    "durationSlower": "700ms",
    "easingSpring": "cubic-bezier(0.22, 1, 0.36, 1)",
    "easingStandard": "ease",
    "easingInOut": "ease-in-out",
    "easingReveal": "cubic-bezier(0.2, 0.8, 0.2, 1)"
  },
  "glass": {
    "bgLight": "rgba(255,255,255,0.65)",
    "bgDark": "rgba(34,40,49,0.75)",
    "borderLight": "rgba(227,213,202,0.5)",
    "borderDark": "rgba(57,62,70,0.5)",
    "blur": "22px saturate(170%)",
    "blurLight": "16px"
  }
}
```

---

## 11. Gaps, Inconsistencies & Recommendations

| Issue                        | Details                                                                                         | Recommendation                                          |
|------------------------------|-------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| Success color inconsistency  | --color-success: #27ae60 in variables.css, but #22c55e used in toast.css and utilities.css      | Standardise to #22c55e                                  |
| Error color inconsistency    | --color-danger: #c0392b vs #ef4444 (toast) vs #dc2626 (logout)                                 | Standardise to #ef4444; add as token                    |
| Missing --font-body token    | var(--font-body) used in filter-bar/messages but not defined in variables.css                   | Add --font-body: 'Inter', sans-serif                    |
| Missing RGB color variants   | color-mix() workarounds used; --color-primary-rgb referenced but not defined                    | Add RGB variants or use color-mix consistently          |
| --radius-2xl only in messages.css | Not in main variables                                                                      | Promote to variables.css                                |
| Dark AI sections never flip  | AI estimator hero hardcodes dark colors regardless of theme — intentional for AI brand          | Document as intentional; replicate on mobile AI screens |
| Editorial font loaded per-page | Playfair Display loaded via @import in home.css — not in main cascade                        | Load globally on mobile, or use Poppins as fallback     |

---

## Appendix A — Design DNA (One-Page Summary)

SERVIO is a warm, editorial, premium marketplace.

- Background: warm off-white #FAF8F5 — never pure white, never cold grey
- Headings: Poppins 700–800, letter-spacing -0.02em, color #222831
- Display: Playfair Display italic for hero pull-quotes and editorial accents
- Body: Inter 400/500, #6B6560 default paragraph color
- Primary action: Dark navy #222831 fill, white text, pill shape
- Accent highlight: Warm taupe #9A8C73 — borders, hovers, active chips
- Motion: Spring easing cubic-bezier(0.22, 1, 0.36, 1), 180–300ms
- Buttons push with a 3D offset shadow on hover; scale-press on mobile
- Glass panels: backdrop-filter: blur(22px), warm-tinted bg
- Dark mode: warm sand #E3D5CA replaces navy as "primary"; dark bg #1A1D23
- RTL: full Arabic support with Cairo font, logical properties

---

## Appendix B — Web → Mobile Component Mapping

| Web Component                          | Mobile Equivalent                                         |
|----------------------------------------|-----------------------------------------------------------|
| Floating pill header (fixed)           | App bar (elevated, platform-native or custom)             |
| Sidebar nav (260px/72px)               | Bottom navigation bar (5 tabs)                            |
| Nav link active pill                   | Bottom tab active icon + label fill                       |
| .btn (pill, hover stamp)               | TouchableHighlight / InkWell with scale press             |
| .input + .field + .label               | TextField with above-label pattern                        |
| .filter-pill row                       | Horizontal scrollable chip row                            |
| Filter bar unified pill                | Search bar + chips (stacked rows)                         |
| Advanced filter panel (expand)         | Bottom sheet / modal                                      |
| Toast (bottom-right, slide-in)         | Snackbar (bottom-center on mobile)                        |
| Cards grid                             | ListView / GridView, 1–2 col                              |
| Auth split panel                       | Onboarding intro screen → full-screen form                |
| Multi-step signup progress bar         | LinearProgressIndicator / StepIndicator                   |
| Chat widget FAB                        | FAB (bottom-right) opening chat screen                    |
| Chat bubble layout                     | Custom ListView with alternating alignment                |
| Dashboard sidebar + cards              | Tab-based navigation + card list                          |
| Profile cover + avatar overlap         | Stack layout, CircleAvatar with negative offset           |
| Splash loader (letter reveal)          | Lottie animation or custom animated splash                |
| Section indicator dots (fixed left)    | Remove entirely                                           |
| [data-reveal] scroll animation         | AnimatedOpacity + AnimatedSlide on scroll entry           |
| Footer (4-col grid)                    | ExpansionTile accordion sections                          |

---

## Appendix C — "Do Not Change" List

These are the most brand-defining traits. Any deviation breaks SERVIO identity:

1. #FAF8F5 warm off-white page background (light mode)
2. #222831 dark navy as the primary interactive color (light mode)
3. #9A8C73 warm taupe accent — the single unique brand color
4. The earth-tone gradient: #3C2415 → #222831
5. Poppins as the heading typeface (weight 700–800)
6. Inter as the body typeface
7. Border-radius scale (10 / 14 / 18 / 22px) — never sharp corners, never over-rounded
8. The cubic-bezier(0.22, 1, 0.36, 1) spring timing on all motion
9. The 3D press feedback on buttons (or its touch equivalent: scale press)
10. Glassmorphism pill nav pattern
11. Dark hero sections (AI features, auth showcase) remain near-black regardless of theme
12. letter-spacing: -0.02em on headings

---

## Appendix D — "Safe to Adapt" List

These patterns are web-specific and should be mobile-optimised:

1. Sidebar navigation → bottom navigation bar
2. Fixed floating pill header → standard app bar
3. Hover-driven interactions → press-driven interactions
4. Multi-column card grids → single/double column
5. Auth split panel → full-screen form with optional intro
6. [data-reveal] scroll blur-fade → simpler AnimatedOpacity slide-in
7. Section dots indicator → remove entirely
8. Footer column layout → stacked accordion
9. Desktop filter bar → bottom sheet or drawer
10. Animated ambient blobs on auth → static gradient (performance)
11. clamp() fluid type sizes → platform point/sp scale
12. Side padding gutter: 24px → 16dp mobile, 24dp tablet

---

## Appendix E — Flutter Token Implementation

```dart
// servio_tokens.dart — Canonical Design Tokens for SERVIO Mobile

import 'package:flutter/material.dart';

class ServioColors {
  // Brand
  static const primary        = Color(0xFF222831);
  static const secondary      = Color(0xFF393E46);
  static const accent         = Color(0xFF9A8C73);
  static const accentLight    = Color(0xFFBFB09A);
  static const neutral        = Color(0xFFE3D5CA);
  static const brown          = Color(0xFF3C2415);
  static const brownLight     = Color(0xFF5C3D2E);

  // Text
  static const textPrimary    = Color(0xFF222831);
  static const textMuted      = Color(0xFF6B6560);

  // Backgrounds
  static const bgPage         = Color(0xFFFAF8F5);
  static const bgSoft         = Color(0xFFF3EDE7);
  static const bgSurface      = Color(0xFFFFFFFF);
  static const bgSurfaceAlt   = Color(0xFFF7F3EF);
  static const border         = Color(0xFFDDD5CC);

  // Status
  static const success        = Color(0xFF22C55E);
  static const successBg      = Color(0x1F22C55E);
  static const warning        = Color(0xFFE67E22);
  static const warningBg      = Color(0x1FF39C12);
  static const info           = Color(0xFF2980B9);
  static const infoBg         = Color(0x1F3498DB);
  static const danger         = Color(0xFFEF4444);
  static const dangerBg       = Color(0x1FC0392B);

  // Dark mode equivalents
  static const darkPrimary    = Color(0xFFE3D5CA);
  static const darkBg         = Color(0xFF1A1D23);
  static const darkBgSoft     = Color(0xFF262B34);
  static const darkSurface    = Color(0xFF222831);
  static const darkBorder     = Color(0xFF393E46);
  static const darkText       = Color(0xFFE3D5CA);
  static const darkTextMuted  = Color(0xFF9A8C73);
}

class ServioTypography {
  static const fontHeading   = 'Poppins';
  static const fontBody      = 'Inter';
  static const fontEditorial = 'Playfair Display';
  static const fontRtl       = 'Cairo';

  // Scale (sp)
  static const double displayLg  = 40;
  static const double displayMd  = 32;
  static const double h1         = 28;
  static const double h2         = 24;
  static const double h3         = 20;
  static const double bodyLg     = 16;
  static const double body       = 15;
  static const double sm         = 13;
  static const double xs         = 12;
  static const double badge      = 10;

  // Letter spacing
  static const double trackingTight   = -0.02;
  static const double trackingTighter = -0.04;
  static const double trackingBadge   = 0.08;

  // Line heights
  static const double leadingBody     = 1.5;
  static const double leadingTight    = 1.05;
}

class ServioSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 48;
  static const double sectionV = 64;
  static const double screenH  = 16;
}

class ServioRadius {
  static const double sm     = 10;
  static const double md     = 14;
  static const double lg     = 18;
  static const double xl     = 22;
  static const double xxl    = 28;
  static const double pill   = 999;
  static const double card   = 16;
  static const double navItem = 12;
}

class ServioDuration {
  static const fast    = Duration(milliseconds: 180);
  static const normal  = Duration(milliseconds: 220);
  static const medium  = Duration(milliseconds: 300);
  static const slow    = Duration(milliseconds: 500);
  static const slower  = Duration(milliseconds: 700);
}

class ServioCurves {
  // The signature SERVIO spring — cubic-bezier(0.22, 1, 0.36, 1)
  static const Cubic spring  = Cubic(0.22, 1.0, 0.36, 1.0);
  // Scroll reveal — cubic-bezier(0.2, 0.8, 0.2, 1)
  static const Cubic reveal  = Cubic(0.2, 0.8, 0.2, 1.0);
  static const standard      = Curves.ease;
  static const inOut         = Curves.easeInOut;
}

class ServioGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C2415), Color(0xFF222831)],
  );
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9A8C73), Color(0xFFBFB09A)],
  );
  static const brandDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE3D5CA), Color(0xFFA68B7B)],
  );
  static const loader = LinearGradient(
    colors: [
      Color(0xFF3C2415),
      Color(0xFF5C3D2E),
      Color(0xFF9A8C73),
      Color(0xFFBFB09A),
      Color(0xFFE3D5CA),
    ],
  );
}
```
