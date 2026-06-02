const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const Booking = require('../bookings/booking.model');
const CashDebt = require('./cash-debt.model');
const enhancedReview = require('../finance/enhanced-review.service');
const ApiError = require('../../utils/ApiError');

const ACTIVE_DISPUTE_STATUSES = enhancedReview.ACTIVE_DISPUTE_STATUSES;

async function createIfClean(bookingId) {
  const session = await mongoose.startSession();
  let result;

  try {
    try {
      await session.withTransaction(async () => {
        const booking = await Booking.findById(bookingId).session(session);
        if (!booking) {
          throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
        }

        if (booking.paymentMethod !== 'cash') {
          result = { booking, debt: null, created: false, skippedReason: 'non_cash' };
          return;
        }

        if (booking.customerFeedback?.action === 'reported_issue') {
          result = { booking, debt: null, created: false, skippedReason: 'customer_reported_issue' };
          return;
        }

        const review = await enhancedReview.shouldBlock(booking, session);
        if (review.blocked) {
          booking.enhancedReviewReason = review.reason;
          await booking.save({ session });
          result = {
            booking,
            debt: null,
            created: false,
            skippedReason: review.signal || review.reason,
          };
          return;
        }

        const existingDebt = await CashDebt.findOne({ booking: booking._id }).session(session);
        if (existingDebt) {
          result = { booking, debt: existingDebt, created: false, skippedReason: 'existing_debt' };
          return;
        }

        booking.status = 'completed';
        booking.paymentStatus = 'cash_pending_settlement';
        await booking.save({ session });

        let debt = null;
        if (booking.platformFeeAmount > 0) {
          [debt] = await CashDebt.create([{
            worker: booking.worker,
            booking: booking._id,
            amount: booking.platformFeeAmount,
            debtType: 'platform_fee',
          }], { session });
        }

        result = { booking, debt, created: Boolean(debt), skippedReason: null };
      });
    } catch (err) {
      if (err?.code !== 11000) throw err;

      const [booking, debt] = await Promise.all([
        Booking.findById(bookingId),
        CashDebt.findOne({ booking: bookingId }),
      ]);
      result = { booking, debt, created: false, skippedReason: 'existing_debt' };
    }

    return result;
  } finally {
    await session.endSession();
  }
}

module.exports = { createIfClean, ACTIVE_DISPUTE_STATUSES };
