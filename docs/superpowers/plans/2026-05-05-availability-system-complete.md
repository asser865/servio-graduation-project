# Availability System — Complete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the end-to-end technician availability flow — signup auto-seeding, listing gate, profile display (dynamic credentials + real schedule), and booking validation (time slot alignment, day enforcement, double-booking prevention).

**Architecture:** Two-layer model: `isAvailable` is both visibility gate and booking gate; `availability[]` is the authoritative weekly schedule driving time slot generation and validation. A tech appears to customers only when `isAvailable: true` AND `availability.length ≥ 1`. `scheduledTime` is validated server-side on every booking creation via a 7-step chain.

**Tech Stack:** Node.js/Express, MongoDB/Mongoose, Vanilla JS (ESM), Jest (backend unit tests)

> **Working directory:** All paths are relative to `d:/Grad_final/temp_repo/`. Run all commands from inside `temp_repo/`.
>
> ⚠️ **NO `git commit` until Task 8 (manual end-to-end testing) passes.** All changes in Tasks 1–7 are staged only. Task 9 is the single final commit.

---

## File Map

**Modify (backend):**
- `backend/__tests__/worker-discovery.test.js` — add `availability.0` to all filter assertions
- `backend/src/modules/users/user.controller.js` — add `availability.0` to `getWorkers` filter
- `backend/src/modules/auth/auth.service.js` — auto-seed `availability[]` after worker creation
- `backend/src/modules/bookings/booking.model.js` — add compound unique index on (worker, scheduledDate, scheduledTime)
- `backend/src/modules/bookings/booking.service.js` — add 7-step validation chain in `createBooking`

**Merge into existing (backend test):**
- `backend/__tests__/booking.service.test.js` — merge new validation-chain tests into existing file; update fixtures for compatibility

**Modify (frontend):**
- `servio_frontend/html/technician-profile.html` — replace hardcoded credentials + availability HTML with dynamic containers
- `servio_frontend/js/html/technician-profile.js` — add `renderCredentials()` and `renderAvailability()`, remove old `availabilityType` pill logic
- `servio_frontend/js/html/booking.js` — 30-day date cap + booking error display (offline gate already exists)

---

## Task 1: Update Worker Discovery Tests + Listing Gate Filter

**Files:**
- Modify: `backend/__tests__/worker-discovery.test.js`
- Modify: `backend/src/modules/users/user.controller.js`

- [ ] **Step 1: Update all 5 test assertions in `worker-discovery.test.js`**

Open `backend/__tests__/worker-discovery.test.js`. Every `expect(User.find).toHaveBeenCalledWith(expect.objectContaining({...}))` call must add `'availability.0': { $exists: true }` to the matcher. There are 5 such assertions.

**Line 59–64 (serviceId test):** Change:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ services: PLUMBING_ID, isAvailable: true })
);
```
To:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ services: PLUMBING_ID, isAvailable: true, 'availability.0': { $exists: true } })
);
```

**Line 74–76 (active/verified test):** Change:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ isActive: true, isVerified: true, role: 'worker', isAvailable: true })
);
```
To:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ isActive: true, isVerified: true, role: 'worker', isAvailable: true, 'availability.0': { $exists: true } })
);
```

**Line 88–90 (category test):** Change:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ categories: { $in: ['plumbing'] }, isAvailable: true })
);
```
To:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ categories: { $in: ['plumbing'] }, isAvailable: true, 'availability.0': { $exists: true } })
);
```

**Line 105–107 (serviceId+category priority test):** Change:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ services: PLUMBING_ID, isAvailable: true })
);
```
To:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ services: PLUMBING_ID, isAvailable: true, 'availability.0': { $exists: true } })
);
```

