# SERVIO Backend & Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete Node.js + Express backend with MongoDB for the SERVIO home-services marketplace, replacing all hardcoded frontend data and localStorage auth with real API-driven persistence.

**Architecture:** Express REST API with Mongoose ODM, JWT auth with bcrypt password hashing, role-based middleware (customer/technician/admin). The backend serves JSON to the existing static HTML/JS frontend via fetch calls. MongoDB stores users, services, technicians, bookings, reviews, messages, and contact submissions.

**Tech Stack:** Node.js, Express, MongoDB, Mongoose, JWT (jsonwebtoken), bcrypt, dotenv, cors, express-validator, multer (file uploads)

---

## Current State Summary

SERVIO is a static HTML/CSS/JS home-services marketplace with:
- **20 HTML pages** across 3 roles (customer, technician, admin)
- **Hardcoded data** in `js/data/services-data.js` and `js/data/technicians-data.js`
- **localStorage-only auth** with demo accounts (login.js, signup.js)
- **No backend** — all state lives in the browser
- **Bilingual** (EN/AR) with `data-i18n` attributes
- **Features:** Smart Match, AI Estimator, Booking flow, Dashboards, Messaging, Reviews

---

## Tools, Skills, MCP Servers & Plugins Required

This section lists every skill, MCP server, plugin, and tool that will be used during implementation, with an explanation of **what it does** and **where it applies** in the SERVIO codebase and website.

### Superpowers Skills

| Skill | What It Does | Where It Applies in SERVIO |
|-------|-------------|---------------------------|
| `superpowers:executing-plans` | Executes this implementation plan task-by-task with review checkpoints. Ensures each task is completed, tested, and committed before moving on. | **The primary driver** — used to walk through all 27 tasks sequentially, from scaffolding through frontend integration. |
| `superpowers:subagent-driven-development` | Dispatches independent tasks to parallel sub-agents for faster execution. Each agent works in isolation on a separate task. | **Tasks 3–4** (models can be built in parallel), **Tasks 5–13** (independent route files), **Tasks 18–26** (independent frontend integration files). |
| `superpowers:dispatching-parallel-agents` | Coordinates 2+ independent agents that don't share state. Decides which tasks are safe to parallelize. | Same as above — used when multiple route files or frontend files can be created simultaneously without dependencies. |
| `superpowers:test-driven-development` | Write tests first, then implementation. Red → Green → Refactor cycle. | **Tasks 5–13** (each route should have curl/test verification), **Task 27** (final verification). Ensures every API endpoint works before moving to frontend integration. |
| `superpowers:systematic-debugging` | Structured debugging: reproduce → hypothesize → test → fix. No guessing. | **Any time** a route returns unexpected errors, MongoDB connection fails, JWT auth doesn't work, or frontend fetch calls fail during integration (Tasks 18–26). |
| `superpowers:verification-before-completion` | Run verification commands and confirm output before claiming work is done. Evidence before assertions. | **After every task** — run `curl` tests, check server logs, verify MongoDB documents exist. Especially critical at **Task 27** (final end-to-end verification). |
| `superpowers:brainstorming` | Explores user intent, requirements, and design before writing code. | **Before Task 14** (seed script — need to map existing hardcoded data to MongoDB documents), **Before Task 15** (Smart Match algorithm design), **Before Task 16** (AI Estimator logic). |
| `superpowers:requesting-code-review` | Reviews completed work against requirements before merging. | **After Task 14** (seed data complete), **After Task 17** (all backend routes done), **After Task 26** (all frontend integration done), **Task 27** (final review). |
| `superpowers:finishing-a-development-branch` | Guides completion of development work — merge, PR, or cleanup options. | **After Task 27** — decides whether to merge the backend branch, create a PR, or do final cleanup. |
| `superpowers:writing-plans` | Creates multi-step implementation plans from specs. | **Already used** to create this plan. Would be used again if scope changes require re-planning (e.g., adding WebSocket support for real-time messaging). |
| `superpowers:receiving-code-review` | Handles code review feedback with technical rigor — verifies suggestions before implementing. | **If review feedback is received** after `requesting-code-review` — ensures changes are validated, not blindly applied. |
| `superpowers:using-git-worktrees` | Creates isolated git worktrees for feature work. Code changes don't affect the main workspace until merged. | **Optional** — if you want the entire backend built in an isolated worktree so the existing static site keeps working during development. |

### MCP Servers

| MCP Server | What It Does | Where It Applies in SERVIO |
|------------|-------------|---------------------------|
| **context7** (`resolve-library-id` + `query-docs`) | Fetches **current, up-to-date documentation** for any library, framework, or SDK. Resolves the library ID first, then queries specific docs. | **Express** — correct middleware patterns, `Router()` usage, error handling (Tasks 1–2, 5–13). **Mongoose** — schema types, `pre` hooks, `populate()`, indexing, `findByIdAndUpdate` (Tasks 3–4, 14). **jsonwebtoken** — `jwt.sign()` / `jwt.verify()` options (Task 5). **bcryptjs** — hash rounds, `compare()` (Task 3). **express-validator** — `body()`, `validationResult()` chains (Tasks 5–13). **multer** — disk storage, file filter, limits (Task 2). **cors** — origin config, credentials (Task 1). |
| **Postman** (`createCollection`, `createCollectionRequest`, `createEnvironment`, `createMock`, etc.) | Creates **Postman API collections** for testing all endpoints, with pre-configured requests, environments (dev/prod), and mock servers. | **After Task 13** (all routes built) — generate a full Postman collection with requests for every endpoint in the API Reference table (28 endpoints). Set up `{{baseUrl}}`, `{{token}}` environment variables. Create mock server for frontend devs to work against before backend is deployed. |

### Claude Code Built-in Tools

| Tool | What It Does | Where It Applies in SERVIO |
|------|-------------|---------------------------|
| **Agent** (sub-agents) | Spawns parallel workers for independent tasks. Each agent gets its own context and can read/write files. | Parallel creation of model files (Task 3–4), route files (Tasks 5–13), frontend integration files (Tasks 18–26). |
| **Bash** | Executes shell commands — `npm install`, `npm run dev`, `npm run seed`, `curl` for API testing, `git` commands. | **Every task** — installing deps (Task 1), starting the server, running seed scripts (Task 14), testing endpoints with curl (Tasks 5–13), git commits. |
| **Read** | Reads existing files to understand current code before modifying. | **Tasks 18–26** — must read each existing frontend JS file (e.g., `js/html/login.js`, `js/html/booking.js`) before modifying it to replace localStorage with API calls. Also reads `js/data/services-data.js` and `js/data/technicians-data.js` for seed script (Task 14). |
| **Edit** | Makes targeted edits to existing files (find & replace). | **Tasks 18–26** — surgically replaces `localStorage.getItem()` calls with `fetch('/api/...')`, replaces hardcoded data references with API responses, updates form submit handlers. |
| **Write** | Creates new files from scratch. | **Tasks 1–14** — every new backend file (`server.js`, models, routes, middleware, seed script). **Task 17** — `js/html/api.js` helper module. |
| **Grep** | Searches file contents with regex. | Finding all `localStorage` references across frontend files (Task 17 planning), finding all hardcoded data imports, finding all form submit handlers that need API integration. |
| **Glob** | Finds files by name pattern. | `js/html/*.js` to list all frontend files needing integration, `server/src/models/*.js` to verify all models exist, `server/src/routes/*.js` to verify all routes exist. |
| **TodoWrite** | Tracks task progress with checkboxes. | **Throughout** — marks each of the 27 tasks and their sub-steps as complete, providing visible progress tracking. |

### NPM Packages (Dependencies)

