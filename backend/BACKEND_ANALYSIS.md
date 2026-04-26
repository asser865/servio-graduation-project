# SERVIO Backend — Complete Technical Breakdown

---

## 1. Folder and File Structure

```
backend/
├── .env                          # Active environment variables (gitignored)
├── .env.example                  # Template showing all required variables
├── package.json                  # Dependencies, scripts (start, dev, test)
├── SERVIO_API_Collection.json    # Postman collection with auto-JWT scripts
└── src/
    ├── server.js                 # Process entry point: dotenv → DB → listen
    ├── app.js                    # Express factory: middleware + routes (no listen)
    ├── config/
    │   ├── db.js                 # Mongoose connection with process.exit on failure
    │   └── stripe.js             # Lazy-loaded Stripe SDK + webhook signature verifier
    ├── middleware/
    │   ├── auth.middleware.js    # JWT extraction + verification → req.user
    │   ├── role.middleware.js    # RBAC factory: authorize('admin', 'worker', ...)
    │   ├── validate.middleware.js # express-validator runner → ApiError(422)
    │   └── error.middleware.js   # notFound (404) + global errorHandler
    ├── utils/
    │   ├── ApiError.js           # Custom Error subclass with statusCode + errors[]
    │   └── ApiResponse.js        # Static success/error response shaper
    └── modules/
        ├── auth/                 # Registration + login
        ├── users/                # Worker discovery + profile + admin management
        ├── services/             # Service catalogue CRUD
        ├── bookings/             # Booking lifecycle + state machine
        ├── reviews/              # Post-completion ratings
        ├── payments/             # Stripe escrow + wallet + disputes + audit log
        └── ai/                   # Proxy gateway to Python AI microservice
```

Each module under `modules/` follows a consistent tripartite structure:

| File | Responsibility |
|---|---|
| `*.routes.js` | Route definitions, validation rules, middleware chain |
| `*.controller.js` | HTTP parsing and response formatting only |
| `*.service.js` | All business logic, no Express objects |
| `*.model.js` | Mongoose schema, indexes, hooks, instance methods |

---

## 2. Architecture Overview

**Style:** Modular monolith with a layered architecture inside each module. Routes → Controller → Service → Model. The architecture anticipates microservice extraction (AI is already a separate process; payments could be split).

**Key separation of concerns:**

- `server.js` handles process lifecycle only (DB connect, HTTP listen, graceful shutdown, unhandled rejection safety net).
- `app.js` is an Express factory that wires middleware and routes but never calls `listen`. This cleanly enables testability — a test can import the app and spin up its own server.
- `express-async-errors` is required at the very top of `app.js` so all async route handler exceptions propagate to Express's `next(err)` chain automatically — no per-handler try/catch is needed anywhere.

**Data flow through the system:**

```
HTTP Request
    → Helmet (security headers)
    → CORS
    → Morgan (logging)
    → [payment router — BEFORE express.json for webhook raw body]
    → express.json / urlencoded (body parsing)
    → Route match
        → validate middleware (express-validator)
        → protect middleware (JWT decode → req.user)
        → authorize middleware (role check)
        → Controller (parse req, call service, format res)
            → Service (business logic, Mongoose queries)
                → Model (Mongoose schema, pre/post hooks)
    → ApiResponse.success(res, ...)
    ← JSON { success: true, message, data }

    [On Error]
    → errorHandler middleware
        normalises: CastError / ValidationError / JWT errors / ApiError
    ← JSON { success: false, message, errors[] }
```

---

## 3. Core Components

### `src/server.js`

The bootstrap file. It is the only place `dotenv.config()` is called, which must happen before any other module loads — otherwise `process.env` values would be undefined when modules import at load time. It calls `connectDB()` first, which will `process.exit(1)` on failure, ensuring the HTTP server never starts in a broken state. Graceful shutdown on SIGTERM/SIGINT: `server.close()` stops accepting new connections; a 10-second hard exit timer prevents the process from hanging if requests never drain.

### `src/app.js`

