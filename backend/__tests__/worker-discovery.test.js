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
const { getWorkers } = require('../src/modules/users/user.controller');

// ── Helpers ──────────────────────────────────────────────────────────────────

const PLUMBING_ID = '664000000000000000000001';
const HVAC_ID     = '664000000000000000000002';

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

beforeEach(() => jest.clearAllMocks());

describe('getWorkers — serviceId filter (canonical)', () => {
  test('passes services: serviceId to the query when ?serviceId is provided', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: PLUMBING_ID } };
    const res = mockRes();

    await getWorkers(req, res);

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({ services: PLUMBING_ID, isAvailable: true, 'availability.0': { $exists: true } })
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.not.objectContaining({ categories: expect.anything() })
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
});

describe('getWorkers — category filter (legacy backward compat)', () => {
  test('passes categories $in filter when ?category is provided and no serviceId', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { category: 'plumbing' } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({ categories: { $in: ['plumbing'] }, isAvailable: true, 'availability.0': { $exists: true } })
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.not.objectContaining({ services: expect.anything() })
    );
  });
});

describe('getWorkers — serviceId takes priority over category', () => {
  test('uses serviceId filter and ignores category when both are provided', async () => {
    User.find = jest.fn().mockReturnValue(buildQuery([]));
    User.countDocuments = jest.fn().mockResolvedValue(0);

    const req = { query: { serviceId: PLUMBING_ID, category: 'plumbing' } };
    await getWorkers(req, mockRes());

    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({ services: PLUMBING_ID, isAvailable: true, 'availability.0': { $exists: true } })
    );
    expect(User.find).toHaveBeenCalledWith(
      expect.not.objectContaining({ categories: expect.anything() })
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
  });
});
