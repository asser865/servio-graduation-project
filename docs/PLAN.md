# Full Frontend-to-Flutter Plan

## Summary
Planning against **all 20 frontend HTML pages**. Admin Dashboard and 404 are out of scope. The remaining **18 pages** are split into:
- **14 completed** — acceptable Flutter implementations already exist
- **4 remaining** — pages with no Flutter screen yet (Phase 1 & 2)
- **4 updates** — existing screens that fall short of frontend-parity (Phase 3 & 4)

Not in scope:
- `Admin Dashboard` (`admin-dashboard.html`) — excluded, no mobile build planned
- `404 Page` (`404.html`) — excluded, generic error screen is sufficient

---

## Completed Pages (Flutter screens already exist)

| Frontend Page | Flutter Screen | Notes |
|---|---|---|
| `index.html` — Home / Landing | `onboarding_screen.dart` + `customer_home_screen.dart` | Web landing replaced by onboarding + home |
| `login.html` | `login_screen.dart` | done |
| `services-marketplace.html` | `services_marketplace_screen.dart` | done |
| `service-details.html` | `service_detail_screen.dart` | done |
| `technician-listing.html` | `technician_listing_screen.dart` | done |
| `technician-profile.html` | `technician_profile_screen.dart` | done |
| `smart-match.html` | `ai_smart_match_screen.dart` | done |
| `ai-estimator.html` | `ai_finishing_estimator_screen.dart` | done |
| `booking.html` Step 1 | `booking_step_one_screen.dart` | done |
| `booking.html` Step 2 | `booking_step_two_screen.dart` | done |
| `booking-details.html` | `BookingDetailsScreen` (inside `my_bookings_screen.dart`) | done |
| Chat (no dedicated HTML) | `chat_screen.dart` | done |
| `technician-dashboard.html` | `technician_dashboard_screen.dart` | done |
| `join-as-technician.html` | `role_selection_screen.dart` | Covered by the customer/technician role choice screen |

---

## Shared Design Tokens

Frontend palette used across all phases:
- `bgPage #FAF8F5`, `bgSoft #F3EDE7`, `bgSurface #FFFFFF`, `bgSurfaceAlt #F7F3EF`
- `primary #222831`, `secondary #393E46`, `accent #9A8C73`, `accentLight #BFB09A`, `brown #3C2415`
- `textPrimary #222831`, `textMuted #6B6560`, `border #DDD5CC`
- `success #22C55E`, `warning #E67E22`, `info #2980B9`, `danger #EF4444`
- Gradients: `brand (#3C2415 -> #222831)`, `accent (#9A8C73 -> #BFB09A)`, `warm (#E3D5CA -> #C8B9AA)`

Shared UI rules:
- `Poppins` headings, `Inter` body, `Cairo` for Arabic
- Radius scale `10 / 14 / 18 / 22 / pill`
- Cards always use `bgSurface + border`
- Muted/supporting copy always uses `textMuted`
- Primary CTA uses `gradientBrand` or `primary`
- Accent highlights, chips, and active states use `accent`

---

## Phase 1 — New Marketing & Support Pages
No Flutter screen exists for any of these. Full builds.

### About Page
Frontend source: `about.html`

Components:
- Hero section — eyebrow kicker with icon, headline with accent word, lead paragraph, dual CTA buttons (Explore Services, Get in Touch), decorative background
- Impact stats strip — 4 stat cards: Verified Professionals (2,500), Bookings Completed (15,000), Satisfaction Rate (98%), 24/7 Support
- Our Story section — 3 numbered chapters in sequence (Problem → Spark → Result) with a visual card beside them
- What Makes SERVIO Different — 4 feature cards with icon, title, description (Verified Professionals, Real Customer Reviews, Secure Payments, Instant Booking)
- Core Values section — 4 gradient cards with numbered labels (01–04): Trust, Transparency, Quality, Customer First
- CTA banner — full-width panel with headline, supporting text, two action buttons (Get Started Free, Contact Us)

Colors:
- Page background: `bgPage`
- Hero contrast blocks: `primary`, `brown`, `brand gradient`
- Stats strip background: `bgSoft`
- Feature and value cards: `bgSurface`, `border`
- Value card gradient accents: `accent` to `accentLight`
- Section number labels and icon accents: `accent`
- Secondary copy: `textMuted`
- CTA banner: `gradientBrand`

