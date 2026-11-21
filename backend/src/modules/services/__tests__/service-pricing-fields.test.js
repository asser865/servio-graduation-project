// backend/src/modules/services/__tests__/service-pricing-fields.test.js
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Service = require('../service.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function base(extra = {}) {
  return {
    title: 'Pipe Repair', description: 'Fix pipes',
    category: 'plumbing', basePrice: 300, priceUnit: 'fixed',
    estimatedDurationMin: 60,
    createdBy: new mongoose.Types.ObjectId(), ...extra,
  };
}

test('serviceType defaults to immediate; seedRange + inspectionFee persist', async () => {
  const s = await Service.create(base({ seedRange: { min: 300, max: 700 }, inspectionFee: 100 }));
  expect(s.serviceType).toBe('immediate');
  expect(s.seedRange.min).toBe(300);
  expect(s.seedRange.max).toBe(700);
  expect(s.inspectionFee).toBe(100);
});

test('serviceType rejects unknown enum', async () => {
  await expect(Service.create(base({ serviceType: 'bogus' }))).rejects.toThrow();
});
