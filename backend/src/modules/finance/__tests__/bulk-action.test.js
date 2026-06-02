jest.mock('../../bookings/booking.model', () => ({
  find: jest.fn(),
}));
jest.mock('../../payments/payment.service', () => ({
  adminApproveCompletion: jest.fn(),
  validateAdminApproveCompletion: jest.fn(),
}));
jest.mock('../queue-classifier.service', () => ({
  classify: jest.fn(),
}));

const Booking = require('../../bookings/booking.model');
const paymentService = require('../../payments/payment.service');
const { classify } = require('../queue-classifier.service');
const { releaseLowRiskBookings } = require('../bulk-action.controller');

function makeResponse() {
  return {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
}

describe('finance bulk release controller', () => {
  const adminId = 'admin-1';

  beforeEach(() => {
    jest.clearAllMocks();
    paymentService.validateAdminApproveCompletion.mockResolvedValue();
  });

  test('rejects the full batch when any booking is not low risk', async () => {
    Booking.find.mockResolvedValue([
      { _id: 'booking-1', totalPrice: 500 },
      { _id: 'booking-2', totalPrice: 750 },
    ]);
    classify
      .mockReturnValueOnce({ tier: 'low', reason: 'LOW_RISK' })
      .mockReturnValueOnce({ tier: 'medium', reason: 'AUTO_RELEASE_BLOCK' });

    await expect(releaseLowRiskBookings(
      { body: { ids: ['booking-1', 'booking-2'] }, user: { id: adminId } },
      makeResponse()
    )).rejects.toMatchObject({
      statusCode: 400,
      message: 'Bulk release only accepts low-risk bookings.',
      errors: [{
        id: 'booking-2',
        tier: 'medium',
        reason: 'AUTO_RELEASE_BLOCK',
      }],
    });

    expect(paymentService.adminApproveCompletion).not.toHaveBeenCalled();
  });

  test('releases every booking when all classifications are low risk', async () => {
    Booking.find.mockResolvedValue([
      { _id: 'booking-1', totalPrice: 500 },
      { _id: 'booking-2', totalPrice: 750 },
    ]);
    classify.mockReturnValue({ tier: 'low', reason: 'LOW_RISK' });
    paymentService.adminApproveCompletion
      .mockResolvedValueOnce({ id: 'booking-1', status: 'released' })
      .mockResolvedValueOnce({ id: 'booking-2', status: 'released' });
    const res = makeResponse();

    await releaseLowRiskBookings(
      { body: { ids: ['booking-1', 'booking-2'] }, user: { id: adminId } },
      res
    );

    expect(classify).toHaveBeenNthCalledWith(1, { _id: 'booking-1', totalPrice: 500, amount: 500, type: 'card_release' });
    expect(classify).toHaveBeenNthCalledWith(2, { _id: 'booking-2', totalPrice: 750, amount: 750, type: 'card_release' });
    expect(paymentService.adminApproveCompletion).toHaveBeenNthCalledWith(
      1,
      'booking-1',
      adminId,
      { reasonCode: 'bulk_low_risk' }
    );
    expect(paymentService.adminApproveCompletion).toHaveBeenNthCalledWith(
      2,
      'booking-2',
      adminId,
      { reasonCode: 'bulk_low_risk' }
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      released: [
        { id: 'booking-1', status: 'released' },
        { id: 'booking-2', status: 'released' },
      ],
    });
  });

  test('rejects the full batch before release when any booking fails eligibility preflight', async () => {
    Booking.find.mockResolvedValue([
      { _id: 'booking-1', totalPrice: 500 },
      { _id: 'booking-2', totalPrice: 750 },
    ]);
    classify.mockReturnValue({ tier: 'low', reason: 'LOW_RISK' });
    paymentService.validateAdminApproveCompletion
      .mockResolvedValueOnce()
      .mockRejectedValueOnce(new Error('Missing completion evidence.'));

    await expect(releaseLowRiskBookings(
      { body: { ids: ['booking-1', 'booking-2'] }, user: { id: adminId } },
      makeResponse()
    )).rejects.toMatchObject({
      statusCode: 400,
      message: 'Some bookings are not eligible for release.',
      errors: [{ id: 'booking-2', reason: 'Missing completion evidence.' }],
    });

    expect(paymentService.adminApproveCompletion).not.toHaveBeenCalled();
  });

  test('rejects missing bookings before classification or release', async () => {
    Booking.find.mockResolvedValue([{ _id: 'booking-1' }]);

    await expect(releaseLowRiskBookings(
      { body: { ids: ['booking-1', 'booking-2'] }, user: { id: adminId } },
      makeResponse()
    )).rejects.toMatchObject({
      statusCode: 400,
      message: 'Some bookings could not be found.',
      errors: [{ id: 'booking-2' }],
    });

    expect(classify).not.toHaveBeenCalled();
    expect(paymentService.adminApproveCompletion).not.toHaveBeenCalled();
  });

  test('rejects an empty ids array', async () => {
    await expect(releaseLowRiskBookings(
      { body: { ids: [] }, user: { id: adminId } },
      makeResponse()
    )).rejects.toMatchObject({
      statusCode: 400,
      message: 'ids must be a non-empty array.',
    });

    expect(Booking.find).not.toHaveBeenCalled();
  });
});