Implementation changes:
- Build as a scrollable marketing-style Flutter screen
- Stats strip uses a horizontal scrolling row on narrow screens
- Value cards use numbered decorative labels (01–04) with gradient fill
- Reuse `ServioCard` and section header widgets throughout
- Both CTA buttons navigate: Explore Services → ServicesMarketplaceScreen, Contact Us → ContactScreen

---

### Contact Page
Frontend source: `contact.html`

Components:
- Hero section — eyebrow with icon, headline with accent on second line, lead text, decorative background
- Two-column layout adapted to stacked mobile:
  - Contact form card — Full Name + Email row, Subject field, Message textarea, Submit button with loading/success state
  - Contact Details card — Email, Phone, Office address, each with icon
  - Support Hours card — business hours listed by day (e.g. Mon–Fri 9am–6pm, Sat 10am–4pm, Sun Closed)
  - Response Promise card — icon + guarantee text (e.g. "We reply within 2 business hours")
- FAQ accordion — 4 expandable items: Booking/account help, Professional signup, Verification process, Browsing without account

Colors:
- Background: `bgPage`
- Form and info card surfaces: `bgSurface`, `border`
- Input fields: `bgSurface` with `border`, focus ring `accent`
- Support Hours and Response Promise card accents: `info`, `accent`
- FAQ chevron and active state: `accent`
- Secondary text: `textMuted`
- Submit button: `gradientBrand`

Implementation changes:
- Stack form card above the three info cards on mobile
- FAQ uses AnimatedSize or ExpansionTile for expand/collapse
- Submit shows inline success message on completion and inline error on failure
- Contact Details items are tappable (email launches mailto, phone launches tel, office launches maps)

---

## Phase 2 — New Dashboard
No adequate Flutter screen exists. Full build.

### Customer Dashboard
Frontend source: `customer-dashboard.html`
Existing: `customer_home_screen.dart` is a simpler home screen, not a dashboard. Build as a new screen.

The desktop layout uses a persistent left sidebar with navigation items. On mobile this becomes a bottom tab bar (already in place) with internal segmented controls per section.

#### Navigation Sections (tabs/segments)
Overview, Bookings, History, Favourites

#### Overview Section
- Welcome card — personalised greeting with time-of-day label (Good morning / afternoon / evening), user name, supporting subheading, Book a Service CTA button
- Stats grid — 4 KPI cards:
  - Total Bookings — count with a goal progress bar
  - In Progress — count with a breakdown row (confirmed vs. awaiting)
  - Saved Technicians — count with a small progress visualisation
  - Total Spent — amount with monthly budget label
- Recent Bookings card — header with View All link, list of 3 booking rows (service icon, name, metadata, status badge)
- Upcoming Schedule card:
  - Next Appointment Spotlight — special badge, service icon, technician name, date/time, visual progress track
  - Timeline list — upcoming appointments with dot indicators and status labels
  - Book New Service CTA at the bottom

#### Bookings Section
- Filter tab bar — All, Active, Pending, Completed
- Booking cards — one per booking, each containing:
  - Service row: icon + service title
  - Provider row: small avatar + technician name + View Profile link
  - Status badge (Confirmed, Pending, En Route, etc.)
  - Detail grid: Date, Time Slot, Address (each with icon)
  - 4-step progress tracker: Booked → Confirmed → En Route → Completed (filled vs. empty connector lines)
  - Arrival PIN box — 4-digit code displayed in a styled container
  - Total Amount box — price in EGP
  - Action buttons: View Details, View Invoice, Chat with Technician, Cancel
  - Collapsible invoice panel — cost breakdown table (base rate, platform fee, parts, total) + payment method row

#### History Section
- History stats row — 3 summary cards: Bookings Completed, Total Amount Spent, Most Used Service
- Filter bar — dropdowns/chips for: Category, Date Range, Payment Method, Rating, Clear All
- History item list — each row has:
  - Service emoji icon + service title with booking ID
  - Technician name and date
  - Payment method badge
  - Price
  - Expand chevron
  - Expandable invoice grid: cost breakdown + transaction verification section