The Express application factory. Critical architectural decision on line 65: `paymentRoutes` is mounted **before** `express.json()` because the `/webhook` sub-route must receive a raw `Buffer` body — Stripe signature verification cryptographically checks the exact bytes sent, which `express.json()` would destroy. The payment router selectively applies `express.raw({ type: 'application/json' })` only to the `/webhook` sub-route, so all other payment endpoints still receive parsed JSON.

### `src/utils/ApiError.js` & `ApiResponse.js`

Two-class response contract. `ApiError` extends `Error` with `statusCode`, an `errors[]` array (for field-level validation feedback), and an `isOperational` flag (`false` marks programmer bugs vs. expected domain errors). `ApiResponse` provides two static methods — `success(res, statusCode, message, data)` and `error(res, statusCode, message, errors)` — used uniformly across every endpoint. The client always receives `{ success, message, data }` or `{ success, message, errors }`.

### `src/config/stripe.js`

Lazy-loaded Stripe via a `Proxy` object. The Proxy intercepts property access and only calls `getStripe()` on first use — the server won't crash at startup if `STRIPE_SECRET_KEY` is a placeholder. `verifyWebhookSignature(rawBody, signature)` wraps `stripe.webhooks.constructEvent()` and throws `ApiError(400)` on failure. Requires two distinct credentials: the API key and the webhook signing secret.

---

## 4. API Endpoints — Complete Catalogue

### Auth (`/api/v1/auth`)

| Method | Route | Auth | Body | Response |
|---|---|---|---|---|
| POST | `/register` | None | `name, email, password, phone?, role?` | `{ token, user }` |
| POST | `/login` | None | `email, password` | `{ token, user }` |

**Register validation:** name ≤100 chars, valid email, password ≥8 chars with at least one digit, role ∈ `['user', 'worker']`.

**Login:** Uses identical error message for "not found" and "wrong password" to prevent user-enumeration attacks. Checks `isActive` before comparing password.

---

### Users (`/api/v1/users`)

| Method | Route | Auth | Access | Description |
|---|---|---|---|---|
| GET | `/workers` | None | Public | Paginated list of active+verified workers; `?category`, `?page`, `?limit` |
| GET | `/workers/:id` | None | Public | Worker profile + last 10 reviews |
| PATCH | `/me` | JWT | Any role | Update own name / phone / profileImage |
| PATCH | `/me/availability` | JWT | Worker | Set weekly availability slots |
| GET | `/` | JWT | Admin | All users with `?role` filter + pagination |
| PATCH | `/:id/status` | JWT | Admin | `{ isActive: boolean }` — ban/unban |
| PATCH | `/workers/:id/verify` | JWT | Admin | `{ isVerified: boolean }` — approve/reject worker |
| GET | `/analytics` | JWT | Admin | Counts by role + booking status breakdown |
| GET | `/analytics/payments` | JWT | Admin | Revenue, escrow, refunds, disputes, monthly revenue chart |

`updateProfile` whitelists only `['name', 'phone', 'profileImage']` — users cannot change their role via this endpoint.

---

### Services (`/api/v1/services`)

| Method | Route | Auth | Access | Description |
|---|---|---|---|---|
| GET | `/` | None | Public | Paginated list of active services; `?category` filter |
| GET | `/:id` | None | Public | Single service detail |
| POST | `/` | JWT | Admin | Create service catalogue entry |
| PUT | `/:id` | JWT | Admin | Full update of a service |
| DELETE | `/:id` | JWT | Admin | Soft-delete (sets `isActive: false`) |

Categories enum: `plumbing`, `electrical`, `painting`, `flooring`, `carpentry`, `cleaning`, `other`. Price units: `per_hour`, `per_sqm`, `fixed`. Deletion is soft — historical booking references remain intact.

---

### Bookings (`/api/v1/bookings`)

| Method | Route | Auth | Access | Description |
|---|---|---|---|---|
| POST | `/` | JWT | User | Create booking: `{ workerId, serviceId, scheduledDate, address, description?, images? }` |
| GET | `/my` | JWT | Any | Own bookings; `?status`, `?page`, `?limit` |
| GET | `/worker` | JWT | Worker | Bookings assigned to me; `?status`, `?page`, `?limit` |
| GET | `/` | JWT | Admin | All bookings; `?status`, `?page`, `?limit` |
| PATCH | `/:id/status` | JWT | Worker/Admin/User | Transition status per role rules |