**Line 122–124 (no filters test):** Change:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ role: 'worker', isActive: true, isVerified: true, isAvailable: true })
);
```
To:
```javascript
expect(User.find).toHaveBeenCalledWith(
  expect.objectContaining({ role: 'worker', isActive: true, isVerified: true, isAvailable: true, 'availability.0': { $exists: true } })
);
```

- [ ] **Step 2: Run tests — confirm they FAIL**

Run from `backend/`:
```bash
npx jest __tests__/worker-discovery.test.js --no-coverage
```
Expected: FAIL — `availability.0` not present in actual filter.

- [ ] **Step 3: Update `getWorkers` filter in `user.controller.js`**

In `backend/src/modules/users/user.controller.js`, find the filter definition in `getWorkers` (around line 37):
```javascript
const filter = { role: 'worker', isActive: true, isVerified: true, isAvailable: true };
```
Replace with:
```javascript
const filter = {
  role:     'worker',
  isActive: true,
  isVerified: true,
  isAvailable: true,
  'availability.0': { $exists: true },
};
```

- [ ] **Step 4: Run tests — confirm they PASS**

```bash
npx jest __tests__/worker-discovery.test.js --no-coverage
```
Expected: PASS (all 5 tests).

- [ ] **Step 5: Run full test suite — confirm no regressions**

```bash
npx jest --no-coverage 2>&1 | tail -6
```
Expected: All tests pass, 0 failures.

---

## Task 2: Booking Service — Validation Chain (TDD)

**Files:**
- Modify: `backend/src/modules/bookings/booking.model.js`
- Modify: `backend/__tests__/booking.service.test.js` (merge into existing — do NOT overwrite)
- Modify: `backend/src/modules/bookings/booking.service.js`

- [ ] **Step 1: Add compound unique index to `booking.model.js`**

Open `backend/src/modules/bookings/booking.model.js`. After the two existing indexes (lines 86–87), add:

```javascript
// Prevents double-booking at the DB level (application-layer findOne is not atomic)
bookingSchema.index(
  { worker: 1, scheduledDate: 1, scheduledTime: 1 },
  { unique: true, partialFilterExpression: { status: { $in: ['pending', 'accepted', 'in_progress'] } } }
);
```

- [ ] **Step 2: Merge new tests into existing `booking.service.test.js`**

The file already exists with 6 tests. **Replace the entire file** with this merged version that preserves all 6 existing tests (with updated fixtures) and adds new validation-chain suites:

```javascript
'use strict';

jest.mock('../src/modules/users/user.model.js');
jest.mock('../src/modules/services/service.model.js');
jest.mock('../src/modules/bookings/booking.model.js');

const User    = require('../src/modules/users/user.model.js');
const Service = require('../src/modules/services/service.model.js');
const Booking = require('../src/modules/bookings/booking.model.js');
const { createBooking } = require('../src/modules/bookings/booking.service.js');

const PLUMBING_SERVICE_ID = '664000000000000000000001';
const HVAC_SERVICE_ID     = '664000000000000000000002';
const WORKER_ID           = '664000000000000000000010';
const USER_ID             = '664000000000000000000020';

// Compute next occurrence of a given weekday (0=Sun, 1=Mon, ...)
function nextWeekday(targetDay) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  const current = d.getDay();
  const diff = (targetDay - current + 7) % 7 || 7;
  d.setDate(d.getDate() + diff);
  return d.toISOString().split('T')[0]; // YYYY-MM-DD
}
const NEXT_MONDAY  = nextWeekday(1);
const NEXT_TUESDAY = nextWeekday(2);

const makeService = (overrides = {}) => ({
  _id:       { toString: () => PLUMBING_SERVICE_ID },
  title:     'Plumbing',
  category:  'plumbing',
  basePrice: 300,
  isActive:  true,
  ...overrides,
});

// Updated: includes isAvailable + availability so new validation chain passes
const makeWorker = (overrides = {}) => ({
  _id:          WORKER_ID,
  role:         'worker',
  isActive:     true,
  isVerified:   true,
  isAvailable:  true,
  availability: [{ day: 'monday', from: '09:00', to: '17:00' }],
  services:     [{ toString: () => PLUMBING_SERVICE_ID }],
  categories:   ['plumbing'],
  ...overrides,
});

// Updated: near-future weekday + scheduledTime so new validation chain passes
const baseBookingData = {
  workerId:      WORKER_ID,
  serviceId:     PLUMBING_SERVICE_ID,
  scheduledDate: NEXT_MONDAY,
  scheduledTime: '10:00',
  address:       '12 Tahrir St, Cairo',
};

beforeEach(() => {
  jest.clearAllMocks();
  User.findOne    = jest.fn().mockResolvedValue(makeWorker());
  Service.findOne = jest.fn().mockResolvedValue(makeService());
  Booking.findOne = jest.fn().mockResolvedValue(null);
  Booking.create  = jest.fn().mockResolvedValue({
    ...baseBookingData,
    _id: 'booking123',
    populate: jest.fn().mockResolvedValue({ _id: 'booking123', status: 'pending' }),
  });
});

