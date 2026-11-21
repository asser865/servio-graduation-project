// backend/src/modules/services/__tests__/service-techstats.test.js
//
// Option B: getAllServices/getServiceById attach a per-service `techStats`
// aggregate computed over the SAME "available verified technician" filter
// used by user.controller.js#getWorkers, so the marketplace card and the
// service drawer/modal read one backend source and never disagree.
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Service = require('../service.model');
const User = require('../../users/user.model');
const { getAllServices, getServiceById } = require('../service.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function baseService(extra = {}) {
  return {
    title: 'Pipe Repair', description: 'Fix pipes',
    category: 'plumbing', basePrice: 300, priceUnit: 'fixed',
    estimatedDurationMin: 60,
    createdBy: new mongoose.Types.ObjectId(), ...extra,
  };
}

// Matches the "available verified technician" filter in
// user.controller.js#getWorkers: role 'worker', isActive, isVerified,
// isAvailable, and at least one availability slot.
function availableVerifiedWorker(extra = {}) {
  return {
    name: 'Tech', email: `tech-${new mongoose.Types.ObjectId()}@example.com`,
    password: 'Password1!',
    role: 'worker',
    isActive: true,
    isVerified: true,
    isAvailable: true,
    availability: [{ day: 'monday', from: '09:00', to: '17:00' }],
    ...extra,
  };
}

test('getAllServices attaches techStats aggregated over available verified workers who offer the service', async () => {
  const service = await Service.create(baseService());

  const workerA = await User.create(availableVerifiedWorker({
    averageRating: 4.5,
    totalReviews: 10,
    services: [{ serviceId: service._id, startsFrom: 250 }],
  }));
  const workerB = await User.create(availableVerifiedWorker({
    averageRating: 5,
    totalReviews: 4,
    services: [{ serviceId: service._id, startsFrom: 200 }],
  }));

  // Decoy: not available/verified — must NOT count toward techStats.
  await User.create(availableVerifiedWorker({
    isAvailable: false,
    averageRating: 1,
    totalReviews: 99,
    services: [{ serviceId: service._id, startsFrom: 100 }],
  }));

  const { services } = await getAllServices({});
  const found = services.find(s => String(s._id) === String(service._id));

  expect(found).toBeDefined();
  expect(found.techStats).toBeDefined();
  expect(found.techStats.pros).toBe(2);
  expect(found.techStats.reviews).toBe(14); // 10 + 4
  // weighted avg = (4.5*10 + 5*4) / 14 = (45 + 20) / 14 = 4.642857...
  expect(found.techStats.rating).toBeCloseTo((4.5 * 10 + 5 * 4) / 14, 5);
  expect(found.techStats.minStartsFrom).toBe(200); // min(250, 200)

  // Sanity: decoy worker truly excluded — pros stays 2, not 3.
  expect(found.techStats.pros).not.toBe(3);

  // Suppress unused var lint noise without removing intent-revealing names.
  expect(workerA.role).toBe('worker');
  expect(workerB.role).toBe('worker');
});

test('a service with no offering workers gets a zeroed techStats', async () => {
  const service = await Service.create(baseService({ title: 'Lonely Service' }));

  const { services } = await getAllServices({});
  const found = services.find(s => String(s._id) === String(service._id));

  expect(found).toBeDefined();
  expect(found.techStats).toEqual({ pros: 0, reviews: 0, rating: 0, minStartsFrom: null });
});

test('getServiceById also attaches techStats for a single service', async () => {
  const service = await Service.create(baseService({ title: 'Solo Lookup' }));
  await User.create(availableVerifiedWorker({
    averageRating: 4,
    totalReviews: 6,
    services: [{ serviceId: service._id, startsFrom: 150 }],
  }));

  const found = await getServiceById(service._id);

  expect(found.techStats).toBeDefined();
  expect(found.techStats.pros).toBe(1);
  expect(found.techStats.reviews).toBe(6);
  expect(found.techStats.rating).toBeCloseTo(4, 5);
  expect(found.techStats.minStartsFrom).toBe(150);
});