**Status machine** (enforced in `booking.service.js`, `TRANSITION_RULES`):

```
Roles → Allowed transitions
worker → [accepted, rejected, in_progress, completed]
user   → [cancelled]  (only if booking.status === 'pending')
admin  → [any status]
```

Ownership is verified at service layer — a worker cannot update another worker's booking.

---

### Reviews (`/api/v1/reviews`)

| Method | Route | Auth | Access | Description |
|---|---|---|---|---|
| POST | `/` | JWT | User | Submit review: `{ bookingId, rating, comment? }` |
| GET | `/worker/:workerId` | None | Public | All reviews for a worker |
| DELETE | `/:id` | JWT | Admin | Remove review |

Pre-conditions for review creation: booking must exist, belong to the requesting user, and have `status === 'completed'`. The `booking` field has a unique index — duplicate reviews are rejected at the database level. The `post('save')` hook on the Review schema re-aggregates all reviews for the worker and updates `User.averageRating` (rounded to 1 decimal) and `User.totalReviews` atomically.

---

### Payments (`/api/v1/payments`)

| Method | Route | Auth | Access | Description |
|---|---|---|---|---|
| POST | `/webhook` | None (Stripe) | Stripe only | Raw-body Stripe event handler |
| POST | `/intent` | JWT | User | Create Stripe PaymentIntent → returns `clientSecret` |
| POST | `/confirm/:bookingId` | JWT | User | Confirm completion → release escrow to worker |
| GET | `/booking/:bookingId` | JWT | User/Worker/Admin | Payment details for a booking |
| GET | `/earnings` | JWT | Worker | Wallet summary + earnings history |
| POST | `/refund/:paymentId` | JWT | Admin | Full manual refund |
| POST | `/disputes` | JWT | User | Open dispute: `{ bookingId, reason, evidence? }` |
| PATCH | `/disputes/:id/resolve` | JWT | Admin | Resolve: `{ resolution, decision: 'refund'\|'release' }` |
| GET | `/disputes` | JWT | Admin | All disputes with pagination |

---

### AI (`/api/v1/ai`)

| Method | Route | Auth | Access | Description |
|---|---|---|---|---|
| POST | `/recommend` | JWT | Any | Forward `{ description, location?, budget? }` to Python AI service |

Proxies to `AI_SERVICE_URL/recommend` with a 15-second timeout. Handles `ECONNABORTED` (504), `error.response` present (502), and network error (503) distinctly.

---

## 5. Business Logic

### Booking State Machine

The booking lifecycle is the core workflow. The `TRANSITION_RULES` object in `booking.service.js` acts as a pure whitelist — not an exhaustive state machine with from/to pairs, just a role-to-allowed-statuses map. An extra rule tightens the user cancellation: users can only cancel while `status === 'pending'`.

### Payment Escrow Flow

This is the most complex subsystem:

1. **User pays** → `POST /payments/intent`: Server creates a Stripe `PaymentIntent` and saves a local `Payment` document with `status: 'pending'`. Returns `clientSecret` to the frontend for Stripe.js to collect card details — the server never sees raw card data.
2. **Stripe confirms payment** → `POST /payments/webhook`: Stripe POSTs a `payment_intent.succeeded` event. Server verifies the signature, checks idempotency (searches for existing `Transaction` with this `intent.id`), then inside a Mongoose session transaction: sets `Payment.status = 'held'`, sets `Booking.status = 'in_progress'`, adds `workerEarning` to `Wallet.pendingBalance`, and writes an immutable `Transaction` log.
3. **Work is done** → `POST /payments/confirm/:bookingId`: User calls this after they're satisfied. Inside a session transaction: `wallet.releasePending(workerEarning)` moves money from `pendingBalance` to `balance`, sets `Payment.status = 'released'`, logs two `Transaction` entries (one for worker earning, one for platform fee).

### Dispute Flow