| Package | What It Does | Where It's Used in the Code |
|---------|-------------|---------------------------|
| **express** | Web framework — handles HTTP routing, middleware pipeline, request/response. | `server/src/app.js` (app setup), all `routes/*.js` files (Router), `server.js` (listen). The backbone of the entire API. |
| **mongoose** | MongoDB ODM — defines schemas, validates data, provides query builder. | All `models/*.js` files (Schema, Model), `config/db.js` (connection), `seeds/seed.js` (bulk insert), all routes (queries). |
| **dotenv** | Loads `.env` file into `process.env`. | `server.js` — `import 'dotenv/config'` at entry point. Provides `PORT`, `MONGODB_URI`, `JWT_SECRET`, `JWT_EXPIRES_IN`. |
| **cors** | Enables Cross-Origin Resource Sharing so frontend (file:// or localhost:3000) can call the API (localhost:5000). | `app.js` — `app.use(cors())`. Without this, every frontend `fetch()` call would be blocked by the browser. |
| **bcryptjs** | Hashes passwords (bcrypt algorithm) and compares hashed passwords on login. | `models/User.js` — `pre('save')` hook hashes password, `comparePassword()` method verifies on login. |
| **jsonwebtoken** | Creates and verifies JWT tokens for stateless authentication. | `routes/auth.routes.js` — `signToken()` on register/login. `middleware/auth.js` — `jwt.verify()` on every protected route. |
| **express-validator** | Validates and sanitizes incoming request body fields (email format, required fields, min length). | All route files — `body('email').isEmail()`, `body('password').isLength({min: 8})`, etc. `middleware/validate.js` collects errors. |
| **multer** | Handles `multipart/form-data` file uploads (profile avatars, technician ID docs, portfolio images). | `middleware/upload.js` — configures storage, file filter, size limits. Used in `user.routes.js` for avatar upload and technician verification docs. |
| **nodemon** (dev) | Auto-restarts the server when files change during development. | `package.json` — `"dev": "nodemon src/server.js"`. Used during all development and testing. |

### What Each Part Does on the Website

| Backend Component | What Changes on the Website |
|------------------|---------------------------|
| **Auth API** (`/api/auth/*`) | Login and Signup pages become real — accounts persist in MongoDB instead of localStorage. Users stay logged in via JWT tokens stored in sessionStorage. Technicians see "pending approval" status. |
| **User Profile API** (`/api/users/*`) | Customer and Technician dashboards load real profile data. Profile editing actually saves. Password changes work server-side with proper hashing. |
| **Service API** (`/api/services/*`) | Services Marketplace page and Service Details page load dynamically from the database instead of hardcoded `services-data.js`. New services can be added via DB without code changes. |
| **Technician API** (`/api/technicians/*`) | Technician Listing page shows real, filterable data (by skill, area, price, rating). Technician Profile page loads from DB. Search and sort work server-side with pagination. |
| **Booking API** (`/api/bookings/*`) | Booking flow creates real records. Customer dashboard shows their bookings. Technician dashboard shows assigned jobs. Status updates (pending → confirmed → completed) work. Booking confirmation page shows real ref numbers. |
| **Review API** (`/api/reviews/*`) | Customers can submit reviews after completed bookings. Technician profiles show real reviews. Rating aggregation updates automatically. One review per booking enforced. |
| **Messaging API** (`/api/messages/*`) | Messages page shows real conversations between customers and technicians. Sending messages persists to DB. Conversations are auto-created when a booking is made. Unread indicators work. |
| **Admin API** (`/api/admin/*`) | Admin dashboard shows real statistics (total users, bookings, revenue). User management table lists real users with search. Admin can approve/suspend/delete technicians. Contact submissions are viewable. |
| **Contact API** (`/api/contact`) | Contact Us form saves submissions to the database instead of nowhere. Admin can view and manage contact messages. |
| **Smart Match API** (`/api/smart-match`) | Smart Match feature parses natural language queries and returns filtered technicians from the real database instead of hardcoded results. |
| **AI Estimator API** (`/api/estimate`) | AI Estimator returns price ranges calculated from real technician pricing data in the database, not hardcoded estimates. |
| **Seed Script** (`seeds/seed.js`) | Populates MongoDB with the same demo data currently hardcoded in `services-data.js` and `technicians-data.js`, plus demo users, so the site works immediately after setup. |
| **API Helper** (`js/html/api.js`) | A shared fetch wrapper used by all frontend JS files — handles `Authorization: Bearer <token>` headers, JSON parsing, and error responses in one place instead of duplicating fetch logic in 15+ files. |

---

## File Structure

```
server/
  package.json
  .env
  .env.example
  src/
    app.js                          # Express app setup (cors, json, routes)
    server.js                       # Entry point — connects to MongoDB, starts listening
    config/
      db.js                         # Mongoose connection logic
    middleware/
      auth.js                       # JWT verification middleware
      role.js                       # Role-based access control (requireRole)
      validate.js                   # express-validator error handler
      upload.js                     # Multer config for file uploads
      error-handler.js              # Global error handler
    models/
      User.js                       # Customer + Technician + Admin (discriminator or role field)
      Service.js                    # Service categories (plumbing, electrical, etc.)
      Booking.js                    # Booking records with status workflow
      Review.js                     # Reviews linked to booking + technician
      Conversation.js               # Chat conversations between users
      Message.js                    # Individual messages within conversations
      Contact.js                    # Contact form submissions
    routes/
      auth.routes.js                # POST /register, /login, /forgot-password
      user.routes.js                # GET/PUT /profile, GET /users (admin)
      service.routes.js             # GET /services, GET /services/:slug
      technician.routes.js          # GET /technicians, GET /technicians/:id, search/filter
      booking.routes.js             # POST /bookings, GET /bookings, PATCH /bookings/:id/status
      review.routes.js              # POST /reviews, GET /reviews/technician/:id
      message.routes.js             # GET /conversations, POST /conversations/:id/messages
      admin.routes.js               # GET /admin/stats, PATCH /admin/users/:id, technician approvals
      contact.routes.js             # POST /contact
      smart-match.routes.js         # POST /smart-match (filtered technician search)
      estimate.routes.js            # POST /estimate (AI cost estimation)
    seeds/
      seed.js                       # Seed script — populates DB from existing JS data files
```

Frontend files to modify (integration phase):
- `js/html/login.js` — replace localStorage auth with POST /api/auth/login
- `js/html/signup.js` — replace saveAccount() with POST /api/auth/register
- `js/html/booking.js` — POST /api/bookings on submit
- `js/html/customer-dashboard.js` — fetch bookings, profile from API
- `js/html/technician-dashboard.js` — fetch jobs, earnings, reviews from API
- `js/html/admin-dashboard.js` — fetch stats, users, approvals from API
- `js/html/messages.js` — fetch/send messages via API
- `js/html/smart-match.js` — POST /api/smart-match
- `js/html/ai-estimator.js` — POST /api/estimate
- `js/html/technician-listing.js` — fetch technicians from API
- `js/html/technician-profile.js` — fetch single technician from API
- `js/html/services-marketplace.js` — fetch services from API
- `js/html/service-details.js` — fetch single service from API
- `js/html/contact.js` — POST /api/contact
- `js/html/booking-details.js` — fetch booking details from API
- `js/html/booking-confirmation.js` — fetch confirmation data from API

---

## Task 1: Project Scaffolding & Dependencies

**Files:**
- Create: `server/package.json`
- Create: `server/.env.example`
- Create: `server/.env`
- Create: `server/src/server.js`
- Create: `server/src/app.js`
- Create: `server/src/config/db.js`

- [ ] **Step 1: Initialize the Node.js project**

```bash
cd server
npm init -y
```

- [ ] **Step 2: Install all dependencies**

```bash
npm install express mongoose dotenv cors bcryptjs jsonwebtoken express-validator multer
npm install --save-dev nodemon
```

- [ ] **Step 3: Create package.json scripts**

Edit `server/package.json` — set these scripts:

```json
{
  "name": "servio-backend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "seed": "node src/seeds/seed.js"
  }
}
```

- [ ] **Step 4: Create .env.example and .env**

`server/.env.example`:
```
PORT=5000
MONGODB_URI=mongodb://localhost:27017/servio
JWT_SECRET=change_me_to_a_random_string
JWT_EXPIRES_IN=7d
```

`server/.env` (same values, actual secret):
```
PORT=5000
MONGODB_URI=mongodb://localhost:27017/servio
JWT_SECRET=servio_dev_secret_key_2026
JWT_EXPIRES_IN=7d
```

- [ ] **Step 5: Create database connection — `server/src/config/db.js`**

```js
import mongoose from 'mongoose';
    
export async function connectDB() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/servio';
  await mongoose.connect(uri);
  console.log(`MongoDB connected: ${mongoose.connection.host}`);
}
```

- [ ] **Step 6: Create Express app — `server/src/app.js`**

```js
import express from 'express';
import cors from 'cors';

import authRoutes from './routes/auth.routes.js';
import userRoutes from './routes/user.routes.js';
import serviceRoutes from './routes/service.routes.js';
import technicianRoutes from './routes/technician.routes.js';
import bookingRoutes from './routes/booking.routes.js';
import reviewRoutes from './routes/review.routes.js';
import messageRoutes from './routes/message.routes.js';
import adminRoutes from './routes/admin.routes.js';
import contactRoutes from './routes/contact.routes.js';
import smartMatchRoutes from './routes/smart-match.routes.js';
import estimateRoutes from './routes/estimate.routes.js';
import { errorHandler } from './middleware/error-handler.js';

const app = express();

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/services', serviceRoutes);
app.use('/api/technicians', technicianRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/contact', contactRoutes);
app.use('/api/smart-match', smartMatchRoutes);
app.use('/api/estimate', estimateRoutes);

// Health check
app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

app.use(errorHandler);

export default app;
```

- [ ] **Step 7: Create server entry point — `server/src/server.js`**

```js
import 'dotenv/config';
import app from './app.js';
import { connectDB } from './config/db.js';

const PORT = process.env.PORT || 5000;

async function start() {
  await connectDB();
  app.listen(PORT, () => console.log(`SERVIO API running on port ${PORT}`));
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
```

- [ ] **Step 8: Verify the server starts (will fail on missing routes — that's expected)**

```bash
# From server/ directory — should connect to MongoDB and log port
# Routes will be added in subsequent tasks
```

- [ ] **Step 9: Commit**

```bash
git add server/package.json server/package-lock.json server/.env.example server/src/server.js server/src/app.js server/src/config/db.js
git commit -m "feat: scaffold Node.js backend with Express, Mongoose, and project structure"
```

> **Note:** Do NOT commit `server/.env` — add it to `.gitignore`.

---

## Task 2: Middleware (Auth, Roles, Validation, Error Handling, Upload)

**Files:**
- Create: `server/src/middleware/auth.js`
- Create: `server/src/middleware/role.js`
- Create: `server/src/middleware/validate.js`
- Create: `server/src/middleware/upload.js`
- Create: `server/src/middleware/error-handler.js`
- Create: `server/.gitignore`

- [ ] **Step 1: Create .gitignore**

`server/.gitignore`:
```
node_modules/
.env
uploads/
```

- [ ] **Step 2: Create JWT auth middleware — `server/src/middleware/auth.js`**

```js
import jwt from 'jsonwebtoken';

export function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = header.split(' ')[1];
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = payload; // { id, role, email }
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}
```

- [ ] **Step 3: Create role guard middleware — `server/src/middleware/role.js`**

```js
export function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden — insufficient role' });
    }
    next();
  };
}
```

- [ ] **Step 4: Create validation middleware — `server/src/middleware/validate.js`**

```js
import { validationResult } from 'express-validator';

export function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}
```

- [ ] **Step 5: Create file upload middleware — `server/src/middleware/upload.js`**

```js
import multer from 'multer';
import path from 'path';

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, 'uploads/'),
  filename: (_req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  },
});

function fileFilter(_req, file, cb) {
  const allowed = /jpeg|jpg|png|webp|pdf/;
  const ext = allowed.test(path.extname(file.originalname).toLowerCase());
  const mime = allowed.test(file.mimetype);
  cb(null, ext && mime);
}

export const upload = multer({ storage, fileFilter, limits: { fileSize: 5 * 1024 * 1024 } });
```

- [ ] **Step 6: Create global error handler — `server/src/middleware/error-handler.js`**

```js
export function errorHandler(err, _req, res, _next) {
  console.error(err.stack || err);
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
  });
}
```

- [ ] **Step 7: Create uploads directory**

```bash
mkdir -p server/uploads
touch server/uploads/.gitkeep
```

- [ ] **Step 8: Commit**

```bash
git add server/src/middleware/ server/.gitignore server/uploads/.gitkeep
git commit -m "feat: add auth, role, validation, upload, and error-handling middleware"
```

---

## Task 3: User Model (Mongoose Schema)

**Files:**
- Create: `server/src/models/User.js`

- [ ] **Step 1: Create User model — `server/src/models/User.js`**

This single model handles all 3 roles via a `role` field. Technician-specific fields are only required when `role === 'technician'`.

```js
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const userSchema = new mongoose.Schema({
  fullName:  { type: String, required: true, trim: true },
  email:     { type: String, required: true, unique: true, lowercase: true, trim: true },
  phone:     { type: String, required: true, trim: true },
  password:  { type: String, required: true, minlength: 8 },
  role:      { type: String, enum: ['customer', 'technician', 'admin'], default: 'customer' },

  // Customer fields
  address:   { type: String, trim: true, default: '' },

  // Technician fields (only relevant when role === 'technician')
  title:       { type: String, trim: true, default: '' },           // e.g. "Master Plumber"
  titleAr:     { type: String, trim: true, default: '' },
  skills:      [{ type: String }],                                   // ["Plumbing", "HVAC"]
  serviceArea: { type: String, trim: true, default: '' },           // "Maadi, Cairo"
  serviceAreaAr: { type: String, trim: true, default: '' },
  availability: { type: String, enum: ['weekdays', 'weekends', 'both', ''], default: '' },
  hourlyRate:  { type: Number, default: 0 },
  currency:    { type: String, default: 'EGP' },
  yearsExp:    { type: Number, default: 0 },
  rating:      { type: Number, default: 0, min: 0, max: 5 },
  reviewCount: { type: Number, default: 0 },
  jobSuccess:  { type: String, default: '0%' },
  responseTime: { type: String, default: '' },
  verified:    { type: Boolean, default: false },
  status:      { type: String, enum: ['active', 'pending', 'suspended'], default: 'active' },
  avatar:      { type: String, default: '' },
  cover:       { type: String, default: '' },
  bioEn:       { type: String, default: '' },
  bioAr:       { type: String, default: '' },
  descEn:      { type: String, default: '' },
  descAr:      { type: String, default: '' },
  memberSince: { type: String, default: '' },
  memberSinceAr: { type: String, default: '' },

  // Technician verification docs
  idFrontUrl:  { type: String, default: '' },
  idBackUrl:   { type: String, default: '' },
  selfieUrl:   { type: String, default: '' },
  portfolioUrls: [{ type: String }],

  // Technician service sub-items (embedded)
  servicesList: [{
    nameEn:     { type: String },
    nameAr:     { type: String },
    priceEn:    { type: String },
    priceAr:    { type: String },
    durationEn: { type: String },
    durationAr: { type: String },
    emergency:  { type: Boolean, default: false },
  }],
}, { timestamps: true });

// Hash password before save
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

// Compare password method
userSchema.methods.comparePassword = async function(candidate) {
  return bcrypt.compare(candidate, this.password);
};

// Strip password from JSON output
userSchema.methods.toJSON = function() {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

const User = mongoose.model('User', userSchema);
export default User;
```

- [ ] **Step 2: Verify model compiles (import it in a scratch test)**

```bash
cd server && node -e "import('./src/models/User.js').then(() => console.log('User model OK'))"
```

- [ ] **Step 3: Commit**

```bash
git add server/src/models/User.js
git commit -m "feat: add User model with role-based fields and password hashing"
```

---

## Task 4: Remaining Models (Service, Booking, Review, Conversation, Message, Contact)

**Files:**
- Create: `server/src/models/Service.js`
- Create: `server/src/models/Booking.js`
- Create: `server/src/models/Review.js`
- Create: `server/src/models/Conversation.js`
- Create: `server/src/models/Message.js`
- Create: `server/src/models/Contact.js`

- [ ] **Step 1: Create Service model — `server/src/models/Service.js`**

```js
import mongoose from 'mongoose';

const bilingualText = (required = false) => ({
  en: { type: String, required, trim: true, default: '' },
  ar: { type: String, trim: true, default: '' },
});

const serviceSchema = new mongoose.Schema({
  slug:       { type: String, required: true, unique: true },   // "plumbing", "electrical"
  title:      bilingualText(true),
  lead:       bilingualText(),
  priceBadge: bilingualText(),
  findBtn:    bilingualText(),
  ctaTitle:   bilingualText(),
  ctaSub:     bilingualText(),
  ctaBtn:     bilingualText(),
  heroImage:  { type: String, default: '' },
  included: [{
    iconKey: { type: String },                                   // "wrench", "bolt", etc.
    title:   bilingualText(),
    desc:    bilingualText(),
  }],
  pricing: [{
    tier:     bilingualText(),
    price:    bilingualText(),
    jobs:     bilingualText(),
    featured: { type: Boolean, default: false },
  }],
  faqs: [{
    question: bilingualText(),
    answer:   bilingualText(),
  }],
  reviews: [{
    initials: { type: String },
    stars:    { type: Number },
    name:     bilingualText(),
    quote:    bilingualText(),
  }],
  technicianIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
}, { timestamps: true });

const Service = mongoose.model('Service', serviceSchema);
export default Service;
```

- [ ] **Step 2: Create Booking model — `server/src/models/Booking.js`**

```js
import mongoose from 'mongoose';

const bookingSchema = new mongoose.Schema({
  bookingRef:   { type: String, required: true, unique: true },   // "S-2847"
  customer:     { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  technician:   { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  serviceType:  { type: String, required: true },                  // "plumbing", "electrical"
  date:         { type: Date, required: true },
  time:         { type: String, required: true },                  // "09:00"
  address:      { type: String, required: true },
  notes:        { type: String, default: '' },
  payment:      { type: String, enum: ['online', 'cash'], default: 'online' },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'in-progress', 'completed', 'cancelled'],
    default: 'pending',
  },
  totalPrice:   { type: Number, default: 0 },
  currency:     { type: String, default: 'EGP' },
}, { timestamps: true });

// Auto-generate booking ref before save
bookingSchema.pre('save', async function(next) {
  if (this.isNew && !this.bookingRef) {
    const count = await mongoose.model('Booking').countDocuments();
    this.bookingRef = `S-${(2847 + count).toString()}`;
  }
  next();
});

const Booking = mongoose.model('Booking', bookingSchema);
export default Booking;
```

- [ ] **Step 3: Create Review model — `server/src/models/Review.js`**

```js
import mongoose from 'mongoose';

const reviewSchema = new mongoose.Schema({
  booking:    { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', required: true },
  customer:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  technician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  rating:     { type: Number, required: true, min: 1, max: 5 },
  comment:    { type: String, default: '', maxlength: 1000 },
}, { timestamps: true });

// One review per booking
reviewSchema.index({ booking: 1, customer: 1 }, { unique: true });

const Review = mongoose.model('Review', reviewSchema);
export default Review;
```

- [ ] **Step 4: Create Conversation model — `server/src/models/Conversation.js`**

```js
import mongoose from 'mongoose';

const conversationSchema = new mongoose.Schema({
  participants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  booking:      { type: mongoose.Schema.Types.ObjectId, ref: 'Booking' },
  lastMessage:  { type: String, default: '' },
  lastMessageAt: { type: Date, default: Date.now },
}, { timestamps: true });

conversationSchema.index({ participants: 1 });

const Conversation = mongoose.model('Conversation', conversationSchema);
export default Conversation;
```

- [ ] **Step 5: Create Message model — `server/src/models/Message.js`**

```js
import mongoose from 'mongoose';

const messageSchema = new mongoose.Schema({
  conversation: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation', required: true },
  sender:       { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  text:         { type: String, required: true, maxlength: 2000 },
  read:         { type: Boolean, default: false },
}, { timestamps: true });

messageSchema.index({ conversation: 1, createdAt: 1 });

const Message = mongoose.model('Message', messageSchema);
export default Message;
```

- [ ] **Step 6: Create Contact model — `server/src/models/Contact.js`**

```js
import mongoose from 'mongoose';

const contactSchema = new mongoose.Schema({
  name:    { type: String, required: true, trim: true },
  email:   { type: String, required: true, trim: true },
  subject: { type: String, required: true, trim: true },
  message: { type: String, required: true, maxlength: 5000 },
  status:  { type: String, enum: ['new', 'read', 'resolved'], default: 'new' },
}, { timestamps: true });

const Contact = mongoose.model('Contact', contactSchema);
export default Contact;
```

- [ ] **Step 7: Commit**

```bash
git add server/src/models/
git commit -m "feat: add Service, Booking, Review, Conversation, Message, Contact models"
```

---

## Task 5: Auth Routes (Register + Login)

**Files:**
- Create: `server/src/routes/auth.routes.js`

- [ ] **Step 1: Create auth routes — `server/src/routes/auth.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import { validate } from '../middleware/validate.js';

const router = Router();

function signToken(user) {
  return jwt.sign(
    { id: user._id, role: user.role, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

// ── Register ────────────────────────────────────────────
router.post('/register', [
  body('fullName').trim().isLength({ min: 2 }).withMessage('Full name is required'),
  body('email').isEmail().withMessage('Valid email required'),
  body('phone').trim().isLength({ min: 9 }).withMessage('Valid phone required'),
  body('password').isLength({ min: 8 }).withMessage('Password must be 8+ characters'),
  body('role').isIn(['customer', 'technician']).withMessage('Role must be customer or technician'),
  validate,
], async (req, res, next) => {
  try {
    const { fullName, email, phone, password, role } = req.body;

    const exists = await User.findOne({ email: email.toLowerCase() });
    if (exists) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const userData = { fullName, email, phone, password, role };

    // Technician extra fields
    if (role === 'technician') {
      userData.skills = req.body.skills || [];
      userData.serviceArea = req.body.serviceArea || '';
      userData.availability = req.body.availability || '';
      userData.hourlyRate = req.body.hourlyRate || 0;
      userData.currency = req.body.currency || 'EGP';
      userData.status = 'pending'; // technicians need admin approval
    }

    // Customer extra fields
    if (role === 'customer') {
      userData.address = req.body.address || '';
    }

    const user = await User.create(userData);
    const token = signToken(user);

    res.status(201).json({
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        status: user.status,
      },
    });
  } catch (err) {
    next(err);
  }
});

// ── Login ───────────────────────────────────────────────
router.post('/login', [
  body('email').isEmail().withMessage('Valid email required'),
  body('password').notEmpty().withMessage('Password required'),
  validate,
], async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email: email.toLowerCase() }).select('+password');
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const match = await user.comparePassword(password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Block pending technicians
    if (user.role === 'technician' && user.status === 'pending') {
      return res.status(403).json({
        error: 'Your account is pending approval. Our team will notify you within 24 hours.',
      });
    }

    const token = signToken(user);

    res.json({
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        status: user.status,
      },
    });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Test registration with curl**

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"fullName":"Test User","email":"test@test.com","phone":"01012345678","password":"test1234","role":"customer"}'
```

Expected: 201 with `{ token, user: { id, fullName, email, role } }`

- [ ] **Step 3: Test login with curl**

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test1234"}'
```

Expected: 200 with `{ token, user }`

- [ ] **Step 4: Commit**

```bash
git add server/src/routes/auth.routes.js
git commit -m "feat: add auth routes — register and login with JWT"
```

---

## Task 6: User Profile Routes

**Files:**
- Create: `server/src/routes/user.routes.js`

- [ ] **Step 1: Create user routes — `server/src/routes/user.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import User from '../models/User.js';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';

const router = Router();

// ── Get own profile ─────────────────────────────────────
router.get('/profile', authenticate, async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (err) {
    next(err);
  }
});

// ── Update own profile ──────────────────────────────────
router.put('/profile', authenticate, [
  body('fullName').optional().trim().isLength({ min: 2 }),
  body('phone').optional().trim().isLength({ min: 9 }),
  body('address').optional().trim(),
  validate,
], async (req, res, next) => {
  try {
    const allowed = ['fullName', 'phone', 'address', 'avatar', 'bioEn', 'bioAr',
      'serviceArea', 'serviceAreaAr', 'availability', 'hourlyRate', 'currency',
      'title', 'titleAr', 'descEn', 'descAr', 'skills', 'servicesList'];

    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    const user = await User.findByIdAndUpdate(req.user.id, updates, {
      new: true, runValidators: true,
    }).select('-password');

    res.json(user);
  } catch (err) {
    next(err);
  }
});

// ── Change password ─────────────────────────────────────
router.put('/change-password', authenticate, [
  body('currentPassword').notEmpty(),
  body('newPassword').isLength({ min: 8 }),
  validate,
], async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    const match = await user.comparePassword(req.body.currentPassword);
    if (!match) return res.status(400).json({ error: 'Current password is incorrect' });

    user.password = req.body.newPassword;
    await user.save();
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/user.routes.js
git commit -m "feat: add user profile routes — get, update, change password"
```

---

## Task 7: Service Routes

**Files:**
- Create: `server/src/routes/service.routes.js`

- [ ] **Step 1: Create service routes — `server/src/routes/service.routes.js`**

```js
import { Router } from 'express';
import Service from '../models/Service.js';

const router = Router();

// ── List all services ───────────────────────────────────
router.get('/', async (_req, res, next) => {
  try {
    const services = await Service.find().select('slug title lead priceBadge heroImage');
    res.json(services);
  } catch (err) {
    next(err);
  }
});

// ── Get single service by slug ──────────────────────────
router.get('/:slug', async (req, res, next) => {
  try {
    const service = await Service.findOne({ slug: req.params.slug })
      .populate('technicianIds', 'fullName avatar rating reviewCount area areaAr title titleAr verified');
    if (!service) return res.status(404).json({ error: 'Service not found' });
    res.json(service);
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/service.routes.js
git commit -m "feat: add service routes — list all and get by slug"
```

---

## Task 8: Technician Routes (Listing, Profile, Search/Filter)

**Files:**
- Create: `server/src/routes/technician.routes.js`

- [ ] **Step 1: Create technician routes — `server/src/routes/technician.routes.js`**

```js
import { Router } from 'express';
import User from '../models/User.js';

const router = Router();

// ── List technicians (with filtering) ───────────────────
router.get('/', async (req, res, next) => {
  try {
    const { skill, area, minRating, maxPrice, sort, page = 1, limit = 12 } = req.query;

    const filter = { role: 'technician', status: 'active' };

    if (skill) filter.skills = { $in: [skill] };
    if (area) filter.serviceArea = { $regex: area, $options: 'i' };
    if (minRating) filter.rating = { $gte: Number(minRating) };
    if (maxPrice) filter.hourlyRate = { $lte: Number(maxPrice) };

    let sortObj = { rating: -1 };
    if (sort === 'price-low') sortObj = { hourlyRate: 1 };
    if (sort === 'price-high') sortObj = { hourlyRate: -1 };
    if (sort === 'experience') sortObj = { yearsExp: -1 };
    if (sort === 'reviews') sortObj = { reviewCount: -1 };

    const skip = (Number(page) - 1) * Number(limit);

    const [technicians, total] = await Promise.all([
      User.find(filter)
        .select('-password -idFrontUrl -idBackUrl -selfieUrl')
        .sort(sortObj)
        .skip(skip)
        .limit(Number(limit)),
      User.countDocuments(filter),
    ]);

    res.json({
      technicians,
      total,
      page: Number(page),
      totalPages: Math.ceil(total / Number(limit)),
    });
  } catch (err) {
    next(err);
  }
});

// ── Get single technician profile ───────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const tech = await User.findOne({
      _id: req.params.id,
      role: 'technician',
    }).select('-password -idFrontUrl -idBackUrl -selfieUrl');

    if (!tech) return res.status(404).json({ error: 'Technician not found' });
    res.json(tech);
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/technician.routes.js
git commit -m "feat: add technician routes — listing with filters and profile view"
```

---

## Task 9: Booking Routes

**Files:**
- Create: `server/src/routes/booking.routes.js`

- [ ] **Step 1: Create booking routes — `server/src/routes/booking.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import Booking from '../models/Booking.js';
import Conversation from '../models/Conversation.js';
import { authenticate } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate } from '../middleware/validate.js';

const router = Router();

// ── Create booking (customer) ───────────────────────────
router.post('/', authenticate, requireRole('customer'), [
  body('serviceType').notEmpty(),
  body('date').notEmpty(),
  body('time').notEmpty(),
  body('address').notEmpty(),
  validate,
], async (req, res, next) => {
  try {
    const { serviceType, date, time, address, notes, payment, technicianId } = req.body;

    const booking = await Booking.create({
      customer: req.user.id,
      technician: technicianId || null,
      serviceType,
      date: new Date(date),
      time,
      address,
      notes: notes || '',
      payment: payment || 'online',
    });

    // Auto-create conversation if technician assigned
    if (technicianId) {
      await Conversation.create({
        participants: [req.user.id, technicianId],
        booking: booking._id,
        lastMessage: `New booking for ${serviceType}`,
        lastMessageAt: new Date(),
      });
    }

    res.status(201).json(booking);
  } catch (err) {
    next(err);
  }
});

// ── List bookings for current user ──────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { status, page = 1, limit = 10 } = req.query;
    const filter = {};

    if (req.user.role === 'customer') {
      filter.customer = req.user.id;
    } else if (req.user.role === 'technician') {
      filter.technician = req.user.id;
    }

    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);

    const [bookings, total] = await Promise.all([
      Booking.find(filter)
        .populate('customer', 'fullName email phone')
        .populate('technician', 'fullName email phone avatar title')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Booking.countDocuments(filter),
    ]);

    res.json({ bookings, total, page: Number(page), totalPages: Math.ceil(total / Number(limit)) });
  } catch (err) {
    next(err);
  }
});

