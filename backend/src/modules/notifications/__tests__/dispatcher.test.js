const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const dispatcher = require('../dispatcher');
const NotificationPreference = require('../preferences.model');
const Notification = require('../notification.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(async () => {
  dispatcher._clearOverrides();
  await db.clear();
});

function uid() { return new mongoose.Types.ObjectId(); }

describe('notification dispatcher', () => {
  test('returns no_template for unknown event', async () => {
    const r = await dispatcher.dispatch('unknown.event', { userId: uid() });
    expect(r.dispatched).toBe(false);
    expect(r.reason).toBe('no_template');
  });

  test('returns no_recipient when payload has no userId/customer/worker', async () => {
    const r = await dispatcher.dispatch('payment.held', { amount: 100 });
    expect(r.dispatched).toBe(false);
    expect(r.reason).toBe('no_recipient');
  });

  test('routes payment.held to email + in-app by default', async () => {
    const calls = { email: 0, inApp: 0 };
    dispatcher._setChannelOverride('email',  { send: async () => { calls.email++;  } });
    dispatcher._setChannelOverride('in-app', { send: async () => { calls.inApp++; } });
    const r = await dispatcher.dispatch('payment.held', { customer: uid(), amount: 500 });
    expect(r.dispatched).toBe(true);
    expect(calls.email).toBe(1);
    expect(calls.inApp).toBe(1);
  });

  test('respects per-channel preference (email off)', async () => {
    const userId = uid();
    await NotificationPreference.create({
      user: userId,
      channels: { email: false, inApp: true, push: true, sms: false },
    });
    const calls = { email: 0, inApp: 0 };
    dispatcher._setChannelOverride('email',  { send: async () => { calls.email++;  } });
    dispatcher._setChannelOverride('in-app', { send: async () => { calls.inApp++; } });
    const r = await dispatcher.dispatch('payment.held', { customer: userId, amount: 500 });
    expect(r.channels.find(c => c.channel === 'email').reason).toBe('pref_disabled');
    expect(calls.email).toBe(0);
    expect(calls.inApp).toBe(1);
  });

  test('in-app channel writes Notification doc with mapped enum type', async () => {
    const userId = uid();
    await dispatcher.dispatch('credit.issued', { customer: userId, amount: 100, currency: 'EGP', reason: 'apology' });
    const notes = await Notification.find({ userId });
    expect(notes).toHaveLength(1);
    expect(notes[0].type).toBe('credit_issued');
    expect(notes[0].title).toMatch(/Credit issued/);
    expect(notes[0].body).toMatch(/100/);
  });

  test('channel failure is swallowed and reported per-channel', async () => {
    const userId = uid();
    dispatcher._setChannelOverride('email',  { send: async () => { throw new Error('SMTP down'); } });
    dispatcher._setChannelOverride('in-app', { send: async () => 'ok' });
    const r = await dispatcher.dispatch('payment.held', { customer: userId, amount: 100 });
    expect(r.dispatched).toBe(true);
    const emailRes = r.channels.find(c => c.channel === 'email');
    expect(emailRes.sent).toBe(false);
    expect(emailRes.error).toMatch(/SMTP/);
  });

  test('safeDispatch never throws', async () => {
    const r = await dispatcher.safeDispatch('unknown.event', {});
    expect(r.dispatched).toBe(false);
  });
});
