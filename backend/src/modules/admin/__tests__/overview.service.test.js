const db = require('../../../test-utils/db');
const { getOverview, buildBookingStats, buildRevenueSeries } = require('../overview.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('buildBookingStats groups lifecycle statuses for the overview', () => {
  const result = buildBookingStats([
    { _id: 'completed', count: 8 },
    { _id: 'pending', count: 3 },
    { _id: 'accepted', count: 2 },
    { _id: 'awaiting_customer_confirmation', count: 1 },
    { _id: 'cancelled', count: 2 },
    { _id: 'disputed', count: 1 },
  ], 4);

  expect(result).toEqual({
    total: 17,
    newLast24Hours: 4,
    successRate: 72.7,
    buckets: {
      completed: 8,
      inProgress: 3,
      scheduled: 3,
      cancelled: 2,
      disputed: 1,
    },
  });
});

test('buildRevenueSeries returns live seven-day revenue and week comparison', () => {
  const today = new Date('2026-05-30T00:00:00');
  const result = buildRevenueSeries([
    { platformFee: 100, releasedAt: new Date('2026-05-30T08:00:00') },
    { platformFee: 50, releasedAt: new Date('2026-05-29T08:00:00') },
    { platformFee: 60, releasedAt: new Date('2026-05-23T08:00:00') },
    { platformFee: 40, releasedAt: new Date('2026-05-22T08:00:00') },
  ], today);

  expect(result.dailyRevenue).toHaveLength(7);
  expect(result.dailyRevenue.at(-1)).toEqual({ date: '2026-05-30', revenue: 100 });
  expect(result.currentWeekRevenue).toBe(150);
  expect(result.previousWeekRevenue).toBe(100);
  expect(result.comparisonPercent).toBe(50);
});

test('getOverview returns a complete empty-state contract', async () => {
  const result = await getOverview();

  expect(result.kpis).toEqual({
    totalUsers: 0,
    totalTechnicians: 0,
    revenueThisMonth: 0,
    openDisputes: 0,
  });
  expect(result.revenue.daily).toHaveLength(7);
  expect(result.bookings.buckets).toEqual({
    completed: 0,
    inProgress: 0,
    scheduled: 0,
    cancelled: 0,
    disputed: 0,
  });
  expect(result.recentActivity).toEqual([]);
  expect(result.topTechnicians).toEqual([]);
});