// ── Get single booking ──────────────────────────────────
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate('customer', 'fullName email phone address')
      .populate('technician', 'fullName email phone avatar title rating');

    if (!booking) return res.status(404).json({ error: 'Booking not found' });

    // Ensure user is a participant or admin
    const isOwner = [booking.customer?._id?.toString(), booking.technician?._id?.toString()].includes(req.user.id);
    if (!isOwner && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json(booking);
  } catch (err) {
    next(err);
  }
});

// ── Update booking status ───────────────────────────────
router.patch('/:id/status', authenticate, [
  body('status').isIn(['confirmed', 'in-progress', 'completed', 'cancelled']),
  validate,
], async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found' });

    // Only technician, customer (cancel), or admin can update
    const isTech = booking.technician?.toString() === req.user.id;
    const isCust = booking.customer.toString() === req.user.id;
    const isAdmin = req.user.role === 'admin';

    if (!isTech && !isCust && !isAdmin) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Customers can only cancel
    if (isCust && req.body.status !== 'cancelled') {
      return res.status(403).json({ error: 'Customers can only cancel bookings' });
    }

    booking.status = req.body.status;
    if (req.body.totalPrice) booking.totalPrice = req.body.totalPrice;
    await booking.save();

    res.json(booking);
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/booking.routes.js
git commit -m "feat: add booking routes — CRUD with status workflow and role guards"
```

---

## Task 10: Review Routes

**Files:**
- Create: `server/src/routes/review.routes.js`

- [ ] **Step 1: Create review routes — `server/src/routes/review.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import Review from '../models/Review.js';
import User from '../models/User.js';
import Booking from '../models/Booking.js';
import { authenticate } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate } from '../middleware/validate.js';

