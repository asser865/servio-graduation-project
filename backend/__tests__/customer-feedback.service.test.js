const customerFeedbackSvc = require('../src/modules/bookings/customer-feedback.service');
const Booking = require('../src/modules/bookings/booking.model');
const autoFeeDebtSvc = require('../src/modules/payments/auto-fee-debt.service');

jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/payments/auto-fee-debt.service', () => ({
  createIfClean: jest.fn(),
}));

describe('customerFeedbackService.submit', () => {
  beforeEach(() => jest.clearAllMocks());

  it('confirms cash job through automatic fee-debt finalization', async () => {
    const fake = {
      _id: 'b1', user: 'u1', paymentMethod: 'cash',
      status: 'awaiting_customer_confirmation',
      save: jest.fn(),
    };
    Booking.findById.mockResolvedValue(fake);
    autoFeeDebtSvc.createIfClean.mockResolvedValue({
      booking: { ...fake, status: 'completed', paymentStatus: 'cash_pending_settlement' },
    });

    const result = await customerFeedbackSvc.submit('b1', 'u1', { action: 'confirmed', rating: 5 });

    expect(fake.customerFeedback.action).toBe('confirmed');
    expect(fake.customerFeedback.rating).toBe(5);
    expect(fake.customerFeedback.confirmedVia).toBe('customer');
    expect(autoFeeDebtSvc.createIfClean).toHaveBeenCalledWith('b1');
    expect(result.status).toBe('completed');
    expect(result.paymentStatus).toBe('cash_pending_settlement');
  });

  it('opens dispute path when action is reported_issue', async () => {
    const fake = {
      _id: 'b1', user: 'u1', paymentMethod: 'cash',
      status: 'awaiting_customer_confirmation',
      save: jest.fn(),
    };
    Booking.findById.mockResolvedValue(fake);

    await customerFeedbackSvc.submit('b1', 'u1', {
      action: 'reported_issue',
      issueReason: 'work_not_done',
      notes: 'Tap still leaks',
      evidenceImages: ['url1'],
    });

    expect(fake.status).toBe('customer_disputed');
    expect(fake.customerFeedback.issueReason).toBe('work_not_done');
  });

  it('rejects when user is not the booking owner', async () => {
    Booking.findById.mockResolvedValue({ _id: 'b1', user: 'other' });
    await expect(
      customerFeedbackSvc.submit('b1', 'u1', { action: 'confirmed' })
    ).rejects.toThrow(/not authorized/i);
  });
});