1. User calls `POST /disputes` → `DisputeService.openDispute` checks booking belongs to user, booking must be `in_progress` or `completed`, payment must be `held`. Creates `Dispute` document, sets `Payment.status = 'disputed'` (freezes funds).
2. Admin resolves via `PATCH /disputes/:id/resolve` with `decision: 'refund'` or `'release'`. The service calls back into `paymentService.refundPayment` or `paymentService.releasePaymentToWorker` accordingly. A circular dependency between `payment.service.js` and `dispute.service.js` is broken via a lazy `require` inside methods.

### Worker Rating Denormalisation

The `Review` model's `post('save')` hook re-aggregates the entire worker's review set using `$avg` — not an incremental counter — to prevent drift. It updates `User.averageRating` and `User.totalReviews` automatically. This is a denormalised cache updated via a Mongoose lifecycle hook.

---

## 6. Database Layer

**Database:** MongoDB accessed via Mongoose ODM (v9.3).

### Models and Relationships

| Model | Collection | Key Fields | Indexes |
|---|---|---|---|
| `User` | `users` | `name, email, password, role, isActive, isVerified, categories[], location{GeoJSON}, averageRating, availability[]` | `2dsphere` on `location` |
| `Service` | `services` | `title, description, category, basePrice, priceUnit, isActive, createdBy→User` | `{ category, isActive }` |
| `Booking` | `bookings` | `user→User, worker→User, service→Service, status, scheduledDate, address, totalPrice` | `{ user, status }`, `{ worker, status }` |
| `Review` | `reviews` | `user→User, worker→User, booking→Booking (unique), rating, comment` | unique on `booking` |
| `Payment` | `payments` | `booking→Booking (unique), user→User, worker→User, amount, platformFee, workerEarning, status, gatewayPaymentIntentId` | unique on `booking`, index on `gatewayPaymentIntentId` |
| `Wallet` | `wallets` | `worker→User (unique), balance, pendingBalance, totalEarned, totalWithdrawn` | unique on `worker` |
| `Transaction` | `transactions` | `payment→Payment, wallet→Wallet, type, amount, direction, actor→User, note` | `{ payment }`, `{ wallet, createdAt }`, `{ type, createdAt }` |
| `Dispute` | `disputes` | `booking→Booking, payment→Payment, raisedBy→User, reason, status, resolvedBy→User` | `{ status, createdAt }`, `{ booking }` |

### Entity Relationship Summary

- One `User` can have many `Booking`s (as customer or worker), many `Review`s received (as worker), one `Wallet` (as worker).
- One `Booking` has exactly one `Payment` (unique constraint enforced), optionally one `Dispute`, optionally one `Review`.
- `Service` is a catalogue entity — `Booking.service` is a reference to a catalogue item.
- `Transaction` is append-only audit log connected to `Payment` and optionally `Wallet`.

**Access pattern:** Direct Mongoose Model queries — no repository abstraction layer. Business logic services call `Model.find()`, `Model.create()`, `Model.findByIdAndUpdate()` etc. directly.

**All monetary amounts** in `Payment`, `Wallet`, and `Transaction` are stored in the smallest currency unit (piastres for EGP, cents for USD) as integers. The `Payment` pre-save hook auto-calculates `platformFee` and `workerEarning` based on `PLATFORM_FEE_PERCENTAGE` env var (defaults to 10%).

---

## 7. Authentication and Authorization

**Authentication:** Stateless JWT, 7-day expiry (`JWT_EXPIRES_IN`). Signed with `JWT_SECRET`. Token payload: `{ id, role }`. The `protect` middleware in `auth.middleware.js` extracts the Bearer token, calls `jwt.verify()`, and attaches the decoded payload to `req.user`. JWT errors (`JsonWebTokenError`, `TokenExpiredError`) are caught by the global error handler and converted to `401` responses.

**Authorization:** Role-Based Access Control via the `authorize()` factory in `role.middleware.js`. Usage pattern in every protected route: `protect, authorize('admin')`. Three roles: `user`, `worker`, `admin`.

**Password security:** bcryptjs with 12 salt rounds (OWASP recommended minimum). Hashing happens in a Mongoose `pre('save')` hook — only when `password` is modified, preventing double-hashing on profile updates. The `password` field is `select: false` so it never appears in query results unless explicitly fetched with `.select('+password')` (only done in login). A `toJSON` transform provides a belt-and-suspenders strip even if password is accidentally selected.