#### Favourites Section
- Saved technician cards — avatar, name, specialty, rating, quick Book button

Colors:
- Page and section background: `bgPage`
- All cards: `bgSurface`, `border`
- KPI accent icons: `accent`, `success`, `info`, `warning`
- Progress tracker filled steps: `success`, current step: `warning`, future steps: `border`
- Arrival PIN box: `bgSoft`, border `accent`
- Status badges: `success` (Confirmed), `warning` (Pending), `info` (En Route), `danger` (Cancelled)
- Filter tab active: `accent`
- Muted metadata and labels: `textMuted`
- Invoice expand accent: `accent`
- CTA buttons: `gradientBrand`

Implementation changes:
- Desktop sidebar navigation becomes bottom tab bar + internal segmented controls
- Booking cards collapse invoice panel using AnimatedSize
- Progress tracker is a custom widget with filled/empty connector lines
- Stats grid is a 2×2 GridView with fixed aspect ratio cards
- History filters use a horizontal scroll row of chips
- Favourites section reuses the technician card widget from technician listing

---

## Phase 3 — Booking & Messaging Updates
Flutter screens exist but are below frontend-parity. Update in place.

### Booking Step Three — Review & Confirm
Frontend source: `booking.html` Step 3
Existing: `booking_step_three_screen.dart` (221 lines) — has summary card and payment selection. Missing: terms consent block, wired Back button, Edit links that navigate to earlier steps, and the Order Summary sidebar trust signals.

Components:
- Review step header (step indicator + title)
- Service Details review block:
  - Edit button (navigates back to step 1)
  - Review rows: Technician, Service, Date, Time, Address — each `label + value` pair
- Payment review block:
  - Edit button (navigates back to step 2)
  - Review rows: Method, Base Rate, Platform Fee, Estimated Total
- Terms & conditions consent block — checkbox with tappable links to Terms of Service and Privacy Policy; Confirm button disabled until checked
- Order Summary card (adapted from web sidebar):
  - Technician avatar, name, role, star rating with count
  - Pricing rows: Base rate (1 hr min), Platform fee (5%), Parts & materials (as quoted), Estimated Total (bold, `accent` color)
  - 4 trust signal rows with checkmark icons: Free cancellation up to 2 hours, SERVIO Service Guarantee, Identity & licence verified, No hidden fees
- Bottom action row: Back (outlined) + Confirm Booking (primary, disabled until consent checked)

Colors:
- Background: `bgPage`
- Review and summary cards: `bgSurface`, `border`
- Review row labels: `textMuted`
- Edit links: `accent`
- Total amount: `accent`, bold
- Trust signal checkmarks: `success`
- Terms link text: `accent`
- Confirm button: `gradientBrand` (disabled state: opacity 0.5)

Implementation changes:
- Add terms consent checkbox; Confirm button blocked until checked
- Wire Back button to pop to step two
- Wire Edit buttons to navigate to the correct earlier step
- Bind all review row values and pricing from `BookingFlowData`
- Order Summary card sits above the action row (stacked below the review blocks on mobile)

---

### Booking Confirmation
Frontend source: `booking-confirmation.html`
Existing: `booking_confirmation_screen.dart` (189 lines) — compact success screen. Missing: 6-step status tracker, Arrival PIN card, Payment Summary card, Technician chip with status badge, Help card, full action stack.

Components:
- Success hero — animated checkmark icon in circle, "Booking Confirmed!" headline, supporting subheading, tappable booking reference chip (copies to clipboard, shows "Copied!" feedback)
- Status tracker — horizontal timeline of 6 named steps with connector lines:
  1. Booked (completed — checkmark)
  2. Technician Confirms (current — pulsing dot)
  3. En Route
  4. Arrived
  5. In Progress
  6. Complete
  - Filled connectors for completed steps, empty for future
  - Current status label + pulsing dot above the tracker
- Arrival PIN card — centred card with title, large 4-digit PIN display, description text
- Payment Summary card — payment method, amount breakdown rows
- Confirmation Details card:
  - Technician section: avatar, name, role, star rating, status badge
  - Service Details section: Service, Date, Time Slot, Address
  - Payment section: Method, Base Rate, Platform Fee, Estimated Total