// ── Worker-service validation (existing 6 tests — preserved) ─────────────────
describe('createBooking — worker-service validation', () => {
  test('succeeds when worker.services contains the selected service ID', async () => {
    const result = await createBooking(USER_ID, baseBookingData);
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
  });

  test('succeeds via legacy categories when worker.services is empty', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [], categories: ['plumbing'] })
    );
    const result = await createBooking(USER_ID, baseBookingData);
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
  });

  test('fails when worker does not support the selected service', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [{ toString: () => HVAC_SERVICE_ID }], categories: ['hvac'] })
    );
    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: 400,
      message:    expect.stringContaining('does not support this service'),
    });
    expect(Booking.create).not.toHaveBeenCalled();
  });

  test('fails when worker is not found', async () => {
    User.findOne = jest.fn().mockResolvedValue(null);
    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: 404,
      message:    expect.stringContaining('Worker not found'),
    });
  });

  test('fails when service is not found', async () => {
    Service.findOne = jest.fn().mockResolvedValue(null);
    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: 404,
      message:    expect.stringContaining('Service not found'),
    });
  });

  test('booking is created with correct user, worker, service fields', async () => {
    await createBooking(USER_ID, baseBookingData);
    expect(Booking.create).toHaveBeenCalledWith(
      expect.objectContaining({ user: USER_ID, worker: WORKER_ID, service: PLUMBING_SERVICE_ID })
    );
  });
});

// ── 3a: Worker gate ───────────────────────────────────────────────────────────
describe('createBooking — worker gate', () => {
  test('throws 400 when worker.isAvailable is false', async () => {
    User.findOne = jest.fn().mockResolvedValue(makeWorker({ isAvailable: false }));
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('not currently accepting') });
  });
});

// ── 3b: Date range ────────────────────────────────────────────────────────────
describe('createBooking — date range', () => {
  test('throws 400 for a past date', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: '2020-01-01' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('today or in the future') });
  });

  test('throws 400 for a date more than 30 days ahead', async () => {
    const future = new Date();
    future.setDate(future.getDate() + 31);
    const futureStr = future.toISOString().split('T')[0];
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: futureStr }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('30 days in advance') });
  });
});

// ── 3c: Time provided ─────────────────────────────────────────────────────────
describe('createBooking — time provided', () => {
  test('throws 400 when scheduledTime is empty', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('time slot must be selected') });
  });
});

// ── 3d: Slot alignment ────────────────────────────────────────────────────────
describe('createBooking — slot alignment', () => {
  test('throws 400 for half-hour slot (09:30)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '09:30' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('Invalid time slot') });
  });

  test('throws 400 for out-of-range hour (99:00)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '99:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('Invalid time slot') });
  });
});

// ── Same-day past-time ────────────────────────────────────────────────────────
describe('createBooking — same-day past-time', () => {
  test('throws 400 when booking today at a slot that has already passed', async () => {
    // Worker with full-day schedule so only the same-day check fires (not working-hours)
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({
        availability: ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']
          .map(day => ({ day, from: '00:00', to: '23:00' })),
      })
    );
    const todayStr = new Date().toISOString().split('T')[0];
    // '00:00' is always <= current hour (tests never run at exactly UTC midnight)
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: todayStr, scheduledTime: '00:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('already passed') });
  });
});

// ── 3e: Day in schedule ───────────────────────────────────────────────────────
describe('createBooking — day in schedule', () => {
  test('throws 400 when the selected day is not in worker schedule', async () => {
    // baseWorker only has Monday; Tuesday is not in schedule
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: NEXT_TUESDAY }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('not available on this day') });
  });
});

// ── 3f: Within working hours ─────────────────────────────────────────────────
describe('createBooking — working hours', () => {
  test('throws 400 when time is before working hours (08:00, window 09:00–17:00)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '08:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('outside technician') });
  });

  test('throws 400 when time equals toHour (17:00 with window ending 17:00)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '17:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('outside technician') });
  });
});

