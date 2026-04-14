# SERVIO Mobile App Design System Prompt

For: Stitch (AI-powered UI generation tool)  
Version: 1.0  
Target: Flutter  
Market: Egypt

## Role and Design Directive

You are a Senior Product Designer and Flutter UI Architect. Design a complete, production-ready mobile app called SERVIO, an AI-enhanced home services marketplace for Egypt. The app connects homeowners with verified technicians for maintenance, repairs, and finishing work.

### Design Philosophy

The app must feel calm, warm, and trustworthy, not loud, utility-like, or aggressive.

Emotional target:

- Airbnb x Notion = SERVIO

Avoid:

- Neon contractor app aesthetics
- Government utility portal aesthetics

Every screen, component, and animation decision must reinforce these brand pillars:

1. Trust: verified workers, escrow payments, transparent pricing
2. Warmth: earthy tones, soft shadows, inviting typography
3. Intelligence: AI features feel helpful, not intimidating

## Section 1: Design System

### 1.1 Color Tokens, Light Mode

| Token Name | Hex | Usage |
| --- | --- | --- |
| background | `#FAF8F5` | Screen backgrounds |
| background-soft | `#F3EDE7` | Subtle section fills |
| surface | `#FFFFFF` | Cards, modals |
| surface-alt | `#F7F3EF` | Input fills, alt cards |
| text-primary | `#222831` | Headings, body text |
| text-secondary | `#6B6560` | Captions, metadata |
| border | `#DDD5CC` | Dividers, input borders |
| accent | `#9A8C73` | Brand signature tone |
| accent-light | `#BFB09A` | Hover states, tags |
| neutral-warm | `#E3D5CA` | Skeleton, placeholders |
| deep-brown | `#3C2415` | Gradient start, icons |
| navy-dark | `#222831` | Gradient end, headings |

### 1.2 Color Tokens, Dark Mode

| Token Name | Hex |
| --- | --- |
| background | `#1A1D23` |
| background-soft | `#222831` |
| surface | `#222831` |
| surface-raised | `#2D323B` |
| text-primary | `#E3D5CA` |
| text-secondary | `#9A8C73` |
| border | `#393E46` |

### 1.3 Semantic Colors

| State | Hex | Usage Rule |
| --- | --- | --- |
| Success | `#27AE60` | Completion, verified, confirmed |
| Warning | `#E67E22` | Pending, awaiting action, alerts |
| Info | `#2980B9` | Informational notices, tips |
| Danger | `#C0392B` | Errors, cancellations, logout |

Rule:

- Each semantic color generates a 12% opacity tint version for background chips and badge fills.
- Example: success chip uses background `#27AE6020` and text `#27AE60`.

### 1.4 Gradients

Never substitute or approximate these values.

| Name | Definition | Usage |
| --- | --- | --- |
| brand-gradient | `#3C2415 -> #222831`, direction `135deg` | Primary CTA buttons, hero banners |
| accent-gradient | `#9A8C73 -> #BFB09A`, direction `135deg` | Verified badges, premium tags |
| warm-gradient | `#E3D5CA -> #C8B9AA`, direction `135deg` | Subtle section dividers, card tints |

### 1.5 Typography System

Font stack:

- Headings: Poppins
- Body and UI: Inter

| Scale Token | Size | Font | Weight | Letter Spacing |
| --- | --- | --- | --- | --- |
| display | `32sp` | Poppins | `700` | `-0.02em` |
| h1 | `24sp` | Poppins | `600-700` | `-0.02em` |
| h2 | `20sp` | Poppins | `600` | `-0.02em` |
| card-title | `16-18sp` | Poppins | `600` | `-0.01em` |
| body | `14-15sp` | Inter | `400` | `0em` |
| label | `12sp` | Inter | `500-600` | `0em` |
| caption | `12sp` | Inter | `400` | `0em` |
| metadata | `11sp` | Inter | `400` | `0em` |

Rules:

- Paragraphs and secondary text always use `text-secondary`.
- Never use pure black `#000000` for text.

### 1.6 Shape and Radius Tokens

