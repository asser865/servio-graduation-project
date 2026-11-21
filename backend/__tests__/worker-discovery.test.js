/**
 * Unit tests for worker discovery logic in user.controller.js.
 *
 * Tests that:
 * - ?serviceId filters by worker.services (canonical)
 * - ?category filters by worker.categories (legacy)
 * - inactive and unverified workers are excluded
 * - a worker with multiple services appears in each relevant query
 */

'use strict';

jest.mock('../src/modules/users/user.model');
jest.mock('../src/modules/reviews/review.model');
jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/payments/payment.model');
jest.mock('../src/modules/payments/dispute.model');
jest.mock('../src/modules/services/service.model');
jest.mock('../src/modules/admin/audit.service', () => ({ logEvent: jest.fn() }));

const User        = require('../src/modules/users/user.model');
const Service     = require('../src/modules/services/service.model');
const { getWorkers } = require('../src/modules/users/user.controller');

// ── Helpers ──────────────────────────────────────────────────────────────────

const PLUMBING_ID = '664000000000000000000001';
const HVAC_ID     = '664000000000000000000002';
const ELECTRICAL_ID = '664000000000000000000003';

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json   = jest.fn().mockReturnValue(res);
  return res;
};

const buildQuery = (users) => {
  const chain = {
    select:   jest.fn().mockReturnThis(),
    populate: jest.fn().mockReturnThis(),
    sort:     jest.fn().mockReturnThis(),
    skip:     jest.fn().mockReturnThis(),
    limit:    jest.fn().mockResolvedValue(users),
  };
  return chain;
};

beforeEach(() => {
  jest.clearAllMocks();
  Service.findOne = jest.fn().mockResolvedValue({
    _id: PLUMBING_ID,
    category: 'plumbing',
  });
  Service.find = jest.fn().mockResolvedValue([
    { _id: PLUMBING_ID },
  ]);
});

describe('getWorkers — serviceId filter (canonical)', () => {
  test('passes services: serviceId to the query when ?serviceId is provided', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: PLUMBING_ID } };
    const res = mockRes();

    await getWorkers(req, res);

    expect(Service.findOne).toHaveBeenCalledWith(
      { _id: PLUMBING_ID, isActive: true },
      'category'
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([
              { 'services.serviceId': PLUMBING_ID },
              { categories: { $in: ['plumbing'] } },
            ]),
          }),
        ]),
        isAvailable: true,
        'availability.0': { $exists: true },
      })
    );
  });

  test('returns only active and verified workers', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: PLUMBING_ID } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({ isActive: true, isVerified: true, role: 'worker', isAvailable: true, 'availability.0': { $exists: true } })
    );
  });

  test('invalid serviceId does not fall back to all workers', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: 'not-a-valid-id' } };
    const res = mockRes();

    await getWorkers(req, res);

    expect(Service.findOne).not.toHaveBeenCalled();
    expect(User.find).not.toHaveBeenCalled();
    expect(User.countDocuments).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          workers: [],
          pagination: expect.objectContaining({ total: 0 }),
        }),
      })
    );
  });
});

describe('getWorkers — category filter (legacy backward compat)', () => {
  test('passes categories $in filter when ?category is provided and no serviceId', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { category: 'plumbing' } };
    await getWorkers(req, mockRes());

    expect(Service.find).toHaveBeenCalledWith(
      { category: 'plumbing', isActive: true },
      '_id'
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([
              { categories: { $in: ['plumbing'] } },
              { 'services.serviceId': { $in: [PLUMBING_ID] } },
            ]),
          }),
        ]),
        isAvailable: true,
        'availability.0': { $exists: true },
      })
    );
  });

  test('passes electrical-only filters for ?category=electrical', async () => {
    Service.find = jest.fn().mockResolvedValue([{ _id: ELECTRICAL_ID }]);
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { category: 'electrical' } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([
              { categories: { $in: ['electrical'] } },
              { 'services.serviceId': { $in: [ELECTRICAL_ID] } },
            ]),
          }),
        ]),
      })
    );
    // Plumbing should NOT appear in the electrical query
    const callArg = User.find.mock.calls[0][0];
    const allOrClauses = (callArg.$and || []).flatMap((c) => c.$or || []);
    expect(allOrClauses).not.toContainEqual({ categories: { $in: ['plumbing'] } });
  });
});

describe('getWorkers — serviceId takes priority over category', () => {
  test('uses serviceId filter and ignores category when both are provided', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: PLUMBING_ID, category: 'plumbing' } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([
              { 'services.serviceId': PLUMBING_ID },
              { categories: { $in: ['plumbing'] } },
            ]),
          }),
        ]),
        isAvailable: true,
        'availability.0': { $exists: true },
      })
    );
  });
});

describe('getWorkers — invalid category', () => {
  test('does not fall back to all workers', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { category: 'not-a-real-category' } };
    const res = mockRes();

    await getWorkers(req, res);

    expect(User.find).not.toHaveBeenCalled();
    expect(User.countDocuments).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          workers: [],
          pagination: expect.objectContaining({ total: 0 }),
        }),
      })
    );
  });
});

describe('getWorkers — area filter', () => {
  test('matches structured coverage slugs first and preserves legacy regex fallbacks', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { area: 'Maadi' } };
    await getWorkers(req, mockRes());

    // Slug-based clause is unshifted to the front; regex fallbacks remain in $and.
    const expectedArea = expect.objectContaining({
      $and: expect.arrayContaining([
        expect.objectContaining({
          $or: expect.arrayContaining([
            expect.objectContaining({ coverageMatchSlugs: 'maadi' }),
            expect.objectContaining({ coverageAreas: expect.any(RegExp) }),
            expect.objectContaining({ serviceArea: expect.any(RegExp) }),
            expect.objectContaining({ locationLabel: expect.any(RegExp) }),
          ]),
        }),
      ]),
    });

    expect(User.find).toHaveBeenCalledWith(expectedArea);
    expect(User.countDocuments).toHaveBeenCalledWith(expectedArea);
  });

  test('resolves a district request to a worker covering the parent governorate', async () => {
    // "Nasr City" is a district under "Cairo" — a worker whose coverage is
    // "Cairo" stores `nasr-city` in `coverageMatchSlugs` via descendant expansion,
    // so the request slug `nasr-city` should appear in the filter.
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { area: 'Nasr City' } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([
              expect.objectContaining({ coverageMatchSlugs: 'nasr-city' }),
            ]),
          }),
        ]),
      })
    );
  });

  test('combines serviceId and area filters with $and so neither overwrites the other', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: PLUMBING_ID, area: 'Maadi' } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([
              { 'services.serviceId': PLUMBING_ID },
              { categories: { $in: ['plumbing'] } },
            ]),
          }),
          expect.objectContaining({
            $or: expect.arrayContaining([
              expect.objectContaining({ coverageMatchSlugs: 'maadi' }),
            ]),
          }),
        ]),
      })
    );
  });
});

describe('getWorkers — no filters', () => {
  test('returns all active verified workers when no filters are provided', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: {} };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({ role: 'worker', isActive: true, isVerified: true, isAvailable: true, 'availability.0': { $exists: true } })
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.not.objectContaining({ services: expect.anything(), categories: expect.anything() })
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.not.objectContaining({ 'services.serviceId': expect.anything() })
    );
    // Suspended workers always excluded via $and clause
    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({
        $and: expect.arrayContaining([
          expect.objectContaining({
            $or: expect.arrayContaining([{ suspendedUntil: { $exists: false } }]),
          }),
        ]),
      })
    );
  });
});
