const Booking = require('../src/modules/bookings/booking.model');
const autoFeeDebt = require('../src/modules/payments/auto-fee-debt.service');
const techReputation = require('../src/modules/trust/tech-reputation.service');
const service = require('../src/modules/bookings/refusal-verification.service');

jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/payments/auto-fee-debt.service', () => ({
  createIfClean: jest.fn(),
}));
jest.mock('../src/modules/trust/tech-reputation.service', () => ({
  recordIncident: jest.fn().mockResolvedValue(),
}));

beforeEach(() => jest.clearAllMocks());

test('customer confirms refusal and booking routes to investigation without debt', async () => {
  const booking = {
    _id: 'b1',
    user: 'u1',
    worker: 'w1',
    status: 'payment_refused',
    refusalVerification: { status: 'pending' },
    save: jest.fn(),
  };
  Booking.findById.mockResolvedValue(booking);

  const result = await service.respond('b1', 'u1', {
    customerConfirmsRefusal: true,
    customerResponse: 'I refused because the job was incomplete.',
  });

  expect(result.status).toBe('refusal_under_investigation');
  expect(result.refusalVerification.status).toBe('customer_confirmed_refusal');
  expect(autoFeeDebt.createIfClean).not.toHaveBeenCalled();
});

test('customer disputes refusal and false-claim incident creates fee debt', async () => {
  const booking = {
    _id: 'b1',
    user: 'u1',
    worker: 'w1',
    status: 'payment_refused',
    refusalVerification: { status: 'pending' },
    save: jest.fn(),
  };
  Booking.findById.mockResolvedValue(booking);
  autoFeeDebt.createIfClean.mockImplementation(async () => {
    booking.status = 'completed';
    booking.paymentStatus = 'cash_pending_settlement';
    return { booking, created: true };
  });

  const result = await service.respond('b1', 'u1', {
    customerConfirmsRefusal: false,
    customerResponse: 'I paid the technician in cash.',
  });

  expect(result.status).toBe('completed');
  expect(result.refusalVerification.status).toBe('customer_disputes_refusal');
  expect(techReputation.recordIncident).toHaveBeenCalledWith('w1', expect.objectContaining({
    type: 'false_refusal_claim',
    bookingId: 'b1',
  }));
  expect(autoFeeDebt.createIfClean).toHaveBeenCalledWith('b1');
});

test('rejects response from another customer', async () => {
  Booking.findById.mockResolvedValue({
    _id: 'b1',
    user: 'other',
    refusalVerification: { status: 'pending' },
  });
  await expect(service.respond('b1', 'u1', { customerConfirmsRefusal: true }))
    .rejects.toThrow(/not authorized/i);
});
