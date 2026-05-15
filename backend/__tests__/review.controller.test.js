'use strict';

jest.mock('../src/modules/reviews/review.model.js');
jest.mock('../src/modules/bookings/booking.model.js');
jest.mock('../src/modules/notifications/notification.service.js');

const Review = require('../src/modules/reviews/review.model.js');
const Booking = require('../src/modules/bookings/booking.model.js');
const notifSvc = require('../src/modules/notifications/notification.service.js');
const { createReview } = require('../src/modules/reviews/review.controller.js');

const USER_ID = '664000000000000000000020';
const WORKER_ID = '664000000000000000000010';
const BOOKING_ID = '665000000000000000000010';

function mockReq() {
  return {
    body: {
      bookingId: BOOKING_ID,
      rating: 5,
      comment: 'Great service',
    },
    user: {
      id: USER_ID,
      name: 'Customer One',
    },
  };
}

function mockRes() {
  return {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
}

function mockBooking(status) {
  return {
    _id: BOOKING_ID,
    user: { toString: () => USER_ID },
    worker: WORKER_ID,
    status,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  Review.create = jest.fn().mockResolvedValue({
    _id: 'review1',
    booking: BOOKING_ID,
    rating: 5,
  });
  notifSvc.notifyReviewReceived = jest.fn();
});

describe('createReview', () => {
  test.each([
    'awaiting_customer_confirmation',
    'pending_admin_review',
    'completed',
  ])('allows reviews for %s bookings', async (status) => {
    Booking.findById = jest.fn().mockResolvedValue(mockBooking(status));
    const res = mockRes();

    await createReview(mockReq(), res);

    expect(Review.create).toHaveBeenCalledWith(
      expect.objectContaining({
        user: USER_ID,
        worker: WORKER_ID,
        booking: BOOKING_ID,
        rating: 5,
        comment: 'Great service',
      })
    );
    expect(res.status).toHaveBeenCalledWith(201);
    expect(notifSvc.notifyReviewReceived).toHaveBeenCalledWith(
      WORKER_ID,
      'Customer One',
      5,
      BOOKING_ID
    );
  });

  test('blocks reviews before the technician finishes the job', async () => {
    Booking.findById = jest.fn().mockResolvedValue(mockBooking('in_progress'));

    await expect(createReview(mockReq(), mockRes())).rejects.toMatchObject({
      statusCode: 400,
      message: 'You can review once the technician has marked the job complete.',
    });

    expect(Review.create).not.toHaveBeenCalled();
  });
});
