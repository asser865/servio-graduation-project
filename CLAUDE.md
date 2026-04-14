# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SERVIO is a full-stack marketplace platform connecting customers with home maintenance/finishing service technicians. It consists of four sub-projects:

- **`backend/`** — Node.js/Express REST API (MongoDB, JWT, Stripe)
- **`frontend-web/`** — Next.js 14 App Router prototype (TypeScript, no component library)
- **`mobile-app/`** — Flutter cross-platform app (iOS/Android)
- **`ai-service/`** — Python AI microservice (placeholder, not yet implemented)

---

## Commands

### Backend
```bash
cd backend
npm install
npm run dev      # nodemon on port 5000
npm run start    # production
```

### Frontend Web
```bash
cd frontend-web
npm install
npm run dev      # Next.js dev server on port 3000
npm run build
npm run lint     # ESLint (Next.js core web vitals)
```

### Mobile App
```bash
cd mobile-app
flutter pub get
flutter run
```

---

## Backend Architecture

**Entry points:** `src/server.js` (starts HTTP + connects MongoDB) → `src/app.js` (Express middleware + routes, no listen).

**API base path:** `/api/v1/` for all routes. Health check at `GET /health`.

**Module pattern** (`src/modules/<feature>/`): each module has routes → controller → service. Business logic lives only in services.

**Response conventions:**
- All success/error responses use `ApiResponse` utility: `{ success, message, data }` or `{ success, message, errors }`
- Errors thrown via `ApiError(statusCode, message, errors)` — caught by global error middleware at `src/middleware/error.middleware.js`
- `express-async-errors` is required in `app.js` so async errors propagate automatically

**Auth:** JWT (7-day expiry), bcryptjs SALT_ROUNDS=12. User schema has `select: false` on `password`. Role field: `user | worker | admin`.

**Critical:** Stripe webhook route must be registered before `express.json()` middleware to receive raw body. This order is enforced in `app.js`.

**Modules:** `auth`, `users`, `services`, `bookings`, `reviews`, `payments` (Stripe), `ai` (Smart Match / Cost Estimator integration)

**Postman collection:** `backend/SERVIO_API_Collection.json` — auto-saves JWT token to environment via test scripts.

---

## Frontend Web Architecture

**Framework:** Next.js 14 App Router (not Pages Router). TypeScript strict mode. Path alias `@/*` → `./src/*`.

The current `src/app/page.tsx` is a single-page design system showcase/prototype demonstrating all customer and technician flows. It uses `use client` with `useState`/`useMemo` for role switching (customer/technician), theme toggle (light/dark), and language switching (EN/AR with RTL).

No external component library or state management library is used. Global CSS design tokens are in `src/app/globals.css`.

---

## Mobile App Architecture

**Entry:** `lib/main.dart` → `ServioApp()` in `lib/src/app.dart` → defaults to `CustomerHomeScreen`.

**Structure:** Feature-driven under `lib/src/features/` (auth, booking, onboarding, customer, technician, messages, shared, design_showcase).

**Design system** (`lib/src/design_system/`):
- `servio_tokens.dart` — color palette, gradients, spacing, motion constants
- `servio_theme.dart` — `ThemeData` for light/dark with 300ms animation

**State management:** Not yet implemented. StatefulWidget used throughout. Ready for GetX, Riverpod, or Provider.

**Routing:** Basic Flutter Navigator. No named routes yet; ready for `go_router` or GetX routing.

**Lint rule:** prefer single quotes (enforced in `analysis_options.yaml`).

---

## Design System

Both web and mobile implement the same design language:
- **Themes:** Light and dark mode
- **i18n:** English and Arabic (RTL support)
- **Colors:** Defined in `servio_tokens.dart` (mobile) and `globals.css` (web)
- **Components:** Primary button, card, status chip, service grid cards, booking flow screens