const router = Router();

// ── Submit a review (customer, after completed booking) ─
router.post('/', authenticate, requireRole('customer'), [
  body('bookingId').notEmpty(),
  body('rating').isInt({ min: 1, max: 5 }),
  body('comment').optional().isLength({ max: 1000 }),
  validate,
], async (req, res, next) => {
  try {
    const { bookingId, rating, comment } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    if (booking.customer.toString() !== req.user.id) {
      return res.status(403).json({ error: 'Not your booking' });
    }
    if (booking.status !== 'completed') {
      return res.status(400).json({ error: 'Can only review completed bookings' });
    }

    const review = await Review.create({
      booking: bookingId,
      customer: req.user.id,
      technician: booking.technician,
      rating,
      comment: comment || '',
    });

    // Update technician's average rating
    const techReviews = await Review.find({ technician: booking.technician });
    const avgRating = techReviews.reduce((sum, r) => sum + r.rating, 0) / techReviews.length;

    await User.findByIdAndUpdate(booking.technician, {
      rating: Math.round(avgRating * 10) / 10,
      reviewCount: techReviews.length,
    });

    res.status(201).json(review);
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ error: 'You already reviewed this booking' });
    }
    next(err);
  }
});

// ── Get reviews for a technician ────────────────────────
router.get('/technician/:id', async (req, res, next) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    const [reviews, total] = await Promise.all([
      Review.find({ technician: req.params.id })
        .populate('customer', 'fullName')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Review.countDocuments({ technician: req.params.id }),
    ]);

    res.json({ reviews, total, page: Number(page), totalPages: Math.ceil(total / Number(limit)) });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/review.routes.js
git commit -m "feat: add review routes — submit review with auto rating recalculation"
```

---

## Task 11: Message & Conversation Routes

**Files:**
- Create: `server/src/routes/message.routes.js`

- [ ] **Step 1: Create message routes — `server/src/routes/message.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import Conversation from '../models/Conversation.js';
import Message from '../models/Message.js';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';

const router = Router();

// ── List conversations for current user ─────────────────
router.get('/conversations', authenticate, async (req, res, next) => {
  try {
    const conversations = await Conversation.find({ participants: req.user.id })
      .populate('participants', 'fullName avatar')
      .populate('booking', 'bookingRef serviceType status')
      .sort({ lastMessageAt: -1 });

    // Count unread per conversation
    const enriched = await Promise.all(conversations.map(async (conv) => {
      const unreadCount = await Message.countDocuments({
        conversation: conv._id,
        sender: { $ne: req.user.id },
        read: false,
      });
      return { ...conv.toObject(), unreadCount };
    }));

    res.json(enriched);
  } catch (err) {
    next(err);
  }
});

// ── Get messages for a conversation ─────────────────────
router.get('/conversations/:id', authenticate, async (req, res, next) => {
  try {
    const conv = await Conversation.findById(req.params.id);
    if (!conv) return res.status(404).json({ error: 'Conversation not found' });

    const isParticipant = conv.participants.some(p => p.toString() === req.user.id);
    if (!isParticipant) return res.status(403).json({ error: 'Forbidden' });

    // Mark unread messages as read
    await Message.updateMany(
      { conversation: conv._id, sender: { $ne: req.user.id }, read: false },
      { read: true }
    );

    const messages = await Message.find({ conversation: conv._id })
      .populate('sender', 'fullName')
      .sort({ createdAt: 1 });

    res.json(messages);
  } catch (err) {
    next(err);
  }
});

// ── Send a message ──────────────────────────────────────
router.post('/conversations/:id/messages', authenticate, [
  body('text').trim().isLength({ min: 1, max: 2000 }),
  validate,
], async (req, res, next) => {
  try {
    const conv = await Conversation.findById(req.params.id);
    if (!conv) return res.status(404).json({ error: 'Conversation not found' });

    const isParticipant = conv.participants.some(p => p.toString() === req.user.id);
    if (!isParticipant) return res.status(403).json({ error: 'Forbidden' });

    const message = await Message.create({
      conversation: conv._id,
      sender: req.user.id,
      text: req.body.text,
    });

    // Update conversation's last message
    conv.lastMessage = req.body.text;
    conv.lastMessageAt = new Date();
    await conv.save();

    const populated = await message.populate('sender', 'fullName');
    res.status(201).json(populated);
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/message.routes.js
git commit -m "feat: add messaging routes — conversations list, messages, send with read tracking"
```

---

## Task 12: Admin Routes

**Files:**
- Create: `server/src/routes/admin.routes.js`

- [ ] **Step 1: Create admin routes — `server/src/routes/admin.routes.js`**

```js
import { Router } from 'express';
import User from '../models/User.js';
import Booking from '../models/Booking.js';
import Contact from '../models/Contact.js';
import { authenticate } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';

const router = Router();

// All admin routes require admin role
router.use(authenticate, requireRole('admin'));

// ── Dashboard stats ─────────────────────────────────────
router.get('/stats', async (_req, res, next) => {
  try {
    const [totalUsers, totalTechnicians, totalCustomers, pendingTechnicians,
           totalBookings, activeBookings, completedBookings, totalRevenue] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ role: 'technician', status: 'active' }),
      User.countDocuments({ role: 'customer' }),
      User.countDocuments({ role: 'technician', status: 'pending' }),
      Booking.countDocuments(),
      Booking.countDocuments({ status: { $in: ['pending', 'confirmed', 'in-progress'] } }),
      Booking.countDocuments({ status: 'completed' }),
      Booking.aggregate([
        { $match: { status: 'completed' } },
        { $group: { _id: null, total: { $sum: '$totalPrice' } } },
      ]),
    ]);

    res.json({
      totalUsers,
      totalTechnicians,
      totalCustomers,
      pendingTechnicians,
      totalBookings,
      activeBookings,
      completedBookings,
      totalRevenue: totalRevenue[0]?.total || 0,
    });
  } catch (err) {
    next(err);
  }
});

