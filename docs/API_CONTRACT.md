# SERVIO API Contract

SERVIO uses one shared Node.js/Express backend and one MongoDB database for the website and mobile app. All client integrations must use the versioned REST API under `/api/v1`.

## Base Rules

- Base path: `/api/v1`
- Auth: `Authorization: Bearer <jwt>`
- Success response: `{ "success": true, "message": string, "data": object | array | null }`
- Error response: `{ "success": false, "message": string, "errors": array }`
- Validation failures use HTTP `422` with `errors: [{ "field": string, "message": string }]`
- List endpoints return a module key plus pagination, for example `{ services, pagination }`, `{ workers, pagination }`, `{ bookings, pagination }`

## Roles

Client roles map to backend roles as follows:

- `customer` -> `user`
- `technician` -> `worker`
- `admin` -> `admin`

Mobile and website clients can display their own labels, but requests and persisted backend data must use the backend role values.

## Auth

- `POST /auth/register`
  - Body: `name`, `email`, `password`, optional `phone`, optional `role`
  - Customer role may be sent as `user` or `customer`
  - Technician role may be sent as `worker` or `technician`
  - Response data: `{ token, user }`
- `POST /auth/login`
  - Body: `email`, `password`
  - Response data: `{ token, user }`
- `POST /auth/forgot-password`
  - Body: `email`
- `POST /auth/reset-password/:token`
  - Body: `password`
- `GET /users/me`
  - Canonical current-user endpoint for all clients

## Core Resources

- Services
  - `GET /services`
  - `GET /services/:id`
  - Admin: `POST /services`, `PUT /services/:id`, `DELETE /services/:id`
- Workers
  - `GET /users/workers`
  - `GET /users/workers/:id`
  - Admin: `PATCH /users/workers/:id/verify`
- Bookings
  - Customer: `POST /bookings`, `GET /bookings/my`
  - Worker: `GET /bookings/worker`
  - Shared: `GET /bookings/:id`, `PATCH /bookings/:id/status`
  - Admin: `GET /bookings`
- Reviews
  - Customer: `POST /reviews`
  - Public: `GET /reviews/worker/:workerId`
  - Admin: `DELETE /reviews/:id`
- Messages
  - Authenticated: `POST /messages`, `GET /messages/conversations`, `GET /messages/unread`, `GET /messages/:bookingId`

## Booking Statuses

Valid backend statuses are:

- `pending`
- `accepted`
- `rejected`
- `in_progress`
- `completed`
- `cancelled`
- `disputed`

Clients may render friendlier labels, but API requests must send the backend status value.

## Mobile Configuration

The Flutter app reads the API base from:

```bash
--dart-define=SERVIO_API_BASE=http://<host>:<port>/api/v1
```

Default Android emulator value is `http://10.0.2.2:5000/api/v1`.