- Action stack (vertical button list):
  - View Booking Details (primary)
  - Message Technician (outlined)
  - Go to Dashboard (outlined)
  - View Booking History (text button)
  - Back to Home (text button)
  - Cancel Booking (danger/red text button)
- Help card — "Need help?" heading, support description, contact info

Colors:
- Background: `bgPage`
- Success icon circle: tint of `success`
- Cards: `bgSurface`, `border`
- Reference chip: `bgSoft`, border `accent`
- Tracker completed steps: `success`; current step: `warning`; future steps: `border`
- PIN display: `primary`, bold
- Technician status badge: `success`
- Cancel button: `danger`
- Supporting/meta text: `textMuted`

Implementation changes:
- Rebuild screen around this structure — current implementation is too compact
- Tracker and reference chip persist values from `BookingFlowData`
- Clipboard copy on reference chip tap using `Clipboard.setData`
- Route each action button to the correct existing screen
- Cancel Booking shows a confirmation bottom sheet before acting

---

### Messages
Frontend source: `messages.html`
Existing: `messages_screen.dart` (176 lines) — has search and conversation list. Missing: workspace header with secure messaging badge, role-awareness, and technician entry point.

Components:
- Workspace header:
  - Left: eyebrow label + "Messages" title
  - Right: secure messaging badge (lock icon + "End-to-end secured" label), Back to Dashboard link
- Search field — pill-shaped, `bgSoft` fill, `accent` focus border
- Conversation list — one card per conversation:
  - Initials avatar with `warm gradient` background and `accent` border
  - Online status dot (green) overlaid on avatar
  - Contact name (`titleMedium`)
  - Message preview (1 line, `textMuted`, ellipsis overflow)
  - Timestamp (top-right, `textMuted`)
  - Unread count badge (`accent` background, white text) — shown only when unread > 0
  - Tap navigates into `ChatScreen`
- Role-aware entry: when the current user is a technician, show a "My Conversations" label and an entry point from TechnicianDashboardScreen; customer sees the same list under customer navigation

Colors:
- Background: `bgPage`
- Conversation cards: `bgSurface`, `border`
- Active/tapped row background: `bgSoft`
- Avatar background: `warm gradient`, border `accent`
- Online dot: `success`
- Unread badge: `accent`
- Secure badge icon and text: `accent`
- Preview and timestamp text: `textMuted`

Implementation changes:
- Add workspace header with secure messaging badge
- Make screen role-aware: show correct back-navigation target per role
- Existing search field, list, and unread badge logic is already correct — keep it
- Remove AppBar and replace with the custom workspace header

---

## Phase 4 — Account & Review Updates
Flutter screens exist but have hardcoded data, missing validation, or structural gaps. Update in place.

### Write Review
Frontend parity source: shared review/card patterns from frontend pages
Existing: `write_review_screen.dart` (185 lines) — all UI components present but technician card is hardcoded (`Ahmed Nabil`, `Plumbing Repair Visit`) and Submit button has no `onPressed` or validation.

Components:
- Technician/job summary card — avatar initials with `warm gradient`, technician name, job/service label (all passed in as constructor parameters, not hardcoded)
- Star rating row — 5 tappable stars; inactive `border`, active `accent`; tapping a star sets rating 1–5
- Review textarea — hint text "Share your experience in detail...", 5 lines, `300` character max
- Character counter — live `current/300` display below the field, turns `danger` at limit
- Quick tags — wrap row of chips: Professional, On Time, Great Quality, Clean Work, Friendly, Would Recommend; inactive `bgSoft`/`textMuted`, selected `accent`/white
- Media strip (optional) — add-photo button + up to 3 placeholder thumbnails
- Submit button — primary, disabled (opacity 0.5) until rating > 0 AND review text is non-empty; on press shows success snackbar and pops screen
- Skip for now — text button, pops screen without submitting

Colors:
- Background: `bgPage`
- Summary and input cards: `bgSurface`, `border`
- Inactive stars: `border`; active stars: `accent`
- Selected tag background: `accent`, text white
- Inactive tag background: `bgSoft`, text `textMuted`
- Character counter default: `textMuted`; at limit: `danger`
- Submit CTA: `gradientBrand`