// ── 3g: Double-booking ───────────────────────────────────────────────────────
describe('createBooking — double-booking', () => {
  test('throws 409 when same worker+date+time slot is already booked', async () => {
    Booking.findOne = jest.fn().mockResolvedValue({ _id: 'existing-booking' });
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 409, message: expect.stringContaining('already booked') });
  });

  test('throws 409 on duplicate-key error (race condition safeguard)', async () => {
    const dupErr = Object.assign(new Error('duplicate key'), { code: 11000 });
    Booking.create = jest.fn().mockRejectedValue(dupErr);
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 409, message: expect.stringContaining('already booked') });
  });
});

// ── Success path ─────────────────────────────────────────────────────────────
describe('createBooking — success', () => {
  test('creates booking when all validation passes', async () => {
    await createBooking(USER_ID, baseBookingData);
    expect(Booking.create).toHaveBeenCalledWith(
      expect.objectContaining({ worker: WORKER_ID, scheduledTime: '10:00', address: '12 Tahrir St, Cairo' })
    );
  });
});
```

- [ ] **Step 3: Run tests — confirm they FAIL**

```bash
cd backend && npx jest __tests__/booking.service.test.js --no-coverage
```
Expected: FAIL — worker gate, date, time, same-day, and double-booking tests fail (validation doesn't exist yet). The 6 original worker-service tests may also fail (missing `isAvailable` check on the old code).

- [ ] **Step 4: Replace `createBooking` in `booking.service.js` with validated version**

Open `backend/src/modules/bookings/booking.service.js`. Replace the entire `createBooking` function (lines 25–66) with:

```javascript
const createBooking = async (userId, data) => {
  const { workerId, serviceId, scheduledDate, scheduledTime, address, description, images } = data;

  // Fetch worker
  const worker = await User.findOne({ _id: workerId, role: 'worker', isActive: true, isVerified: true });
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or not available.');

  // 3a — Worker availability gate
  if (!worker.isAvailable) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician is not currently accepting bookings.');
  }

  // 3b — Date range (UTC-based to match Mongoose's Date type storage)
  const [y, m, d] = scheduledDate.split('-').map(Number);
  const bookingDateUTC = new Date(Date.UTC(y, m - 1, d));
  const todayUTC       = new Date(); todayUTC.setUTCHours(0, 0, 0, 0);
  const maxDateUTC     = new Date(todayUTC); maxDateUTC.setUTCDate(maxDateUTC.getUTCDate() + 30);

  if (bookingDateUTC < todayUTC) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Booking date must be today or in the future.');
  }
  if (bookingDateUTC > maxDateUTC) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Bookings can only be made up to 30 days in advance.');
  }

  // 3c — Time provided
  if (!scheduledTime) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A time slot must be selected.');
  }

  // 3d — Slot alignment: valid hour (00–23) at whole-hour boundary
  if (!/^(0[0-9]|1[0-9]|2[0-3]):00$/.test(scheduledTime)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid time slot format. Only whole-hour slots are accepted.');
  }

  const scheduledHour = parseInt(scheduledTime, 10);

  // 3d-extra — Same-day past-time check (compare local hours since scheduledTime is local)
  const todayLocal       = new Date(); todayLocal.setHours(0, 0, 0, 0);
  const bookingDateLocal = new Date(y, m - 1, d);
  if (bookingDateLocal.getTime() === todayLocal.getTime() && scheduledHour <= new Date().getHours()) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Cannot book a time slot that has already passed today.');
  }

  // 3e — Day must exist in worker's schedule (use UTC day since bookingDateUTC is UTC)
  const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const dayName   = DAY_NAMES[bookingDateUTC.getUTCDay()];
  const daySlot   = (worker.availability || []).find(a => a.day === dayName);
  if (!daySlot) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Technician is not available on this day.');
  }

  // 3f — Time must fall within working hours (last valid slot starts at toHour - 1)
  const fromHour = parseInt(daySlot.from, 10);
  const toHour   = parseInt(daySlot.to,   10);
  if (scheduledHour < fromHour || scheduledHour >= toHour) {
    throw new ApiError(StatusCodes.BAD_REQUEST, "Selected time is outside technician's working hours.");
  }

  // 3g — Double-booking check (exact UTC midnight match eliminates timezone range ambiguity)
  const conflict = await Booking.findOne({
    worker:        workerId,
    scheduledDate: bookingDateUTC,
    scheduledTime,
    status:        { $in: ['pending', 'accepted', 'in_progress'] },
  });
  if (conflict) {
    throw new ApiError(StatusCodes.CONFLICT, 'This time slot is already booked. Please select another.');
  }

  // Verify service exists
  const service = await Service.findOne({ _id: serviceId, isActive: true });
  if (!service) throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found or no longer available.');

  // Verify worker supports this service
  const workerSupportsService = Array.isArray(worker.services) &&
    worker.services.some((id) => id.toString() === service._id.toString());
  const legacyCategoryMatches = !workerSupportsService &&
    Array.isArray(worker.categories) &&
    worker.categories.includes(service.category);
  if (!workerSupportsService && !legacyCategoryMatches) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Selected worker does not support this service.');
  }

  // Create booking — catch duplicate-key as race-condition safeguard
  let booking;
  try {
    booking = await Booking.create({
      user:          userId,
      worker:        workerId,
      service:       serviceId,
      scheduledDate: bookingDateUTC,
      scheduledTime,
      address,
      description,
      images,
      totalPrice:    service.basePrice,
    });
  } catch (err) {
    if (err.code === 11000) {
      throw new ApiError(StatusCodes.CONFLICT, 'This time slot is already booked. Please select another.');
    }
    throw err;
  }

  return booking.populate(['user', 'worker', 'service']);
};
```

- [ ] **Step 5: Run booking service tests — confirm they PASS**

```bash
npx jest __tests__/booking.service.test.js --no-coverage
```
Expected: PASS (all tests — preserved worker-service tests + new validation chain + same-day + race condition).

- [ ] **Step 6: Run full test suite — confirm no regressions**

```bash
npx jest --no-coverage 2>&1 | tail -6
```
Expected: All tests pass, 0 failures.

---

## Task 3: Auto-Seed Availability on Worker Signup

**Files:**
- Modify: `backend/src/modules/auth/auth.service.js`

- [ ] **Step 1: Read `auth.service.js` and locate `registerUser`**

Open `backend/src/modules/auth/auth.service.js`. Find the line `const user = await User.create({...})` inside `registerUser`. Note the line number.

- [ ] **Step 2: Add the `seedAvailability` helper before `registerUser`**

Insert this function immediately before the `registerUser` function definition:

```javascript
function seedAvailability(type) {
  const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  const WEEKENDS = ['saturday', 'sunday'];
  let days = [];
  if      (type === 'weekdays') days = WEEKDAYS;
  else if (type === 'weekends') days = WEEKENDS;
  else if (type === 'both')     days = [...WEEKDAYS, ...WEEKENDS];
  else                          return [];
  const from = type === 'weekends' ? '10:00' : '09:00';
  const to   = type === 'weekends' ? '15:00' : '17:00';
  return days.map(day => ({ day, from, to }));
}
```

- [ ] **Step 3: Add seeding call after `User.create()` inside `registerUser`**

Immediately after the `const user = await User.create({...});` line (and before the token generation / return), insert:

```javascript
  // Auto-seed weekly availability from availabilityType chosen at signup
  if (isWorker && availabilityType) {
    const seeded = seedAvailability(availabilityType);
    if (seeded.length) {
      await User.findByIdAndUpdate(user._id, { availability: seeded });
      user.availability = seeded;
    }
  }