| Token | dp | Applied To |
| --- | --- | --- |
| radius-sm | `10dp` | Inputs, chips, tags |
| radius-md | `14dp` | Standard cards, list items |
| radius-lg | `18dp` | Image cards, modals, bottom sheets |
| radius-xl | `22dp` | Featured cards, hero elements, bottom tabs |
| radius-full | `9999dp` | Pills, avatars, toggles, FABs |

### 1.7 Shadows

- At rest: `0 8px 20px rgba(34,40,49,0.06)`
- Elevated: `0 14px 36px rgba(34,40,49,0.10)`
- Dark overlay for bottom sheets: `rgba(34,40,49,0.40)`

### 1.8 Spacing System

- Screen horizontal padding: `20dp` and never break this
- Section gap: `32dp`
- Card internal padding: `16dp`
- Minimum tap target: `44 x 44dp`

## Section 2: Component Library

Build every component below as an isolated, reusable element. All screens must be composed exclusively from these components.

### 2.1 Buttons

- Full-width height: `52dp`
- Compact height: `36dp`
- Radius: `radius-full`

Variants:

- Primary: brand-gradient fill, white text, medium shadow
- Secondary: surface fill, `1.5dp` border, `text-primary`
- Outline: transparent fill, accent border, accent text
- Ghost: no fill, no border, accent text
- Danger: danger fill `#C0392B`, white text
- Loading: primary style with centered circular progress indicator and disabled interaction

### 2.2 Cards

- Base: `radius-md`, small shadow, `16dp` padding, surface background
- Elevated: `radius-lg`, medium shadow on tap or hover
- Image: `radius-lg` top corners with full-bleed image header and transparent-to-`#222831` overlay at 60% from bottom
- Featured: `radius-xl`, medium shadow, optional warm-gradient tint background
- Press behavior: shadow-sm to shadow-md plus `scale(0.98)`

### 2.3 Input Fields

- Height: `52dp`
- Radius: `radius-sm`
- Fill: `surface-alt`

States:

- Default: `1dp` border `#DDD5CC`
- Focused: `2dp` accent border `#9A8C73`
- Error: `2dp` danger border `#C0392B` plus error message below
- Filled: default border with `text-primary`

Rules:

- Label: `12sp` Inter, `text-secondary`, above field
- Error message: `11sp` Inter, danger color, below field
- Prefix icon: accent color, left-aligned inside field

### 2.4 Chips and Badges

- Verified badge: accent-gradient fill, white text, `radius-full`, checkmark icon, label `✓ Verified`
- Status chip: semantic color with 12% tint background and full-color text, `radius-full`
- Category chip: `background-soft` fill, accent text, `radius-sm`
- Emergency badge: danger 12% tint with danger text, `radius-full`
- AI badge: `✦ AI POWERED`, accent-gradient text or fill, sparkle icon prefix

### 2.5 Avatars

| Context | Size | Notes |
| --- | --- | --- |
| Inline list | `32dp` | `radius-full` |
| Card | `48dp` | `radius-full` with optional verified ring |
| Profile view | `72dp` | `radius-full` with `2dp` accent ring if verified |
| Own profile | `88dp` | `radius-full` with camera overlay icon |

Rules:

- Fallback uses initials on warm-gradient background
- Verified ring uses `2dp` solid accent `#9A8C73`

### 2.6 Bottom Sheets

- Top radius: `radius-xl`
- Drag handle: `40 x 4dp`, border color
- Background: `surface` in light mode, `surface-raised` in dark mode
- Overlay: `rgba(34,40,49,0.40)`
- Animation: spring slide-up, `cubic-bezier(0.2,0.8,0.2,1)`, `400ms`

### 2.7 Toast Notifications

- Slide up from bottom
- Background: `surface-raised`
- Left icon colored by semantic type
- Auto-dismiss after 3 seconds
- Radius: `radius-md`

### 2.8 Skeleton Loaders

- Use shimmer animation: `background-soft -> neutral-warm -> background-soft`
- Match the exact size and shape of the real content
- Apply to cards, avatars, text lines, and buttons