---

## 8. Configuration and Environment

All configuration is through environment variables loaded by `dotenv` at process start. `server.js` loads `.env` before any other `require`, ensuring all modules see `process.env` populated.

| Variable | Purpose |
|---|---|
| `NODE_ENV` | Switches morgan logging, error detail in responses |
| `PORT` | HTTP listen port (default 5000) |
| `MONGODB_URI` | MongoDB Atlas connection string |
| `JWT_SECRET` | HMAC signing key for JWT |
| `JWT_EXPIRES_IN` | Token lifetime (default `7d`) |
| `STRIPE_SECRET_KEY` | Stripe server-side API key (`sk_test_...`) |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret (`whsec_...`) |
| `STRIPE_CURRENCY` | Currency code (default `egp`) |
| `PLATFORM_FEE_PERCENTAGE` | Commission rate (default `10`) |
| `AI_SERVICE_URL` | Base URL of Python AI microservice |
| `CLIENT_URL` | Allowed CORS origin |

The Stripe config is **lazily validated** — `getStripe()` throws a descriptive `ApiError(500)` at first use rather than crashing the process at startup, making it possible to run the server locally without Stripe configured for non-payment features.

---

## 9. Dependencies

| Package | Role |
|---|---|
| `express@4` | HTTP framework |
| `mongoose@9` | MongoDB ODM, schema validation, middleware hooks, sessions |
| `jsonwebtoken@9` | JWT creation and verification |
| `bcryptjs@3` | Password hashing (pure-JS, no native bindings) |
| `stripe@20` | Stripe Node.js SDK — PaymentIntents, refunds, webhook verification |
| `express-async-errors@3` | Patches Express to auto-catch async errors — no try/catch needed |
| `express-validator@7` | Request body / param / query validation chains |
| `helmet@8` | Sets ~15 security headers (XSS, MIME, clickjacking protection) |
| `cors@2` | CORS headers with configurable origin |
| `morgan@1` | HTTP request logging |
| `dotenv@17` | `.env` file parsing into `process.env` |
| `axios@1` | HTTP client for AI microservice proxy calls |
| `http-status-codes@2` | Named HTTP status code constants |
| `nodemon@3` | Dev-time file watcher (devDependency only) |

---

## 10. Middleware and Error Handling

### Middleware Stack (in application order)

1. **`helmet()`** — Security response headers
2. **`cors()`** — CORS policy
3. **`morgan('dev')`** — Request logging (skipped in `test` env)
4. **`paymentRoutes`** — Registered early to preserve raw body for webhook
5. **`express.json({ limit: '10mb' })`** — JSON body parsing
6. **`express.urlencoded({ extended: true })`** — Form data parsing
7. **Route handlers** (per-route middleware chains)
8. **`notFound`** — Catches unmatched routes, throws `ApiError(404)`
9. **`errorHandler`** — Global error normalizer

### Per-Route Middleware Chains

Routes compose: `validate(rules)` → `protect` → `authorize('role')` → controller.

`validate()` runs all `express-validator` rules in parallel (`Promise.all`), collects failures, and throws `ApiError(422)` with a `{ field, message }[]` errors array before the controller executes.

### Error Normalisation (`error.middleware.js`)

The global handler normalises five Mongoose/JWT error types before responding:

| Error | Normalised to |
|---|---|
| `CastError` (invalid ObjectId in URL) | `ApiError(400)` |
| Mongoose duplicate key (`code 11000`) | `ApiError(409)` with field name extracted from `keyValue` |
| `ValidationError` (schema constraint) | `ApiError(400)` with all messages joined |
| `JsonWebTokenError` | `ApiError(401)` |
| `TokenExpiredError` | `ApiError(401)` |
| Any other | Wrapped in `ApiError(500, ..., isOperational=false)` |

Stack traces are logged to console only in `development` mode.

---

## 11. Full Request Lifecycle (Example: POST `/api/v1/bookings`)