```

- [ ] **Step 4: Verify syntax**

Run from `backend/`:
```bash
node -e "require('./src/modules/auth/auth.service.js'); console.log('OK')"
```
Expected: `OK`

- [ ] **Step 5: Run full test suite — confirm no regressions**

```bash
npx jest --no-coverage 2>&1 | tail -6
```
Expected: All tests pass.

---

## Task 4: Update Technician Profile HTML

**Files:**
- Modify: `servio_frontend/html/technician-profile.html`

- [ ] **Step 1: Replace hardcoded credentials `<ul>` with dynamic container**

In `servio_frontend/html/technician-profile.html`, find lines 448–473 (the entire `<ul class="list-credentials">` block with 4 hardcoded `<li>` items). Replace it with:

```html
          <ul class="list-credentials" id="credentials-list"></ul>
```

The surrounding `<div class="sidebar-widget">` and `<h3>` header stay unchanged.

- [ ] **Step 2: Replace hardcoded availability pills with dynamic containers**

Find lines 479–491 (the `.avail-days` div with 7 hardcoded pills and the `.avail-hours` div with hardcoded text). Replace this entire block:

```html
          <div class="avail-days">
            <span class="avail-pill avail-pill--on" data-i18n="prof_day_sat">Sat</span>
            <span class="avail-pill avail-pill--on" data-i18n="prof_day_sun">Sun</span>
            <span class="avail-pill avail-pill--on" data-i18n="prof_day_mon">Mon</span>
            <span class="avail-pill avail-pill--on" data-i18n="prof_day_tue">Tue</span>
            <span class="avail-pill avail-pill--on" data-i18n="prof_day_wed">Wed</span>
            <span class="avail-pill avail-pill--on" data-i18n="prof_day_thu">Thu</span>
            <span class="avail-pill avail-pill--off" data-i18n="prof_day_fri">Fri</span>
          </div>
          <div class="avail-hours">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            <span data-i18n="prof_typical_hours">Typical hours: 8:00 AM – 8:00 PM</span>
          </div>
