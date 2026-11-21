const completionOutcomeSvc = require('../src/modules/bookings/completion-outcome.service');
const Booking = require('../src/modules/bookings/booking.model');

jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/admin/admin-settings.service', () => ({
  get: jest.fn().mockResolvedValue({ escrow: { autoConfirmHours: 48 } }),
}));

describe('completionOutcomeService.submit', () => {
  beforeEach(() => jest.clearAllMocks());

  it('sets status to awaiting_customer_confirmation when outcome is customer_paid', async () => {
    const fakeBooking = {
      _id: 'b1',
      worker: 'w1',
      status: 'in_progress',
      paymentMethod: 'cash',
      save: jest.fn(),
    };
    const claimedBooking = {
      _id: 'b1',
      worker: 'w1',
      status: 'awaiting_customer_confirmation',
      paymentMethod: 'cash',
      platformFeeRate: 10,
      save: jest.fn(),
    };
    Booking.findById.mockResolvedValue(fakeBooking);
    Booking.findOneAndUpdate.mockResolvedValue(claimedBooking);

    await completionOutcomeSvc.submit('b1', 'w1', {
      outcome: 'customer_paid',
      beforePhotos: ['a'],
      afterPhotos: ['b'],
      workerNotes: 'done',
      laborAmount: 100,
      materials: [],
    });

    expect(claimedBooking.status).toBe('awaiting_customer_confirmation');
    expect(claimedBooking.completionOutcome.outcome).toBe('customer_paid');
    expect(claimedBooking.customerConfirmAutoAt).toBeInstanceOf(Date);
    expect(claimedBooking.actualCompletedAt).toBeInstanceOf(Date);
    expect(claimedBooking.save).toHaveBeenCalled();
  });

  it('rejects customer_paid when the atomic claim finds no eligible booking (concurrent submit)', async () => {
    const fakeBooking = {
      _id: 'b1',
      worker: 'w1',
      status: 'in_progress',
      paymentMethod: 'cash',
      save: jest.fn(),
    };
    Booking.findById.mockResolvedValue(fakeBooking);
    Booking.findOneAndUpdate.mockResolvedValue(null); // another request already advanced it

    await expect(
      completionOutcomeSvc.submit('b1', 'w1', {
        outcome: 'customer_paid',
        beforePhotos: ['a'],
        afterPhotos: ['b'],
        laborAmount: 100,
        materials: [],
      })
    ).rejects.toThrow(/cannot submit outcome/i);
    expect(fakeBooking.save).not.toHaveBeenCalled();
  });

  it('sets status to payment_refused when outcome is customer_refused_payment', async () => {
    const fakeBooking = {
      _id: 'b1',
      worker: 'w1',
      status: 'in_progress',
      paymentMethod: 'cash',
      save: jest.fn(),
    };
    Booking.findById.mockResolvedValue(fakeBooking);

    await completionOutcomeSvc.submit('b1', 'w1', {
      outcome: 'customer_refused_payment',
      refusalReason: 'customer unhappy with finish',
    });

    expect(fakeBooking.status).toBe('payment_refused');
    expect(fakeBooking.refusalVerification.status).toBe('pending');
    expect(fakeBooking.save).toHaveBeenCalled();
  });

  it('rejects when outcome is invalid', async () => {
    await expect(
      completionOutcomeSvc.submit('b1', 'w1', { outcome: 'banana' })
    ).rejects.toThrow(/invalid outcome/i);
  });

  it('rejects when worker is not the assigned worker', async () => {
    Booking.findById.mockResolvedValue({ _id: 'b1', worker: 'other-worker' });
    await expect(
      completionOutcomeSvc.submit('b1', 'w1', { outcome: 'customer_paid', beforePhotos: ['a'], afterPhotos: ['b'] })
    ).rejects.toThrow(/not authorized/i);
  });

  it('rejects paid completion without before and after evidence', async () => {
    await expect(
      completionOutcomeSvc.submit('b1', 'w1', { outcome: 'customer_paid', afterPhotos: ['b'] })
    ).rejects.toThrow(/before and after completion photos are required/i);
  });

  it('rejects refusal without a reason', async () => {
    await expect(
      completionOutcomeSvc.submit('b1', 'w1', { outcome: 'customer_refused_payment', refusalReason: '  ' })
    ).rejects.toThrow(/refusal reason is required/i);
  });

  it('rejects incomplete outcome without a reason', async () => {
    await expect(
      completionOutcomeSvc.submit('b1', 'w1', { outcome: 'could_not_complete' })
    ).rejects.toThrow(/incomplete-job reason is required/i);
  });
});