1. **TCP/HTTP** — Request arrives at Node.js HTTP server.
2. **Helmet** — Adds security headers to the response.
3. **CORS** — Validates `Origin` header, sets `Access-Control-Allow-Origin`.
4. **Morgan** — Logs `POST /api/v1/bookings` with timestamp.
5. **`express.json()`** — Parses JSON body into `req.body`.
6. **Route match** — Router dispatches to the `/bookings` router.
7. **`validate(createValidation)`** — Runs `isMongoId()` on `workerId` and `serviceId`, `isISO8601()` on `scheduledDate`, `notEmpty` on `address`. If any fail → throws `ApiError(422)` → jumps to step 12.
8. **`protect`** — Extracts `Authorization: Bearer <token>`, calls `jwt.verify()`, attaches `{ id, role }` to `req.user`. If missing/invalid → throws `ApiError(401)`.
9. **`authorize('user')`** — Checks `req.user.role === 'user'`. Workers and admins get `403`.
10. **`bookingController.create`** — Calls `bookingService.createBooking(req.user.id, req.body)`.
11. **`bookingService.createBooking`**:
    - `User.findOne({ _id: workerId, role: 'worker', isActive: true, isVerified: true })` — throws `ApiError(404)` if not found
    - `Service.findOne({ _id: serviceId, isActive: true })` — throws `ApiError(404)` if not found
    - `Booking.create({ user, worker, service, scheduledDate, address, ..., totalPrice: service.basePrice })`
    - Returns populated booking document
12. **`ApiResponse.success(res, 201, '...', booking)`** — Sends `{ success: true, message: '...', data: booking }`.

**On any error:** `express-async-errors` catches the thrown `ApiError` and passes it to `errorHandler`. The handler normalises it and calls `ApiResponse.error(res, statusCode, message, errors[])`.

---

## 12. Notable Design Patterns and Engineering Practices

**Escrow + Wallet pattern** — The platform holds payment during service delivery. Worker sees a `pendingBalance` but cannot withdraw until the user confirms completion. `releasePending()` atomically decrements `pendingBalance` and increments `balance`. This pattern is cleanly encapsulated as instance methods on the Wallet model.

**MongoDB session transactions** — `payment.service.js` uses `mongoose.startSession()` + `session.withTransaction()` for all multi-document money operations. If any write fails, all are rolled back. This is critical for financial consistency — a crash between "update wallet" and "update payment status" would otherwise leave the system in an inconsistent state.

**Idempotent webhook processing** — Before processing `payment_intent.succeeded`, the service queries for an existing `Transaction` log with the same `intent.id`. If found, it returns early without double-crediting. This is the correct industry approach to Stripe webhook retry handling.

**Immutable transaction log** — The `Transaction` model's `pre('save')` hook throws if `this.isNew === false`, making every log entry append-only. The schema also sets `updatedAt: false` in timestamps. This is a genuine accounting ledger pattern.

**Lazy circular dependency resolution** — `dispute.service.js` and `payment.service.js` would create a circular `require` if both imported each other at module load time. The solution lazily calls `require('./payment.service')` inside methods — the module is loaded only on first method call, by which time both modules are fully initialized.

**isOperational error classification** — `ApiError(statusCode, msg, [], false)` marks programmer bugs (unexpected errors). This is the foundation for a production-grade pattern where only operational errors get user-facing messages; non-operational errors would trigger alerting and log the stack trace without leaking internals.

**Anti-pattern — cross-module DB access in controller** — Controllers in the `users` module directly import and query `Review`, `Booking`, `Payment`, and `Dispute` models for analytics. This crosses module boundaries without going through service layers, creating tight coupling between the users module and the payments/bookings modules. Analytics queries (`$group`, `$match`, `$sum`) embedded in a controller is a violation of the separation of concerns the rest of the codebase otherwise maintains consistently.

**Denormalised rating** — `User.averageRating` and `User.totalReviews` are maintained by a Mongoose `post('save')` hook in `review.model.js`. The hook uses a full `$avg` aggregation rather than incremental math, which is correct but fires a second aggregation query on every review save. There is no corresponding hook for review deletion — deleting a review would leave the cached rating stale.

**Pagination is consistent** — Every list endpoint uses the same `(page, limit, skip)` pattern and returns the same `{ data, pagination: { total, page, limit, totalPages } }` envelope.