Implementation changes:
- Add `required String technicianName` and `required String jobSummary` constructor params; remove all hardcoded strings
- Gate Submit on rating > 0 and reviewText.trim().isNotEmpty
- Wire Submit `onPressed` to pop with success snackbar
- Screen must only be reachable from a completed booking (pass booking context on push)

---

### Sign Up
Frontend source: `signup.html`
Existing: `sign_up_screen.dart` (449 lines) — solid multi-step flow. Missing: brand showcase left panel, OTP phone verification step, and technician application-submitted end state.

#### Left Brand Panel (visible on tablet/landscape; collapses to top strip on mobile)
- Canvas-style animated background with brand gradient
- Logo + SERVIO brand name
- Headline with emphasised word
- Feature list (3 items with icons): e.g. Verified Experts, Secure Payments, Instant Booking
- Stats row (3 stats): Technicians count, Jobs Done, Average Rating

#### Multi-step form — Customer path (4 steps)
**Step 1 — Role Selection:**
- Role indicator badge (hidden on step 1, appears from step 2 onward)
- Brand icon + headline + subheading
- Two role cards (radiogroup): Customer card (icon, title, subtitle, description, checkmark overlay when selected), Technician card (same structure)
- Error message slot
- Auth actions: "Already have an account?" link + Continue button
- Trust signals row: Secure signup, No spam, Cancel anytime

**Step 2 — Basic Information:**
- Step header with progress bar
- Social sign-up buttons: Continue with Google, Continue with Apple
- Divider "or"
- Fields: Full Name (icon-wrapped, clear button), Phone Number (icon-wrapped, clear button), Email Address (full-width, icon-wrapped), Password (full-width, toggle visibility, strength indicator bar)
- Auth actions: Back + Continue

**Step 3 — Phone / OTP Verification:**
- Step header: "Verify your phone number"
- Description showing destination phone number
- 6-digit OTP input field with clear button
- Resend code link with cooldown timer
- Error message slot
- Auth actions: Back + Verify

**Step 4 — Customer Finish:**
- Step header: "Almost done!"
- Address / City field (optional)
- Terms & Privacy checkbox with tappable links
- Error message slot
- Auth actions: Back + Create Account

#### Multi-step form — Technician path (7 steps)
Steps 1–3 are identical to the customer path above.

**Step 4B — Skills:**
- Step header: "What services do you offer?"
- Skills search input with clear button
- Dynamic chip row of selectable skill tags
- Error message slot
- Auth actions: Back + Continue

**Step 5B — Availability:**
- Step header: "Set your availability"
- Service area field (required)
- Availability toggle: 3-segment control — Weekdays / Weekends / Both
- Error message slot
- Auth actions: Back + Continue

**Step 6B — Pricing:**
- Step header: "Set your hourly rate"
- Two-column row: Currency dropdown + Hourly rate number input (range 50–2000) with clear button
- Rate hint text
- Error message slot
- Auth actions: Back + Continue

**Step 7B — Verification (document upload — see Verification Upload spec below):**
- Embedded as a step in this flow, not a standalone screen

**Step 8B — Application Submitted:**
- Success icon (checkmark circle, `success` color)
- Headline: "Application Submitted!"
- Description paragraph
- Next Steps ordered list (3 items): Team verifies documents, Email notification timeline, Post-approval app access
- Support contact info with tappable email link
- Auth actions: Back to Home (centred primary button)

Colors:
- Background: `bgPage`
- Left panel / top strip: `gradientBrand`, `brown` overlays
- Form surfaces: `bgSurface`
- Progress bar fill: `gradientAccent`
- Role card selected state: `gradientBrand` background, white text
- Role card unselected: `bgSurface`, `border`
- OTP input: `bgSurface`, focus border `accent`
- Strength bar: `danger` (weak) → `warning` (medium) → `success` (strong)
- Skills chip selected: `accent`, white text; unselected: `bgSoft`, `textMuted`
- Availability toggle active segment: `accent`, white text
- Trust signals: `textMuted` with `accent` icon
- Submit / Continue CTAs: `gradientBrand`