### 2.9 Bottom Navigation Bar

- Top radius: `22dp`
- Shadow: brand shadow
- Height: `64dp` plus system safe area
- Active tab: accent icon and text or brand-gradient fill
- Inactive tab: `text-secondary`

## Section 3: Navigation Architecture

### Customer Role Bottom Tabs

1. Home
2. Services
3. Smart Match
4. Bookings
5. Profile

The Smart Match tab is the AI center tab and must use an accent-gradient highlight, sparkle icon, and slightly elevated larger presentation.

### Technician Role Bottom Tabs

1. Dashboard
2. Jobs
3. Earnings
4. Availability
5. Profile

### Transition Rules

- Stack navigation push and pop: slide left and right
- Tab switching: cross-fade only, never slide
- Bottom sheets: spring slide-up
- No persistent top app bar on Home or Marketplace screens
- Use inline floating headers or scroll-aware sticky bars instead

## Section 4: Motion System

- Master easing: `cubic-bezier(0.2, 0.8, 0.2, 1)`
- Duration range: `300ms` to `700ms`

| Element | Animation |
| --- | --- |
| Screen push and pop | Slide left and right, `350ms` |
| Tab switch | Cross-fade, `300ms` |
| Cards entering list | `fadeIn + translateY(16dp)` with `60ms` stagger |
| Skeleton to content | Shimmer fade from `background-soft` to `neutral-warm` |
| Availability dot | Scale pulse `1 -> 1.4 -> 1`, `1.5s` infinite |
| Success checkmark | Stroke-draw and scale bounce |
| Button press | `scale(0.98)` and shadow collapse |
| All color transitions | `300ms` ease for theme switching |
| Bottom sheet | Spring slide-up, `400ms` |
| Toast | Slide up from bottom, `300ms` |

## Section 5: Screen Specifications

Generate every screen in this exact order, and provide both light and dark mode variants. Screen horizontal padding is always `20dp`.

### Phase 1: Onboarding and Authentication

#### Screen 01: Splash Screen

- Full-screen brand-gradient background
- Centered SERVIO wordmark in `#E3D5CA`, Poppins Bold `32sp`
- Tagline below in accent, Inter `14sp`
- Mount animation: logo fades in and scales from `0.8` to `1.0` over `600ms`, then tagline fades in `300ms` later
- No navigation visible

#### Screen 02: Onboarding Slides

- Three slides
- Top 55%: full-height warm illustration
- Bottom: text content on `#FAF8F5`
- Pagination dots centered
- Active dot: accent pill
- Inactive dot: border-colored dot
- Bottom CTA: `Get Started`, full-width primary button
- Top-right skip link in ghost style

Slide content:

1. Homeowner with leaky pipe and phone, title `Find Trusted Experts`, body `Verified technicians at your fingertips.`
2. Technician arriving at a door with verified badge, title `Book with Confidence`, body `Escrow payments protect every transaction.`
3. AI sparkle over a phone mockup, title `AI Finds the Right Pro`, body `Describe your issue - we handle the match.`

#### Screen 03: Role Selection

- Centered title `How will you use SERVIO?`
- Subtitle `Choose your role to get started.`
- Two stacked full-width selection cards:
- `I Need Services`
- `I'm a Technician`
- Unselected state uses surface background and border
- Selected state uses brand-gradient fill, white icon and text, medium shadow
- Continue button is disabled until a role is selected

#### Screen 04: Login

- Centered SERVIO wordmark
- Heading `Welcome back`
- Subheading `Sign in to your account`
- Fields: email and password
- Password includes eye toggle
- `Forgot password?` ghost link aligned right
- Full-width primary login button
- Divider: `or continue with`
- Social row: Google and Apple on iOS
- Footer link: `Don't have an account? Sign Up`

#### Screen 05: Sign Up

- Multi-step and role-aware
- Shared fields: full name, email, mobile number with `+20` prefix dropdown, password, confirm password
- Password strength indicator below password
- Customer step 2: address or city selector plus agreement checkbox
- Technician step 2: specialty selector, city or service area, years of experience
- Technician step 3: hourly rate in EGP, availability segmented control, immediate-jobs toggle
- Step CTA: `Continue ->`