// ── List all users (with search + filter) ───────────────
router.get('/users', async (req, res, next) => {
  try {
    const { role, status, search, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (role) filter.role = role;
    if (status) filter.status = status;
    if (search) {
      filter.$or = [
        { fullName: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
      ];
    }

    const skip = (Number(page) - 1) * Number(limit);

    const [users, total] = await Promise.all([
      User.find(filter).select('-password').sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
      User.countDocuments(filter),
    ]);

    res.json({ users, total, page: Number(page), totalPages: Math.ceil(total / Number(limit)) });
  } catch (err) {
    next(err);
  }
});

// ── Update user status (approve/suspend technician) ─────
router.patch('/users/:id', async (req, res, next) => {
  try {
    const { status, verified } = req.body;
    const updates = {};
    if (status) updates.status = status;
    if (verified !== undefined) updates.verified = verified;

    const user = await User.findByIdAndUpdate(req.params.id, updates, { new: true }).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });

    res.json(user);
  } catch (err) {
    next(err);
  }
});

// ── Delete user ─────────────────────────────────────────
router.delete('/users/:id', async (req, res, next) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ message: 'User deleted' });
  } catch (err) {
    next(err);
  }
});

// ── List contact submissions ────────────────────────────
router.get('/contacts', async (req, res, next) => {
  try {
    const contacts = await Contact.find().sort({ createdAt: -1 });
    res.json(contacts);
  } catch (err) {
    next(err);
  }
});

// ── List all bookings (admin view) ──────────────────────
router.get('/bookings', async (req, res, next) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const filter = {};
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);

    const [bookings, total] = await Promise.all([
      Booking.find(filter)
        .populate('customer', 'fullName email')
        .populate('technician', 'fullName email')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Booking.countDocuments(filter),
    ]);

    res.json({ bookings, total, page: Number(page), totalPages: Math.ceil(total / Number(limit)) });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Commit**

```bash
git add server/src/routes/admin.routes.js
git commit -m "feat: add admin routes — stats, user management, bookings, contact submissions"
```

---

## Task 13: Contact, Smart Match, and Estimate Routes

**Files:**
- Create: `server/src/routes/contact.routes.js`
- Create: `server/src/routes/smart-match.routes.js`
- Create: `server/src/routes/estimate.routes.js`

- [ ] **Step 1: Create contact routes — `server/src/routes/contact.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import Contact from '../models/Contact.js';
import { validate } from '../middleware/validate.js';

const router = Router();

router.post('/', [
  body('name').trim().notEmpty().withMessage('Name required'),
  body('email').isEmail().withMessage('Valid email required'),
  body('subject').trim().notEmpty().withMessage('Subject required'),
  body('message').trim().isLength({ min: 10, max: 5000 }).withMessage('Message required (10-5000 chars)'),
  validate,
], async (req, res, next) => {
  try {
    const { name, email, subject, message } = req.body;
    const contact = await Contact.create({ name, email, subject, message });
    res.status(201).json({ message: 'Message sent successfully', id: contact._id });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 2: Create smart-match routes — `server/src/routes/smart-match.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import User from '../models/User.js';
import { validate } from '../middleware/validate.js';

const router = Router();