Implementation changes:
- Add brand showcase strip at top of the form screen (collapsed horizontal strip on mobile with logo + tagline)
- Add OTP step (Step 3) between Basic Information and the role-specific steps
- Add Application Submitted end state for technician path
- Embed Verification Upload as Step 7B rather than navigating to a separate screen
- Preserve all field values across back/forward navigation

---

### Verification Upload
Frontend source: embedded Step 6B in `signup.html`
Existing: `verification_upload_screen.dart` (124 lines) — standalone screen with ID front/back, trade licence, insurance zones. Missing: selfie zone, portfolio zone with multi-photo support, trust/info strip, per-document error messages, preview grid, and integration as a signup step.

Components:
- Step header: "Verify your identity" + progress bar showing position in overall flow
- Trust/security strip — lock icon + "Your documents are encrypted and reviewed only by our team" text
- Upload zones (required):
  - National ID — Front (file input card)
  - National ID — Back (file input card)
  - Selfie holding ID (full-width file input card)
- Upload zones (optional):
  - Trade Certificate / Licence (file input card)
  - Portfolio Photos — multiple, up to 5 (file input card + thumbnail preview grid below)
- Each upload card shows one of four states:
  - Pending — dashed `border`, upload icon, "Tap to upload" label
  - Uploaded — solid `accent` border, file name chip, remove button
  - Under Review — `warning` border, hourglass icon, "Under Review" label
  - Verified — `success` border, checkmark icon, "Verified" label
  - Rejected — `danger` border, error icon, "Rejected — Re-upload" label
- Per-document error message — shown in `danger` color below the relevant card when validation fails
- Portfolio thumbnail preview grid — 3-column wrap of image thumbnails with remove buttons
- Auth actions row: Back + Submit Application (full-width primary button)

Colors:
- Background: `bgPage`
- Card surfaces: `bgSurface` / `bgSoft`
- Default border: `border` (dashed)
- Uploaded border: `accent`
- Under Review border: `warning`
- Verified border: `success`
- Rejected border: `danger`
- Trust strip: `accent` icon, `textMuted` text
- Required label: `accent`; Optional label: `textMuted`
- Error text: `danger`
- Submit button: `gradientBrand`

Implementation changes:
- Refactor from standalone screen into a reusable widget that can be embedded as a signup step
- Add selfie zone (required) and portfolio zone (optional, multi-photo, up to 5)
- Add trust/security strip at the top
- Implement per-document error messages below each card
- Add portfolio thumbnail preview grid with remove-per-photo support
- Preserve all uploaded file references across back/forward navigation in the signup flow
- Required documents must all be uploaded before Submit Application is enabled

---

## Test Plan
- Phase 1: marketing pages scroll correctly, all sections render, RTL layout, CTA buttons navigate to correct screens, FAQ accordion expands/collapses, contact form shows success/error states
- Phase 2: all four dashboard tabs switch correctly, booking card progress tracker renders, invoice panel expands/collapses, history filters update the list, stats cards show correct values
- Phase 3: booking step 3 consent gates the confirm button, back/edit navigation works, booking confirmation tracker shows correct step states, reference chip copies to clipboard, messages header shows secure badge and correct role back-link
- Phase 4: sign-up OTP step appears between basic info and role steps, technician path ends on application-submitted screen, write review submit is gated on rating + text, verification upload blocks submit until required docs are uploaded
- Verify light mode, dark mode, and Arabic (RTL) layout for every screen
- Verify all CTAs navigate to existing screens without dead ends

## Assumptions
- `Customer Dashboard` is a full new build — `customer-dashboard.html` is a rich multi-section dashboard while `CustomerHomeScreen` is a simpler browsing home screen.
- `Verification Upload` is kept as a separate spec entry because it needs its own component breakdown even though it will be embedded as a step inside Sign Up.
- `Join as Technician` is complete — covered by `role_selection_screen.dart`.
- `Admin Dashboard` and `404` are out of scope.
- `booking-details.html` is covered by `BookingDetailsScreen` inside `my_bookings_screen.dart`.
- The AI chat widget present on all web pages (about, contact, signup) is not replicated in Flutter — the app has a dedicated AI Smart Match screen instead.
- The web site header/footer (nav bar, newsletter, social links) are not replicated in Flutter — replaced by the app shell (bottom nav, app bars).