### Phase 2: Customer Flow

#### Screen 06: Customer Home Feed

- No persistent app bar
- Scroll-aware floating header with location pill and notification bell
- Top inline greeting, name, and search bar
- Hero AI banner card with image background and gradient overlay
- Second finishing-estimate banner card
- Services section with horizontal two-row icon grid
- Recent activity booking card
- Recommended technicians horizontal list

#### Screen 07: Services Marketplace

- Sticky top with search bar and filter button
- Horizontal category chips
- Sort dropdown
- List or grid toggle
- List cards with cover image, category, title, description, price range, rating, duration, and outline CTA
- Pinned AI recommendation promo card at top

#### Screen 08: Service Detail

- `220dp` hero image with gradient overlay
- Floating back and share actions
- Category chip, service title, AI estimate badge, display-sized price, duration chip
- Tabs: Overview, About, Reviews
- Sticky bottom action bar with `Find a Technician`

#### Screen 09: Technician Listing

- Header with result count
- Horizontal filter chips
- Sort dropdown
- Compare mechanism with per-card checkbox
- Comparison bottom bar appears when two or more are selected
- Technician cards with avatar, specialty, rating, response time, hourly rate, verified badge, and CTA

#### Screen 10: Technician Public Profile

- Collapsible cover photo
- Avatar overlapping cover edge
- Name and specialty
- Four-stat horizontal row
- Accordion sections for summary, services, portfolio, reviews, coverage, credentials, and availability
- Sticky bottom action bar with pulsing availability dot, `Book Now`, and `Message`

#### Screen 11: AI Smart Match

- Animated brand-gradient hero banner
- Centered `Powered by SERVIO AI` badge
- Title with highlighted `problem?`
- Large text area with mic and camera actions
- Quick suggestion chips
- Primary analyze button
- Loading state with AI processing animation and contextual copy
- Results state with recommended service card, top matched technicians, booking CTA, and secondary ghost action

#### Screen 12: AI Finishing Cost Estimator

- Four-step wizard with progress bar
- Step 1: room type selection grid
- Step 2: room dimensions with meters or feet segmented control and secure-processing note
- Step 3: AI cost suggestion card, finish-level segmented control, budget inputs, and range slider
- Step 4: results with estimated range, savings chip, cost breakdown bars, materials list, vendor quotes, save action, and booking CTA

#### Screen 13: Booking Step 1

- Title `Confirm Your Booking`
- Service summary card
- Selected technician mini-card with change action
- Optional job description text area
- Continue CTA

#### Screen 14: Booking Step 2

- Title `Pick a Date & Time`
- Calendar month view
- Time-slot chips for morning, afternoon, and evening
- Address field with current-location ghost action
- Continue CTA

#### Screen 15: Booking Step 3

- Title `Review & Confirm`
- Summary card with edit links
- Promo code input with inline apply action
- Payment method radio cards
- Conditional credit-card fields
- Price breakdown
- Escrow info card
- `Confirm Booking` primary CTA

#### Screen 16: Booking Confirmation

- Clean success-focused screen
- Centered success animation
- Booking reference in accent
- Details card
- Stacked actions: view details, message technician, track status
- Bottom text link back home

#### Screen 17: Booking Details

- Large status chip
- Vertical timeline stepper
- Technician mini-card with message and call
- Service and price breakdown card
- Map preview
- Conditional bottom bar for review and re-book, or cancel

#### Screen 18: My Bookings

- Sub-tabs: Active, History, Favourites
- Active uses status-color left border cards
- History shows completed cards with re-book and details actions
- Favourites shows saved technicians with filled accent heart

#### Screen 19: Messages

- Top search bar
- Conversation rows with avatar, last message preview, timestamp, and unread badge

#### Screen 20: Chat Screen

- Floating technician info bar
- Sent bubbles use brand-gradient fill with clipped corner
- Received bubbles use raised surface background with clipped corner
- Bottom input bar with attachment, camera, and circular send action

#### Screen 21: Write a Review

