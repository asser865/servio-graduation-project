# SERVIO

AI-powered home maintenance, booking, payments, and room-finishing platform.

This repository is a multi-app graduation project. It contains a Node.js API,
a static web frontend, a Flutter mobile app, and Python FastAPI AI services.

## Repository Layout

| Path | Purpose | Main technologies |
| --- | --- | --- |
| `backend/` | REST API, auth, bookings, payments, notifications, admin, messaging, uploads, Socket.IO events | Node.js, Express, MongoDB/Mongoose, JWT, Socket.IO, Stripe/demo gateway, Jest |
| `servio_frontend/` | Browser web app | HTML, CSS, vanilla JavaScript ES modules, Motion package, static assets |
| `mobile-app/` | Customer and technician mobile app | Flutter, Dart, Provider, Material, shared preferences, secure storage, HTTP APIs |
| `ai-service/` | AI microservices for room analysis, recommendations, and cost estimates | Python, FastAPI, Uvicorn, Gemini/Groq integrations, Diffusers/Transformers, Torch |
| `docs/` | Project documentation and reports | Markdown/docs assets |

## Main Features

- User, worker, and admin authentication with JWT.
- Service marketplace with workers, profiles, availability, reviews, favorites, and locations.
- Customer booking flow with worker acceptance, job start/completion, cancellation, no-show handling, and execution windows.
- Payments with demo/Stripe gateway support, cash debt tracking, payouts, customer credits, invoices, receipts, refunds, partial refunds, and dispute workflows.
- Admin audit logs, settings, worker verification, payments oversight, settlements, and support escalation.
- Notifications through in-app, email, socket, and push-channel abstractions.
- Real-time messaging and payment/settlement socket events.
- AI service recommendation, room analysis from image upload, room finishing render generation, and cost estimation.
- Flutter mobile app for customer and technician workflows with EN/AR locale support and light/dark themes.
- Static web frontend with multilingual UI, dark mode, AI chat/matching pages, booking pages, dashboards, and admin pages.

## Prerequisites

- Node.js and npm for `backend/` and `servio_frontend/`.
- MongoDB database for the backend.
- Python 3.10+ recommended for `ai-service/`.
- Flutter SDK 3.3+ for `mobile-app/`.

## Backend Setup

```bash
cd backend
npm install
```

Create `backend/.env`:

```env
NODE_ENV=development
PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/servio
JWT_SECRET=replace-me
JWT_EXPIRES_IN=7d
CLIENT_URL=http://127.0.0.1:5173,http://localhost:5173
FRONTEND_URL=http://127.0.0.1:5173
AI_SERVICE_URL=http://127.0.0.1:8000
PAYMENT_GATEWAY=demo
```

Optional backend variables used by the code:

```env
STRIPE_SECRET_KEY=
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
SMTP_FROM=
SERVIO_UPLOAD_DIR=
PLATFORM_FEE_PERCENTAGE=10
OVERLAP_ENFORCEMENT_ENABLED=true
TRUST_PROXY=false
DISPUTE_SLA_FIRST_RESPONSE_HOURS=24
DISPUTE_SLA_RESOLVE_HOURS=72
DISPUTE_SLA_BREACH_HOURS=24
DISPUTE_ESCALATE_HOURS=72
AI_MOBILE_SERVICE_URL=http://localhost:8001
AI_MOBILE_MAIN_SERVICE_URL=http://localhost:8002
```

Run the API:

```bash
npm run dev
```

Health checks:

```text
GET http://localhost:5000/health
GET http://localhost:5000/api/v1/health
```

Useful backend commands:

```bash
npm test
npm run migrate:escrow
node scripts/create-admin.js
node scripts/seed-test-technicians.js
node scripts/seed-multi-service-technicians.js
```

## Web Frontend Setup

The web app is not React or Next.js. It is a static HTML/CSS/vanilla JavaScript
frontend under `servio_frontend/`.

```bash
cd servio_frontend
npm install
npm run preview
```

The preview command serves the folder on port `5173`. Open:

```text
http://localhost:5173/html/index.html
```

Local API routing is defined in `servio_frontend/js/config.js`:

```text
http://127.0.0.1:5000/api/v1
```

Non-localhost builds point to:

```text
https://servio-backend.onrender.com/api/v1
```

## Mobile App Setup

```bash
cd mobile-app
flutter pub get
flutter run
```

The default mobile API base URL is:

```text
http://10.0.2.2:5000/api/v1
```

Override it at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api/v1
```

or:

```bash
flutter run --dart-define=SERVIO_API_BASE=http://localhost:5000/api/v1
```

Run mobile tests:

```bash
flutter test
```

## AI Service Setup

```bash
cd ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Create `ai-service/.env` if you use external AI providers:

```env
GEMINI_API_KEY=
GROQ_API_KEY=
```

AI service endpoints:

```text
GET  /
GET  /docs
POST /ai/analyze-room
POST /ai/recommend
POST /ai/estimate-cost
POST /recommend
```

There are also separate Groq/Gradio recommender folders:

```text
ai-service/ai_recommender/
ai-service/ai_recommender_mobile/
```

Each has its own lightweight `requirements.txt` and development scripts.

## API Overview

The backend mounts API modules under `/api/v1`:

```text
/auth
/users
/services
/bookings
/reviews
/ai
/mobile/ai
/messages
/payments
/admin
/uploads
/notify
/notifications
/saved-cards
/platform-settings
/locations
/favorites
/support
```

Static uploaded files are served from:

```text
/uploads
```

## Testing

Backend:

```bash
cd backend
npm test
```

Mobile:

```bash
cd mobile-app
flutter test
```

Web:

```bash
cd servio_frontend
npm run lint
```

AI service tests and scenario scripts live in:

```text
ai-service/ai_recommender/
ai-service/ai_recommender_mobile/
```

## Team

- Ahmed Yasser
- Asser Essam
- Mostafa Abdelaal
- Youssef Tarek
- Ahmed Essam