```

With:

```html
          <div class="avail-days" id="avail-days"></div>
          <div class="avail-hours" id="avail-hours"></div>
```

---

## Task 5: Update Technician Profile JS

**Files:**
- Modify: `servio_frontend/js/html/technician-profile.js`

- [ ] **Step 1: Add `renderCredentials` function**

Insert this function anywhere before the main profile build function (the function that references `worker.availabilityType` around line 79). Add after the existing helper functions near the top of the file:

```javascript
function renderCredentials(worker) {
  const list = document.getElementById('credentials-list');
  if (!list) return;

  const CHECK_SVG = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>`;
  const PENDING_SVG = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#9ca3af" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`;

  if (!worker.isVerified) {
    list.innerHTML = `<li style="opacity:0.55">${PENDING_SVG}<span>Verification Pending</span></li>`;
    return;
  }

  const items = [
    'SERVIO Verified Professional',
    'Background Checked & ID Verified',
  ];

  const rating = worker.averageRating || 0;
  if      (rating >= 4.8) items.push('SERVIO Elite Tier');
  else if (rating >= 4.5) items.push('SERVIO Pro Tier');
  else                    items.push('SERVIO Standard Tier');

  if ((worker.completedJobs || 0) > 0) {
    items.push(`${worker.completedJobs}+ Verified Jobs Completed`);
  }

  list.innerHTML = items
    .map(text => `<li>${CHECK_SVG}<span>${escapeHtml(text)}</span></li>`)
    .join('');
}
```

- [ ] **Step 2: Add `renderAvailability` function**

Insert immediately after `renderCredentials`:

```javascript
function renderAvailability(worker) {
  const daysEl  = document.getElementById('avail-days');
  const hoursEl = document.getElementById('avail-hours');
  if (!daysEl) return;

  // Weekend-first order matches the existing HTML layout (Sat → Sun → Mon … Fri)
  const WEEK = [
    { key: 'saturday',  label: 'Sat' },
    { key: 'sunday',    label: 'Sun' },
    { key: 'monday',    label: 'Mon' },
    { key: 'tuesday',   label: 'Tue' },
    { key: 'wednesday', label: 'Wed' },
    { key: 'thursday',  label: 'Thu' },
    { key: 'friday',    label: 'Fri' },
  ];

  const schedule = worker.availability || [];

  if (!schedule.length) {
    daysEl.innerHTML = '<p style="font-size:0.85rem;color:#9ca3af;margin:0;">Schedule not yet published</p>';
    if (hoursEl) hoursEl.innerHTML = '';
    return;
  }

  daysEl.innerHTML = WEEK.map(({ key, label }) => {
    const slot = schedule.find(s => s.day === key);
    const cls  = slot ? 'avail-pill avail-pill--on' : 'avail-pill avail-pill--off';
    const tip  = slot ? ` title="${slot.from} – ${slot.to}"` : '';
    return `<span class="${cls}"${tip}>${label}</span>`;
  }).join('');

  if (hoursEl) {
    const fmt = t => {
      const [h, min] = t.split(':').map(Number);
      return `${h % 12 || 12}:${String(min).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
    };
    const froms = schedule.map(s => s.from).sort();
    const tos   = schedule.map(s => s.to).sort().reverse();
    hoursEl.innerHTML = `
      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      <span>Typical hours: ${fmt(froms[0])} – ${fmt(tos[0])}</span>`;
  }
}
```

- [ ] **Step 3: Replace old `availabilityType` pill logic with calls to new functions**

Find lines 78–96 in the main profile build function — the block that starts with the comment on line 78:
```javascript
  // Availability Pills Logic
  const availType = worker.availabilityType || 'both';
  const pills = document.querySelectorAll('.avail-pill');
  pills.forEach(pill => {
    ...
  });
```

Replace the entire block (lines 78–96, including the comment) with:
```javascript
  renderCredentials(worker);
  renderAvailability(worker);
```

---

## Task 6: Update Booking Page JS

**Files:**
- Modify: `servio_frontend/js/html/booking.js`

- [ ] **Step 1: Add 30-day date cap to date picker**

In `booking.js`, find the section where `bookDate.min` is set (around line 631):
```javascript
  if (bookDate) {
    bookDate.min   = todayStr;
    bookDate.value = startDate;
    renderTimeSlotsForDate(startDate, worker.availability || []);
  }
```

Replace with:
```javascript
  if (bookDate) {
    const maxBookDate = new Date();
    maxBookDate.setDate(maxBookDate.getDate() + 30);
    bookDate.min   = todayStr;
    bookDate.max   = maxBookDate.toISOString().split('T')[0];
    bookDate.value = startDate;
    renderTimeSlotsForDate(startDate, worker.availability || []);
  }
```

- [ ] **Step 2: Replace silent booking error with user-facing error display**

Find the `createBooking` try/catch block in `finalizeBooking` (line 769, around lines 780–793):
```javascript
    try {
      const payload = {
        workerId,
        serviceId:     state.data.serviceId,
        scheduledDate: state.data.date,
        scheduledTime: state.selectedTime || '',
        address:       state.data.address,
        description:   document.getElementById('bookNotes')?.value.trim() || '',
      };
      const res = await createBooking(payload);
      bookingId = res.data?._id || res._id || res.data?.booking?._id || null;
    } catch (e) {
      console.warn('createBooking API error (falling back to local):', e);
    }
```

Replace with:
```javascript
    try {
      const payload = {
        workerId,
        serviceId:     state.data.serviceId,
        scheduledDate: state.data.date,
        scheduledTime: state.selectedTime || '',
        address:       state.data.address,
        description:   document.getElementById('bookNotes')?.value.trim() || '',
      };
      const res = await createBooking(payload);
      bookingId = res.data?._id || res._id || res.data?.booking?._id || null;
    } catch (e) {
      const msg = e?.message || '';
      let userMsg = 'Booking failed. Please try again.';
      if      (msg.includes('not currently accepting'))  userMsg = 'This technician is not currently accepting bookings.';
      else if (msg.includes('today or in the future'))   userMsg = 'Please select a valid date.';
      else if (msg.includes('30 days in advance'))       userMsg = 'Bookings can only be made up to 30 days in advance.';
      else if (msg.includes('outside technician'))       userMsg = 'Selected time is outside this technician\'s working hours.';
      else if (msg.includes('not available on this day')) userMsg = 'This technician doesn\'t work on the selected day.';
      else if (msg.includes('time slot'))                userMsg = 'Please select a valid time slot.';
      else if (msg.includes('already booked'))           userMsg = 'This time slot was just taken — please pick another time.';
      alert(userMsg);
      return;
    }
```

---

## Task 7: Run Full Automated Test Suite

- [ ] **Step 1: Run all backend tests**

From `backend/`:
```bash
npx jest --no-coverage
```
Expected output:
```
Test Suites: 5 passed, 5 total
Tests:       XX passed, XX total
```
All suites must pass. If any fail, fix before continuing.

- [ ] **Step 2: Verify app.js still loads cleanly**

```bash
node -e "require('./src/app.js'); console.log('OK')"
```
Expected: `OK`

---

## Task 8: Manual End-to-End Testing Checklist

**Run the dev server before starting:**
```bash
cd backend && npm run dev
```
Open a live-server or VS Code Live Server for the frontend.

- [ ] **Test 1 — Signup auto-seeding**
  1. Register a new technician via the signup flow, select "Weekdays" availability
  2. Check MongoDB `users` collection — the new tech should have `availability: [{day:'monday',from:'09:00',to:'17:00'}, ...]` (5 weekday entries)
  3. Repeat for "Both" → expect 7 entries

- [ ] **Test 2 — Listing gate**
  1. Log in as admin. Set a tech to `isAvailable: true` but clear their `availability: []` via MongoDB directly
  2. Open the public technician listing for their service
  3. Expected: tech does NOT appear (empty array fails the gate)
  4. Restore one availability day. Refresh listing
  5. Expected: tech appears

- [ ] **Test 3 — Profile page credentials (verified tech)**
  1. Open a profile for a verified tech (`isVerified: true`, `averageRating: 4.9`, `completedJobs: 12`)
  2. Expected credentials: "SERVIO Verified Professional", "Background Checked & ID Verified", "SERVIO Elite Tier", "12+ Verified Jobs Completed"
  3. No hardcoded "Master Plumber License" or "Fully Insured" text visible

- [ ] **Test 4 — Profile page credentials (unverified tech)**
  1. Open a profile for a pending tech (`isVerified: false`)
  2. Expected: single greyed item "Verification Pending", no green checkmarks

- [ ] **Test 5 — Profile page availability pills**
  1. Open a profile for a tech with Mon–Fri schedule, no Sat/Sun
  2. Expected: Mon–Fri pills green, Sat–Sun pills grey
  3. Hover over Mon pill → tooltip shows "09:00 – 17:00"
  4. Hours summary shows correct range
  5. Open a profile for a tech with empty `availability: []`
  6. Expected: "Schedule not yet published" message, no pills

- [ ] **Test 6 — Booking: 30-day cap**
  1. Open booking page for an online tech
  2. Open the date picker
  3. Expected: dates beyond today + 30 days are greyed out / unselectable

- [ ] **Test 7 — Booking: offline tech**
  1. Set a tech's `isAvailable: false`
  2. Navigate directly to their booking page URL
  3. Expected: offline banner displayed, form disabled

- [ ] **Test 8 — Booking: valid slot end-to-end**
  1. Online tech, Mon–Fri 09:00–17:00 schedule
  2. Select next Monday, select 10:00 AM slot
  3. Complete booking → expected: success screen, booking appears in DB with `scheduledTime: "10:00"`

- [ ] **Test 9 — Booking: double-booking prevention**
  1. Book the same tech, same date, same time slot a second time (from a different user)
  2. Expected: error message "This time slot was just taken — please pick another time"
  3. That slot now appears greyed out in the UI for that date

- [ ] **Test 10 — Booking: outside hours**
  1. Craft a direct API call (Postman or curl):
     ```bash
     curl -X POST http://localhost:5000/api/v1/bookings \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer <user_token>" \
       -d '{"workerId":"<id>","serviceId":"<id>","scheduledDate":"<next_monday>","scheduledTime":"08:00","address":"Test"}'
     ```
  2. Expected: `400 Selected time is outside technician's working hours.`

- [ ] **Test 11 — Booking: half-hour slot rejection**
  1. Same curl as above but `"scheduledTime":"09:30"`
  2. Expected: `400 Invalid time slot format.`

- [ ] **Test 12 — Booking: past date rejection**
  1. `"scheduledDate":"2020-01-01"`, `"scheduledTime":"10:00"`
  2. Expected: `400 Booking date must be today or in the future.`

---

## Task 9: Final Commit (after all Task 8 tests pass)

⚠️ **Only run this after every checkbox in Task 8 is checked.**

- [ ] **Stage all changed files**

From `d:/Grad_final/temp_repo/`:
```bash
git add \
  backend/__tests__/worker-discovery.test.js \
  backend/__tests__/booking.service.test.js \
  backend/src/modules/users/user.controller.js \
  backend/src/modules/auth/auth.service.js \
  backend/src/modules/bookings/booking.model.js \
  backend/src/modules/bookings/booking.service.js \
  servio_frontend/html/technician-profile.html \
  servio_frontend/js/html/technician-profile.js \
  servio_frontend/js/html/booking.js
```

- [ ] **Commit**

```bash
git commit -m "feat: complete availability system — seeding, listing gate, profile display, booking validation"
```