- Technician mini-card
- Centered experience rating prompt
- Five large stars with bounce animation on fill
- Review text area with character counter
- Optional multiselect quick tags
- Photo attachment row
- Primary submit button and ghost skip action

#### Screen 22: Customer Profile and Settings

- Centered profile header with editable avatar
- Stats row
- Grouped settings list
- Preferences include dark mode and EN or AR language toggle
- Bottom log-out action in danger color

### Phase 3: Technician Flow

#### Screen 23: Technician Dashboard

- Floating header with greeting and notifications
- Horizontal KPI cards
- Incoming job alert card with warning pulse border
- Recent activity list

#### Screen 24: Job Queue

- Sub-tabs: Pending, Confirmed, In Progress, Completed
- Count badges on tab headers
- Job cards
- Pending jobs show accept and decline
- Active jobs show detail CTA

#### Screen 25: Job Details

- Customer info card
- Job card with description, photos, map preview, schedule, and offered amount
- Primary status-update CTA with confirmation dialog

#### Screen 26: Earnings

- Period selector
- Brand-gradient earnings banner
- Earnings chart
- Transaction list

#### Screen 27: Availability Manager

- Horizontal Mon-Sun pill row
- Toggle availability by day
- Time-range controls per active day
- Save availability primary CTA

#### Screen 28: Technician Profile and Settings

- Same foundation as customer profile
- Adds specialty chips, service area, hourly rate, and verification status card

#### Screen 29: Verification Document Upload

- Three-step upload flow
- National ID, Trade License, and Insurance Certificate
- Upload states: pending, uploading, under review, verified, rejected
- Bottom `Save & Submit` primary CTA

### Phase 4: Shared Screens

#### Screen 30: Notifications

- Top-right `Mark all as read` ghost action
- Notification rows with semantic icon tint treatments
- Unread rows use `background-soft`
- Swipe left to dismiss with danger zone

#### Screen 31: Search Results

- Prefilled search bar with back arrow
- Sub-tabs: Services and Technicians
- Filter row matching marketplace
- Empty state with warm illustration, helpful copy, and Smart Match CTA

#### Screen 32: 404 and Error Screen

- Large faded error code text
- Accent error icon
- Helpful title and description
- Stacked `Go Home` and `Try Again` actions

## Section 6: Dark Mode

Every screen must include a complete dark mode variant.

Rules:

- Respect system theme and manual toggle
- Animate all color properties over `300ms`
- Brand-gradient remains unchanged in dark mode
- Reduce shadow intensity in dark mode and use borders where needed
- Cards change from `#FFFFFF` to `#222831`
- Screen backgrounds change from `#FAF8F5` to `#1A1D23`

## Section 7: Localization and Accessibility

### RTL Arabic Support

- Mirror paddings, margins, and icon directions horizontally
- Text aligns right in Arabic and left in English
- Navigation arrows, list icons, and layout grids flip
- Language toggle stores English and Arabic preference
- Text direction is LTR in English and RTL in Arabic

### Accessibility

- Minimum tap target: `44 x 44dp`
- WCAG AA contrast ratio on all text combinations
- Semantic labels on all icons
- Form inputs must have visible labels, not placeholders only
- Error messages must be announced to screen readers

### Egypt Market Formatting

- Currency: `1,500 EGP`
- Date format: `DD/MM/YYYY`
- Phone prefix default: `+20`
- Time format: `12-hour with AM/PM`, Arabic variant uses `ص/م`

## Section 8: Quality Rules

Never:

- Use pure black `#000000` for text or background
- Use the brand-gradient on more than two elements per screen
- Show a spinner without skeleton or contextual loading feedback
- Use a persistent top app bar on Home or Marketplace screens
- Omit dark mode
- Use visible text below `11sp`
- Stack two brand-gradient buttons on the same screen

Always:

- Use the exact hex values from the token set
- Apply `20dp` horizontal padding consistently
- Provide empty states for list views that can be empty
- Use the correct radius token for each component type
- Apply the specified motion system
- Use warm illustration style for onboarding, empty states, and error screens
