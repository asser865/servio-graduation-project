const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const SavedCard = require('../savedCard.model');
const service = require('../savedCard.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function uid() { return new mongoose.Types.ObjectId(); }

describe('savedCard.service (gateway tokenization)', () => {
  test('add: saves card via gateway, marks first as default', async () => {
    const userId = uid();
    const c = await service.add(userId, { gatewayToken: 'tok_demo_visa' });
    expect(c.last4).toMatch(/^\d{4}$/);
    expect(c.brand).toBe('visa');
    expect(c.cardType).toBe('visa');
    expect(c.gatewayPaymentMethodId).toMatch(/^pm_demo_/);
    expect(c.isDefault).toBe(true);
  });

  test('add: second card for same user is not default', async () => {
    const userId = uid();
    await service.add(userId, { gatewayToken: 'tok_demo_visa' });
    const second = await service.add(userId, { gatewayToken: 'tok_demo_mc' });
    expect(second.isDefault).toBe(false);
    expect(second.brand).toBe('mastercard');
  });

  test('listForUser: only returns own cards', async () => {
    const a = uid(), b = uid();
    await service.add(a, { gatewayToken: 'tok_a' });
    await service.add(b, { gatewayToken: 'tok_b' });
    const list = await service.listForUser(a);
    expect(list).toHaveLength(1);
    expect(String(list[0].userId)).toBe(String(a));
  });

  test('remove: deletes card; promotes another to default if removed was default', async () => {
    const userId = uid();
    const a = await service.add(userId, { gatewayToken: 'tok_a' });
    const b = await service.add(userId, { gatewayToken: 'tok_b' });
    expect(a.isDefault).toBe(true);
    await service.remove(userId, a._id);
    expect(await SavedCard.findById(a._id)).toBeNull();
    const promoted = await SavedCard.findById(b._id);
    expect(promoted.isDefault).toBe(true);
  });

  test('remove: rejects cards owned by another user', async () => {
    const a = uid(), b = uid();
    const card = await service.add(a, { gatewayToken: 'tok_a' });
    await expect(service.remove(b, card._id)).rejects.toThrow(/not found/i);
  });

  test('setDefault: only one card is default at a time', async () => {
    const userId = uid();
    await service.add(userId, { gatewayToken: 'tok_a' });
    const b = await service.add(userId, { gatewayToken: 'tok_b' });
    await service.setDefault(userId, b._id);
    const all = await SavedCard.find({ userId });
    const defaults = all.filter(c => c.isDefault);
    expect(defaults).toHaveLength(1);
    expect(String(defaults[0]._id)).toBe(String(b._id));
  });

  test('add: rejects beyond MAX_CARDS', async () => {
    const userId = uid();
    for (let i = 0; i < service.MAX_CARDS; i++) {
      await service.add(userId, { gatewayToken: `tok_${i}` });
    }
    await expect(service.add(userId, { gatewayToken: 'tok_over' })).rejects.toThrow(/maximum/i);
  });
});