// ── Smart Match — search technicians by natural language query ──
router.post('/', [
  body('query').trim().isLength({ min: 3 }).withMessage('Query too short'),
  validate,
], async (req, res, next) => {
  try {
    const { query } = req.body;
    const q = query.toLowerCase();

    // Extract criteria from natural language
    const filter = { role: 'technician', status: 'active' };

    // Skill detection
    const skillMap = {
      plumb: 'Plumbing', electric: 'Electrical', hvac: 'HVAC', ac: 'HVAC',
      paint: 'Painting', carpent: 'Carpentry', clean: 'Cleaning',
      roof: 'Roofing', floor: 'Flooring', appliance: 'Appliance Repair',
      landscap: 'Landscaping', maintenance: 'General Maintenance',
    };

    for (const [keyword, skill] of Object.entries(skillMap)) {
      if (q.includes(keyword)) {
        filter.skills = { $in: [skill] };
        break;
      }
    }

    // Location detection (Cairo areas)
    const areas = ['maadi', 'nasr city', 'zamalek', 'dokki', 'heliopolis',
      'new cairo', '6th october', 'october', 'madinaty', 'rehab', 'tagamoa',
      'mohandessin', 'giza', 'downtown'];

    for (const area of areas) {
      if (q.includes(area)) {
        filter.serviceArea = { $regex: area, $options: 'i' };
        break;
      }
    }

    // Budget detection
    const budgetMatch = q.match(/(\d+)\s*(egp|pound|جنيه)/i) || q.match(/under\s*(\d+)/i) || q.match(/exceed\s*(\d+)/i);
    if (budgetMatch) {
      filter.hourlyRate = { $lte: Number(budgetMatch[1]) };
    }

    const technicians = await User.find(filter)
      .select('fullName title titleAr rating reviewCount serviceArea serviceAreaAr hourlyRate availability avatar verified yearsExp skills responseTime')
      .sort({ rating: -1, reviewCount: -1 })
      .limit(5);

    // Simple match score (percentage based on how many criteria matched)
    const results = technicians.map(tech => {
      let score = 70; // base score
      if (filter.skills && tech.skills.some(s => s === filter.skills.$in?.[0])) score += 10;
      if (filter.serviceArea) score += 10;
      if (filter.hourlyRate) score += 10;
      return { ...tech.toObject(), matchScore: Math.min(score, 99) };
    });

    res.json({ results, total: results.length });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 3: Create estimate routes — `server/src/routes/estimate.routes.js`**

```js
import { Router } from 'express';
import { body } from 'express-validator';
import { validate } from '../middleware/validate.js';

const router = Router();

// Price estimation based on service type and parameters
const PRICE_RANGES = {
  plumbing:    { base: 200, perHour: 150, emergency: 1.5 },
  electrical:  { base: 300, perHour: 200, emergency: 1.5 },
  hvac:        { base: 400, perHour: 250, emergency: 1.8 },
  painting:    { base: 500, perHour: 120, emergency: 1.3 },
  carpentry:   { base: 200, perHour: 130, emergency: 1.4 },
  cleaning:    { base: 300, perHour: 100, emergency: 1.2 },
};

router.post('/', [
  body('serviceType').notEmpty(),
  body('description').trim().isLength({ min: 10 }),
  validate,
], async (req, res, next) => {
  try {
    const { serviceType, description, urgency, area } = req.body;
    const desc = description.toLowerCase();

    const range = PRICE_RANGES[serviceType] || PRICE_RANGES.plumbing;
    let estimatedHours = 2; // default

    // Estimate complexity from description length/keywords
    if (desc.includes('full') || desc.includes('complete') || desc.includes('rewrite')) estimatedHours = 6;
    else if (desc.includes('install') || desc.includes('replace')) estimatedHours = 4;
    else if (desc.includes('repair') || desc.includes('fix')) estimatedHours = 2;
    else if (desc.includes('inspect') || desc.includes('check')) estimatedHours = 1;

    const multiplier = urgency === 'emergency' ? range.emergency : 1;
    const low = Math.round((range.base + range.perHour * (estimatedHours - 1)) * multiplier);
    const high = Math.round((range.base + range.perHour * (estimatedHours + 1)) * multiplier);

    res.json({
      serviceType,
      estimatedHours,
      priceRange: { low, high, currency: 'EGP' },
      urgency: urgency || 'normal',
      confidence: 'medium',
    });
  } catch (err) {
    next(err);
  }
});

export default router;
```

- [ ] **Step 4: Commit**

```bash
git add server/src/routes/contact.routes.js server/src/routes/smart-match.routes.js server/src/routes/estimate.routes.js
git commit -m "feat: add contact, smart-match, and estimate routes"
```

---

## Task 14: Database Seed Script

**Files:**
- Create: `server/src/seeds/seed.js`

- [ ] **Step 1: Create seed script — `server/src/seeds/seed.js`**

This populates the database with the existing dummy data from the frontend JS files.

```js
import 'dotenv/config';
import mongoose from 'mongoose';
import { connectDB } from '../config/db.js';
import User from '../models/User.js';
import Service from '../models/Service.js';
import Booking from '../models/Booking.js';
import Conversation from '../models/Conversation.js';
import Message from '../models/Message.js';

async function seed() {
  await connectDB();
  console.log('Seeding database...');

  // Clear existing data
  await Promise.all([
    User.deleteMany({}),
    Service.deleteMany({}),
    Booking.deleteMany({}),
    Conversation.deleteMany({}),
    Message.deleteMany({}),
  ]);

  // ── Users ─────────────────────────────────────────────
  const admin = await User.create({
    fullName: 'Admin',
    email: 'admin@servio.eg',
    phone: '01000000000',
    password: 'admin123',
    role: 'admin',
    status: 'active',
  });

  const customer = await User.create({
    fullName: 'Ahmed Yasser',
    email: 'ahmed@test.com',
    phone: '01012345678',
    password: 'test1234',
    role: 'customer',
    address: 'Nasr City, Cairo',
    status: 'active',
  });

  const tech1 = await User.create({
    fullName: 'Khaled Mohamed',
    email: 'khaled@test.com',
    phone: '01098765432',
    password: 'test1234',
    role: 'technician',
    status: 'active',
    title: 'Master Plumber',
    titleAr: 'سباك محترف',
    skills: ['Plumbing'],
    serviceArea: 'Maadi, Cairo',
    serviceAreaAr: 'المعادي، القاهرة',
    availability: 'both',
    hourlyRate: 145,
    yearsExp: 8,
    rating: 4.9,
    reviewCount: 128,
    jobSuccess: '97%',
    responseTime: '30m',
    verified: true,
    avatar: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?q=80&w=256&auto=format&fit=crop',
    cover: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=2669&auto=format&fit=crop',
    bioEn: 'With 8 years of hands-on experience in residential plumbing, Khaled delivers reliable solutions for leaks, fixtures, and full pipe systems.',
    bioAr: 'بخبرة 8 سنوات في السباكة السكنية، يقدم خالد حلولاً موثوقة للتسربات والتجهيزات وأنظمة الأنابيب الكاملة.',
    descEn: 'Expert plumber specializing in pipe repair, leak detection, and fixture installation across Cairo.',
    descAr: 'سباك خبير متخصص في إصلاح الأنابيب وكشف التسربات وتركيب التجهيزات في القاهرة.',
    memberSince: 'January 2024',
    memberSinceAr: 'يناير 2024',
    servicesList: [
      { nameEn: 'Pipe Repair', nameAr: 'إصلاح الأنابيب', priceEn: '300 – 600 EGP', priceAr: '300 – 600 جنيه', durationEn: '1 – 3 hours', durationAr: '1 – 3 ساعات' },
      { nameEn: 'Leak Detection', nameAr: 'كشف التسربات', priceEn: '200 – 400 EGP', priceAr: '200 – 400 جنيه', durationEn: '1 – 2 hours', durationAr: '1 – 2 ساعة' },
      { nameEn: 'Fixture Installation', nameAr: 'تركيب التجهيزات', priceEn: '400 – 800 EGP', priceAr: '400 – 800 جنيه', durationEn: '2 – 4 hours', durationAr: '2 – 4 ساعات' },
      { nameEn: 'Emergency Callout', nameAr: 'طارئ', priceEn: '600 – 1,200 EGP', priceAr: '600 – 1,200 جنيه', durationEn: 'Varies', durationAr: 'يتفاوت', emergency: true },
    ],
  });

  const tech2 = await User.create({
    fullName: 'Mahmoud Ibrahim',
    email: 'mahmoud@test.com',
    phone: '01055555555',
    password: 'test1234',
    role: 'technician',
    status: 'active',
    title: 'Licensed Electrician',
    titleAr: 'كهربائي مرخص',
    skills: ['Electrical'],
    serviceArea: 'Nasr City, Cairo',
    serviceAreaAr: 'مدينة نصر، القاهرة',
    availability: 'weekdays',
    hourlyRate: 160,
    yearsExp: 6,
    rating: 4.7,
    reviewCount: 95,
    jobSuccess: '95%',
    responseTime: '45m',
    verified: true,
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=256&auto=format&fit=crop',
    bioEn: 'Mahmoud holds a valid electrical trade license and has completed safety training across residential and commercial projects.',
    bioAr: 'يحمل محمود رخصة مهنية كهربائية سارية وأكمل تدريب السلامة في المشاريع السكنية والتجارية.',
    descEn: 'Licensed electrician specializing in wiring, lighting installation, and electrical fault repair.',
    descAr: 'كهربائي مرخص متخصص في التوصيلات وتركيب الإضاءة وإصلاح الأعطال الكهربائية.',
    memberSince: 'March 2024',
    memberSinceAr: 'مارس 2024',
    servicesList: [
      { nameEn: 'Wiring & Rewiring', nameAr: 'التوصيلات الكهربائية', priceEn: '500 – 1,500 EGP', priceAr: '500 – 1,500 جنيه', durationEn: '2 – 6 hours', durationAr: '2 – 6 ساعات' },
      { nameEn: 'Lighting Installation', nameAr: 'تركيب الإضاءة', priceEn: '300 – 800 EGP', priceAr: '300 – 800 جنيه', durationEn: '1 – 3 hours', durationAr: '1 – 3 ساعات' },
      { nameEn: 'Safety Inspection', nameAr: 'فحص السلامة', priceEn: '200 – 400 EGP', priceAr: '200 – 400 جنيه', durationEn: '1 – 2 hours', durationAr: '1 – 2 ساعة' },
      { nameEn: 'Panel Upgrade', nameAr: 'ترقية لوحة التوزيع', priceEn: '800 – 2,000 EGP', priceAr: '800 – 2,000 جنيه', durationEn: '3 – 5 hours', durationAr: '3 – 5 ساعات' },
    ],
  });

  const tech3 = await User.create({
    fullName: 'Hassan Ali',
    email: 'hassan@test.com',
    phone: '01066666666',
    password: 'test1234',
    role: 'technician',
    status: 'active',
    title: 'HVAC & Cleaning Specialist',
    titleAr: 'متخصص تكييف وتنظيف',
    skills: ['HVAC', 'Cleaning'],
    serviceArea: 'Zamalek, Cairo',
    serviceAreaAr: 'الزمالك، القاهرة',
    availability: 'both',
    hourlyRate: 180,
    yearsExp: 10,
    rating: 4.8,
    reviewCount: 210,
    jobSuccess: '98%',
    responseTime: '25m',
    verified: true,
    avatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=256&auto=format&fit=crop',
    bioEn: 'Hassan brings 10 years of expertise in AC installation, servicing, and professional deep cleaning.',
    bioAr: 'يمتلك حسن 10 سنوات من الخبرة في تركيب التكييف والصيانة والتنظيف العميق الاحترافي.',
    descEn: 'Certified HVAC technician and professional cleaning specialist serving Zamalek and Dokki.',
    descAr: 'فني تكييف معتمد ومتخصص تنظيف احترافي يخدم الزمالك والدقي.',
    memberSince: 'February 2024',
    memberSinceAr: 'فبراير 2024',
    servicesList: [
      { nameEn: 'AC Installation', nameAr: 'تركيب التكييف', priceEn: '800 – 1,500 EGP', priceAr: '800 – 1,500 جنيه', durationEn: '2 – 4 hours', durationAr: '2 – 4 ساعات' },
      { nameEn: 'AC Servicing', nameAr: 'صيانة التكييف', priceEn: '400 – 800 EGP', priceAr: '400 – 800 جنيه', durationEn: '1 – 2 hours', durationAr: '1 – 2 ساعة' },
      { nameEn: 'Deep Cleaning', nameAr: 'التنظيف العميق', priceEn: '400 – 900 EGP', priceAr: '400 – 900 جنيه', durationEn: '3 – 5 hours', durationAr: '3 – 5 ساعات' },
      { nameEn: 'AC Fault Repair', nameAr: 'إصلاح أعطال التكييف', priceEn: '500 – 1,200 EGP', priceAr: '500 – 1,200 جنيه', durationEn: '1 – 3 hours', durationAr: '1 – 3 ساعات' },
    ],
  });

  const tech4 = await User.create({
    fullName: 'Youssef Samir',
    email: 'youssef@test.com',
    phone: '01077777777',
    password: 'test1234',
    role: 'technician',
    status: 'active',
    title: 'Professional Painter',
    titleAr: 'دهان محترف',
    skills: ['Painting'],
    serviceArea: 'New Cairo, Cairo',
    serviceAreaAr: 'القاهرة الجديدة، القاهرة',
    availability: 'weekdays',
    hourlyRate: 120,
    yearsExp: 7,
    rating: 4.6,
    reviewCount: 74,
    jobSuccess: '94%',
    responseTime: '60m',
    verified: false,
    avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=256&auto=format&fit=crop',
    descEn: 'Professional painter with expertise in interior finishing, surface prep, and wallpaper installation.',
    descAr: 'دهان محترف متخصص في التشطيب الداخلي وتحضير الأسطح وتركيب ورق الجدران.',
    memberSince: 'April 2024',
    memberSinceAr: 'أبريل 2024',
    servicesList: [
      { nameEn: 'Interior Painting', nameAr: 'الدهان الداخلي', priceEn: '1,000 – 2,500 EGP', priceAr: '1,000 – 2,500 جنيه', durationEn: '1 – 2 days', durationAr: '1 – 2 أيام' },
      { nameEn: 'Surface Preparation', nameAr: 'تحضير الأسطح', priceEn: '300 – 700 EGP', priceAr: '300 – 700 جنيه', durationEn: '2 – 4 hours', durationAr: '2 – 4 ساعات' },
    ],
  });

  const tech5 = await User.create({
    fullName: 'Amr Gamal',
    email: 'amr@test.com',
    phone: '01088888888',
    password: 'test1234',
    role: 'technician',
    status: 'active',
    title: 'Master Carpenter',
    titleAr: 'نجار محترف',
    skills: ['Carpentry'],
    serviceArea: 'Maadi, Cairo',
    serviceAreaAr: 'المعادي، القاهرة',
    availability: 'weekends',
    hourlyRate: 130,
    yearsExp: 9,
    rating: 4.5,
    reviewCount: 58,
    jobSuccess: '93%',
    responseTime: '50m',
    verified: false,
    avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=256&auto=format&fit=crop',
    descEn: 'Skilled carpenter specializing in woodwork, furniture repair, and custom built-in storage.',
    descAr: 'نجار ماهر متخصص في الأعمال الخشبية وإصلاح الأثاث والتخزين المدمج المخصص.',
    memberSince: 'May 2024',
    memberSinceAr: 'مايو 2024',
    servicesList: [
      { nameEn: 'Furniture Repair', nameAr: 'إصلاح الأثاث', priceEn: '200 – 600 EGP', priceAr: '200 – 600 جنيه', durationEn: '1 – 3 hours', durationAr: '1 – 3 ساعات' },
      { nameEn: 'Custom Built-ins', nameAr: 'وحدات مدمجة مخصصة', priceEn: '1,000 – 3,000 EGP', priceAr: '1,000 – 3,000 جنيه', durationEn: '1 – 3 days', durationAr: '1 – 3 أيام' },
    ],
  });

  console.log('Users seeded:', { admin: admin.email, customer: customer.email, technicians: [tech1.email, tech2.email, tech3.email, tech4.email, tech5.email] });

  // ── Services ──────────────────────────────────────────
  await Service.create([
    {
      slug: 'plumbing',
      title: { en: 'Plumbing Services', ar: 'خدمات السباكة' },
      lead: { en: 'Expert pipe repair, leak detection, and fixture installation by verified professionals.', ar: 'إصلاح الأنابيب والكشف عن التسربات وتركيب الأجهزة من قبل متخصصين معتمدين.' },
      priceBadge: { en: 'avg. 200 – 2,000 EGP', ar: 'متوسط 200 – 2,000 جنيه' },
      heroImage: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=1600&q=80',
      technicianIds: [tech1._id],
    },
    {
      slug: 'electrical',
      title: { en: 'Electrical Services', ar: 'خدمات الكهرباء' },
      lead: { en: 'Safe, licensed wiring, lighting installation, and precision electrical repairs.', ar: 'توصيلات كهربائية آمنة ومرخصة وتركيب الإضاءة وإصلاحات دقيقة.' },
      priceBadge: { en: 'avg. 300 – 3,000 EGP', ar: 'متوسط 300 – 3,000 جنيه' },
      heroImage: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=1600&q=80',
      technicianIds: [tech2._id],
    },
    {
      slug: 'hvac',
      title: { en: 'HVAC Services', ar: 'خدمات التكييف' },
      lead: { en: 'AC installation, servicing, and repair by certified specialists.', ar: 'تركيب وصيانة وإصلاح التكييف من متخصصين معتمدين.' },
      priceBadge: { en: 'avg. 400 – 2,000 EGP', ar: 'متوسط 400 – 2,000 جنيه' },
      technicianIds: [tech3._id],
    },
    {
      slug: 'painting',
      title: { en: 'Painting Services', ar: 'خدمات الدهانات' },
      lead: { en: 'Professional interior and exterior painting with premium finishing.', ar: 'دهان داخلي وخارجي احترافي بتشطيب فاخر.' },
      priceBadge: { en: 'avg. 500 – 5,000 EGP', ar: 'متوسط 500 – 5,000 جنيه' },
      technicianIds: [tech4._id],
    },
    {
      slug: 'carpentry',
      title: { en: 'Carpentry Services', ar: 'خدمات النجارة' },
      lead: { en: 'Woodwork, furniture repair, and custom built-in solutions.', ar: 'أعمال خشبية وإصلاح أثاث وحلول تخزين مدمجة.' },
      priceBadge: { en: 'avg. 200 – 3,000 EGP', ar: 'متوسط 200 – 3,000 جنيه' },
      technicianIds: [tech5._id],
    },
    {
      slug: 'cleaning',
      title: { en: 'Cleaning Services', ar: 'خدمات التنظيف' },
      lead: { en: 'Professional deep cleaning for homes and offices.', ar: 'تنظيف عميق احترافي للمنازل والمكاتب.' },
      priceBadge: { en: 'avg. 300 – 1,500 EGP', ar: 'متوسط 300 – 1,500 جنيه' },
      technicianIds: [tech3._id],
    },
  ]);

  console.log('Services seeded: 6 categories');

  // ── Sample Bookings ───────────────────────────────────
  const booking1 = await Booking.create({
    bookingRef: 'S-2847',
    customer: customer._id,
    technician: tech1._id,
    serviceType: 'plumbing',
    date: new Date('2026-04-10'),
    time: '09:00',
    address: 'Nasr City, Cairo',
    notes: 'Pipe under kitchen sink is leaking',
    payment: 'online',
    status: 'confirmed',
    totalPrice: 400,
  });

  const booking2 = await Booking.create({
    bookingRef: 'S-2848',
    customer: customer._id,
    technician: tech3._id,
    serviceType: 'hvac',
    date: new Date('2026-04-11'),
    time: '11:00',
    address: 'Nasr City, Cairo',
    notes: 'AC unit needs refrigerant refill',
    payment: 'cash',
    status: 'pending',
    totalPrice: 800,
  });

  const booking3 = await Booking.create({
    bookingRef: 'S-2849',
    customer: customer._id,
    technician: tech2._id,
    serviceType: 'electrical',
    date: new Date('2026-04-09'),
    time: '14:00',
    address: 'Nasr City, Cairo',
    notes: 'Circuit breaker keeps tripping',
    payment: 'online',
    status: 'in-progress',
    totalPrice: 600,
  });

  console.log('Bookings seeded: 3 bookings');

  // ── Sample Conversations & Messages ───────────────────
  const conv1 = await Conversation.create({
    participants: [customer._id, tech1._id],
    booking: booking1._id,
    lastMessage: "Got it, I'll be there on time",
    lastMessageAt: new Date(),
  });

  await Message.insertMany([
    { conversation: conv1._id, sender: tech1._id, text: "Salam, I've reviewed the job. Can come tomorrow 9am?", read: true },
    { conversation: conv1._id, sender: customer._id, text: 'Yes, 9am works. The pipe under the sink is leaking.', read: true },
    { conversation: conv1._id, sender: tech1._id, text: "Got it, I'll bring replacement parts.", read: true },
    { conversation: conv1._id, sender: tech1._id, text: "Got it, I'll be there on time", read: true },
  ]);

  const conv2 = await Conversation.create({
    participants: [customer._id, tech3._id],
    booking: booking2._id,
    lastMessage: "Perfect, please call when you're 10 minutes away.",
    lastMessageAt: new Date(),
  });

  await Message.insertMany([
    { conversation: conv2._id, sender: tech3._id, text: 'AC unit needs a refrigerant refill. I will assess on arrival.', read: true },
    { conversation: conv2._id, sender: customer._id, text: "Perfect, please call when you're 10 minutes away.", read: false },
  ]);

  const conv3 = await Conversation.create({
    participants: [customer._id, tech2._id],
    booking: booking3._id,
    lastMessage: "Thank you, I'll make sure the main switch is off beforehand.",
    lastMessageAt: new Date(),
  });

  await Message.insertMany([
    { conversation: conv3._id, sender: customer._id, text: 'The circuit breaker keeps tripping. Is this dangerous?', read: true },
    { conversation: conv3._id, sender: tech2._id, text: 'Could be overload or a faulty breaker. I will test everything.', read: true },
    { conversation: conv3._id, sender: customer._id, text: "Thank you, I'll make sure the main switch is off beforehand.", read: true },
  ]);

  console.log('Conversations & messages seeded: 3 conversations');

  console.log('\n--- Seed complete ---');
  console.log('Demo accounts:');
  console.log('  Admin:      admin@servio.eg / admin123');
  console.log('  Customer:   ahmed@test.com / test1234');
  console.log('  Technician: khaled@test.com / test1234');
  console.log('  Technician: mahmoud@test.com / test1234');
  console.log('  Technician: hassan@test.com / test1234');

  process.exit(0);
}

seed().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Run the seed script**

```bash
cd server && npm run seed
```

Expected: All data seeded, demo accounts listed.

- [ ] **Step 3: Verify with curl**

```bash
curl http://localhost:5000/api/technicians | head -100
curl http://localhost:5000/api/services | head -100
```

- [ ] **Step 4: Commit**

```bash
git add server/src/seeds/seed.js
git commit -m "feat: add database seed script with all demo data from frontend"
```

---

## Task 15: Frontend API Helper

**Files:**
- Create: `js/api.js`

- [ ] **Step 1: Create a shared API client — `js/api.js`**

This module wraps `fetch` with auth headers and base URL, used by all frontend pages.

```js
/**
 * api.js — Shared HTTP client for SERVIO frontend ↔ backend.
 * Reads JWT from localStorage and attaches it to every request.
 */

const API_BASE = 'http://localhost:5000/api';

function getToken() {
  try {
    const session = JSON.parse(localStorage.getItem('servio_session') || 'null');
    return session?.token || '';
  } catch {
    return '';
  }
}

export async function api(path, options = {}) {
  const url = `${API_BASE}${path}`;
  const token = getToken();

  const headers = { 'Content-Type': 'application/json', ...options.headers };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(url, { ...options, headers });

  if (res.status === 401) {
    // Token expired — redirect to login
    localStorage.removeItem('servio_session');
    const page = window.location.pathname.split('/').pop() || 'index.html';
    window.location.href = `./login.html?redirect=${encodeURIComponent('./' + page)}`;
    throw new Error('Unauthenticated');
  }

  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

export function get(path) {
  return api(path, { method: 'GET' });
}

export function post(path, body) {
  return api(path, { method: 'POST', body: JSON.stringify(body) });
}

export function put(path, body) {
  return api(path, { method: 'PUT', body: JSON.stringify(body) });
}

export function patch(path, body) {
  return api(path, { method: 'PATCH', body: JSON.stringify(body) });
}

export function del(path) {
  return api(path, { method: 'DELETE' });
}
```

- [ ] **Step 2: Commit**

```bash
git add js/api.js
git commit -m "feat: add shared API client for frontend-to-backend communication"
```

---

## Task 16: Integrate Auth — Login Page

**Files:**
- Modify: `js/html/login.js`

- [ ] **Step 1: Update login.js to call the backend API**

Replace the hardcoded demo-account checks and localStorage-only auth with a real `POST /api/auth/login` call. The key changes:

1. Import `{ post }` from `'../api.js'`
2. In the `submit` handler, call `post('/auth/login', { email, password })`
3. Store the returned `{ token, user }` in `servio_session` (keep the same key for backward compat)
4. Keep the `routeToDashboard(role)` function as-is

Replace the form submit handler inside `initLogin()` (the `form.addEventListener("submit", ...)` block):

```js
// At top of file, add:
import { post } from '../api.js';

// Replace the form submit handler body (inside the setTimeout callback):
    try {
      const result = await post('/auth/login', { email, password });

      // Remember email if checkbox is checked
      if (rememberCheckbox && rememberCheckbox.checked) {
        localStorage.setItem("servio_remember_email", email);
      } else {
        localStorage.removeItem("servio_remember_email");
      }

      // Store session with token
      localStorage.setItem('servio_session', JSON.stringify({
        token: result.token,
        role: result.user.role,
        email: result.user.email,
        name: result.user.fullName,
        id: result.user.id,
        status: result.user.status,
      }));

      routeToDashboard(result.user.role);
    } catch (err) {
      setLoading(false);
      setError(errorEl, err.message || 'Login failed. Please try again.');
    }
```

Make the submit callback `async` and remove the old hardcoded demo account checks.

- [ ] **Step 2: Test login in browser**

1. Run the backend: `cd server && npm run dev`
2. Open login.html in browser
3. Login with `ahmed@test.com` / `test1234`
4. Verify redirect to customer-dashboard.html

- [ ] **Step 3: Commit**

```bash
git add js/html/login.js
git commit -m "feat: integrate login page with backend auth API"
```

---

## Task 17: Integrate Auth — Signup Page

**Files:**
- Modify: `js/html/signup.js`

- [ ] **Step 1: Update signup.js to call backend register API**

Replace `saveAccount(payload)` calls with `post('/auth/register', payload)`.

Key changes at the two registration points:

**Customer finish** (inside the `finishCustomer` click handler):
```js
import { post } from '../api.js';

// Replace saveAccount(payload) and localStorage.setItem with:
      try {
        const result = await post('/auth/register', {
          fullName: payload.fullName,
          email: payload.email,
          phone: payload.phone,
          password: qs('input[name="password"]', form)?.value || '',
          role: 'customer',
          address: payload.address,
        });

        localStorage.setItem('servio_session', JSON.stringify({
          token: result.token,
          role: result.user.role,
          email: result.user.email,
          name: result.user.fullName,
          id: result.user.id,
        }));

        routeToDashboard('customer');
      } catch (err) {
        setError(form, 'customer-finish', err.message || 'Registration failed');
      }
```

**Technician submit** (inside `persistTechnicianAccount`):
```js
  const persistTechnicianAccount = async () => {
    try {
      const result = await post('/auth/register', {
        fullName: qs('input[name="fullName"]', form)?.value?.trim() || '',
        email: qs('input[name="email"]', form)?.value?.trim() || '',
        phone: qs('input[name="phone"]', form)?.value?.trim() || '',
        password: qs('input[name="password"]', form)?.value || '',
        role: 'technician',
        skills: Array.from(state.skills),
        serviceArea: qs('input[name="serviceArea"]', form)?.value?.trim() || '',
        availability: qs('input[name="availability"]', form)?.value || '',
        currency: qs('select[name="currency"]', form)?.value || 'EGP',
        hourlyRate: Number(qs('input[name="hourlyRate"]', form)?.value || 0),
      });

      localStorage.setItem('servio_session', JSON.stringify({
        token: result.token,
        role: result.user.role,
        email: result.user.email,
        name: result.user.fullName,
        id: result.user.id,
        status: result.user.status,
      }));
    } catch (err) {
      setError(form, 'tech-review', err.message || 'Registration failed');
    }
  };
```

- [ ] **Step 2: Test signup in browser**

1. Open signup.html
2. Register a new customer account
3. Verify redirect to customer-dashboard.html
4. Register a new technician — verify "pending" status message

- [ ] **Step 3: Commit**

```bash
git add js/html/signup.js
git commit -m "feat: integrate signup page with backend register API"
```

---

## Task 18: Integrate Booking Flow

**Files:**
- Modify: `js/html/booking.js`

- [ ] **Step 1: Update booking.js to submit to backend**

At the form submission (Step 3 confirmation), replace the simulated booking with:

```js
import { post } from '../api.js';

// In the final step's submit handler:
try {
  const booking = await post('/bookings', {
    serviceType: state.data.serviceType,
    date: state.data.date,
    time: state.data.time,
    address: state.data.address,
    notes: state.data.notes,
    payment: state.data.payment,
    technicianId: state.data.technicianId || undefined,
  });

  // Redirect to confirmation with booking ref
  window.location.href = `./booking-confirmation.html?ref=${booking.bookingRef}`;
} catch (err) {
  // Show error toast
  showToast(err.message || 'Booking failed', 'error');
}
```

- [ ] **Step 2: Commit**

```bash
git add js/html/booking.js
git commit -m "feat: integrate booking flow with backend API"
```

---

## Task 19: Integrate Customer Dashboard

**Files:**
- Modify: `js/html/customer-dashboard.js`

- [ ] **Step 1: Update customer-dashboard.js to fetch data from API**

Replace the hardcoded dashboard data with API calls:

```js
import { get, patch } from '../api.js';

// Fetch bookings
async function loadBookings() {
  try {
    const data = await get('/bookings');
    renderBookings(data.bookings);
  } catch (err) {
    console.error('Failed to load bookings:', err);
  }
}

// Fetch profile
async function loadProfile() {
  try {
    const user = await get('/users/profile');
    renderProfile(user);
  } catch (err) {
    console.error('Failed to load profile:', err);
  }
}
```

Wire `loadBookings()` and `loadProfile()` into the existing tab-switch logic. Call them when the corresponding panel becomes active.

- [ ] **Step 2: Commit**

```bash
git add js/html/customer-dashboard.js
git commit -m "feat: integrate customer dashboard with backend API"
```

---

## Task 20: Integrate Technician Dashboard

**Files:**
- Modify: `js/html/technician-dashboard.js`

- [ ] **Step 1: Update technician-dashboard.js to fetch from API**

Same pattern as customer dashboard — replace hardcoded data with:

```js
import { get, patch, put } from '../api.js';

async function loadJobQueue() {
  const data = await get('/bookings?status=pending');
  renderJobQueue(data.bookings);
}

async function loadEarnings() {
  const data = await get('/bookings?status=completed');
  renderEarnings(data.bookings);
}

async function acceptJob(bookingId) {
  await patch(`/bookings/${bookingId}/status`, { status: 'confirmed' });
  loadJobQueue();
}

async function loadProfile() {
  const user = await get('/users/profile');
  renderTechProfile(user);
}

async function updateProfile(updates) {
  await put('/users/profile', updates);
  showToast('Profile updated');
}
```

- [ ] **Step 2: Commit**

```bash
git add js/html/technician-dashboard.js
git commit -m "feat: integrate technician dashboard with backend API"
```

---

## Task 21: Integrate Admin Dashboard

**Files:**
- Modify: `js/html/admin-dashboard.js`

- [ ] **Step 1: Update admin-dashboard.js to fetch from API**

```js
import { get, patch, del } from '../api.js';

async function loadStats() {
  const stats = await get('/admin/stats');
  renderStats(stats);
}

async function loadUsers() {
  const data = await get('/admin/users');
  renderUserTable(data.users);
}

async function approveTechnician(userId) {
  await patch(`/admin/users/${userId}`, { status: 'active', verified: true });
  loadUsers();
  showToast('Technician approved');
}

async function suspendUser(userId) {
  await patch(`/admin/users/${userId}`, { status: 'suspended' });
  loadUsers();
  showToast('User suspended');
}

async function deleteUser(userId) {
  await del(`/admin/users/${userId}`);
  loadUsers();
  showToast('User deleted');
}

async function loadBookings() {
  const data = await get('/admin/bookings');
  renderBookingTable(data.bookings);
}
```

- [ ] **Step 2: Commit**

```bash
git add js/html/admin-dashboard.js
git commit -m "feat: integrate admin dashboard with backend API"
```

---

## Task 22: Integrate Messages Page

**Files:**
- Modify: `js/html/messages.js`

- [ ] **Step 1: Update messages.js to fetch/send via API**

Replace the hardcoded `CONVERSATIONS` array:

```js
import { get, post } from '../api.js';

async function loadConversations() {
  const conversations = await get('/messages/conversations');
  renderConversationList(conversations);
}

async function loadMessages(conversationId) {
  const messages = await get(`/messages/conversations/${conversationId}`);
  renderMessages(messages);
}

async function sendMessage(conversationId, text) {
  const message = await post(`/messages/conversations/${conversationId}/messages`, { text });
  appendMessage(message);
}
```

Wire the existing UI (conversation list click, message form submit) to these functions.

- [ ] **Step 2: Commit**

```bash
git add js/html/messages.js
git commit -m "feat: integrate messages page with backend API"
```

---

## Task 23: Integrate Technician Listing & Profile Pages

**Files:**
- Modify: `js/html/technician-listing.js`
- Modify: `js/html/technician-profile.js`

- [ ] **Step 1: Update technician-listing.js**

Replace the import from `technicians-data.js`:

```js
import { get } from '../api.js';

async function loadTechnicians() {
  const params = new URLSearchParams();
  if (activeSkill) params.set('skill', activeSkill);
  if (activeArea) params.set('area', activeArea);
  if (activeSort) params.set('sort', activeSort);
  params.set('page', currentPage);

  const data = await get(`/technicians?${params}`);
  renderTechnicians(data.technicians);
  renderPagination(data.totalPages, data.page);
}
```

- [ ] **Step 2: Update technician-profile.js**

```js
import { get } from '../api.js';

async function loadTechnicianProfile() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get('id');
  if (!id) return;

  const tech = await get(`/technicians/${id}`);
  renderProfile(tech);

  const reviewData = await get(`/reviews/technician/${id}`);
  renderReviews(reviewData.reviews);
}
```

- [ ] **Step 3: Commit**

```bash
git add js/html/technician-listing.js js/html/technician-profile.js
git commit -m "feat: integrate technician listing and profile with backend API"
```

---

## Task 24: Integrate Services Marketplace & Details

**Files:**
- Modify: `js/html/services-marketplace.js`
- Modify: `js/html/service-details.js`

- [ ] **Step 1: Update services-marketplace.js**

```js
import { get } from '../api.js';

async function loadServices() {
  const services = await get('/services');
  renderServiceCards(services);
}
```

- [ ] **Step 2: Update service-details.js**

```js
import { get } from '../api.js';

async function loadServiceDetails() {
  const params = new URLSearchParams(window.location.search);
  const slug = params.get('service');
  if (!slug) return;

  const service = await get(`/services/${slug}`);
  renderServicePage(service);
}
```

- [ ] **Step 3: Commit**

```bash
git add js/html/services-marketplace.js js/html/service-details.js
git commit -m "feat: integrate services pages with backend API"
```

---

## Task 25: Integrate Smart Match & AI Estimator

**Files:**
- Modify: `js/html/smart-match.js`
- Modify: `js/html/ai-estimator.js`

- [ ] **Step 1: Update smart-match.js**

```js
import { post } from '../api.js';

async function runSmartMatch(query) {
  showProcessing();
  try {
    const data = await post('/smart-match', { query });
    renderResults(data.results);
  } catch (err) {
    showError(err.message);
  }
}
```

- [ ] **Step 2: Update ai-estimator.js**

```js
import { post } from '../api.js';

async function getEstimate(serviceType, description, urgency) {
  try {
    const data = await post('/estimate', { serviceType, description, urgency });
    renderEstimate(data);
  } catch (err) {
    showError(err.message);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add js/html/smart-match.js js/html/ai-estimator.js
git commit -m "feat: integrate smart match and AI estimator with backend API"
```

---

## Task 26: Integrate Contact Page

**Files:**
- Modify: `js/html/contact.js`

- [ ] **Step 1: Update contact.js**

```js
import { post } from '../api.js';

async function submitContact(formData) {
  try {
    await post('/contact', {
      name: formData.name,
      email: formData.email,
      subject: formData.subject,
      message: formData.message,
    });
    showSuccess('Message sent successfully!');
  } catch (err) {
    showError(err.message || 'Failed to send message');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add js/html/contact.js
git commit -m "feat: integrate contact form with backend API"
```

---

## Task 27: Final Verification & Cleanup

**Files:**
- Verify all routes work end-to-end

- [ ] **Step 1: Start backend and seed database**

```bash
cd server && npm run seed && npm run dev
```

- [ ] **Step 2: Test all critical flows**

Run through each flow manually in the browser:

1. **Register** a new customer → verify redirect to dashboard
2. **Login** as `ahmed@test.com` / `test1234` → customer dashboard loads with bookings
3. **Login** as `khaled@test.com` / `test1234` → technician dashboard loads with jobs
4. **Login** as `admin@servio.eg` / `admin123` → admin dashboard shows stats
5. **Browse services** → services load from API
6. **View technician listing** → technicians load with filters
7. **Create a booking** → booking saved, confirmation page shows ref
8. **Send a message** → message appears in conversation
9. **Submit contact form** → success toast
10. **Smart Match** → results returned
11. **AI Estimator** → price range returned

- [ ] **Step 3: Verify API error handling**

```bash
# Invalid login
curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"email":"wrong@test.com","password":"wrong"}'
# Expected: 401 {"error":"Invalid email or password"}

# Unauthorized access
curl http://localhost:5000/api/admin/stats
# Expected: 401 {"error":"Authentication required"}

# Invalid booking (no token)
curl -X POST http://localhost:5000/api/bookings -H "Content-Type: application/json" -d '{"serviceType":"plumbing"}'
# Expected: 401 {"error":"Authentication required"}
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete SERVIO backend integration — all pages connected to Node.js + MongoDB API"
```

---

## API Endpoint Reference

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register` | No | Register customer or technician |
| POST | `/api/auth/login` | No | Login, returns JWT |
| GET | `/api/users/profile` | Yes | Get own profile |
| PUT | `/api/users/profile` | Yes | Update own profile |
| PUT | `/api/users/change-password` | Yes | Change password |
| GET | `/api/services` | No | List all service categories |
| GET | `/api/services/:slug` | No | Get single service with technicians |
| GET | `/api/technicians` | No | List technicians (filterable) |
| GET | `/api/technicians/:id` | No | Get technician profile |
| POST | `/api/bookings` | Customer | Create booking |
| GET | `/api/bookings` | Yes | List own bookings |
| GET | `/api/bookings/:id` | Yes | Get booking details |
| PATCH | `/api/bookings/:id/status` | Yes | Update booking status |
| POST | `/api/reviews` | Customer | Submit review |
| GET | `/api/reviews/technician/:id` | No | Get technician reviews |
| GET | `/api/messages/conversations` | Yes | List conversations |
| GET | `/api/messages/conversations/:id` | Yes | Get messages |
| POST | `/api/messages/conversations/:id/messages` | Yes | Send message |
| GET | `/api/admin/stats` | Admin | Dashboard stats |
| GET | `/api/admin/users` | Admin | List/search users |
| PATCH | `/api/admin/users/:id` | Admin | Update user status |
| DELETE | `/api/admin/users/:id` | Admin | Delete user |
| GET | `/api/admin/bookings` | Admin | List all bookings |
| GET | `/api/admin/contacts` | Admin | List contact submissions |
| POST | `/api/contact` | No | Submit contact form |
| POST | `/api/smart-match` | No | Natural language technician search |
| POST | `/api/estimate` | No | Service price estimation |
