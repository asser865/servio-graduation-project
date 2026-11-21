const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');
const Booking = require('./booking.model');
const Payment = require('../payments/payment.model');
const Service = require('../services/service.model');
const settings = require('../admin/admin-settings.service');
const adminAction = require('../admin/admin-action.service');
const ApiError = require('../../utils/ApiError');
const { money } = require('../../utils/rounding');
const { HIGH_VALUE_THRESHOLD_EGP } = require('../../config/finance.config');

let paymentService;
const getPaymentService = () => {
  if (!paymentService) paymentService = require('../payments/payment.service');
  return paymentService;
};

const VALID_OUTCOMES = Booking.COMPLETION_OUTCOME_VALUES;

function hasPhotos(value) {
  return Array.isArray(value) && value.some(photo => typeof photo === 'string' && photo.trim());
}

function requiredText(value, message) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ApiError(StatusCodes.BAD_REQUEST, message);
  }
}

async function submit(bookingId, workerId, payload) {
  const {
    outcome,
    beforePhotos = [],
    afterPhotos = [],
    workerNotes,
    materialsUsed,
    refusalReason,
    couldNotCompleteReason,
    declineReason,
  } = payload;

  if (!VALID_OUTCOMES.includes(outcome)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid outcome');
  }
  if (outcome === 'customer_paid' && (!hasPhotos(beforePhotos) || !hasPhotos(afterPhotos))) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Before and after completion photos are required.');
  }
  if (outcome === 'customer_refused_payment') {
    requiredText(refusalReason, 'Refusal reason is required.');
  }
  if (outcome === 'could_not_complete') {
    requiredText(couldNotCompleteReason, 'Incomplete-job reason is required.');
  }
  if (outcome === 'customer_declined_work') {
    requiredText(declineReason, 'Decline reason is required.');
  }

  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (String(booking.worker) !== String(workerId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Worker not authorized for this booking');
  }
  if (!['in_progress', 'arrived'].includes(booking.status)) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Cannot submit outcome from status '${booking.status}'`
    );
  }

  const submittedAt = new Date();
  let claimedBooking = booking;

  // I-B: gate the status transition with a conditional update so a concurrent
  // double-submit cannot double-process the outcome (and, for customer_paid,
  // double-write the invoice / double-capture money later).
  if (outcome === 'customer_paid') {
    const claimed = await Booking.findOneAndUpdate(
      { _id: bookingId, status: { $in: ['in_progress', 'arrived'] } },
      { $set: { status: 'awaiting_customer_confirmation' } },
      { returnDocument: 'after' }
    );
    if (!claimed) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot submit outcome from status '${booking.status}'`
      );
    }
    claimedBooking = claimed;
  } else if (outcome === 'customer_declined_work') {
    // customer_declined_work is claimable from the SAME source statuses as
    // customer_paid ('in_progress'/'arrived') — a declined job has no
    // customer-approval step, so the claim's target is the terminal
    // 'customer_declined' status directly (not an intermediate awaiting_* state).
    const claimed = await Booking.findOneAndUpdate(
      { _id: bookingId, status: { $in: ['in_progress', 'arrived'] } },
      { $set: { status: 'customer_declined' } },
      { returnDocument: 'after' }
    );
    if (!claimed) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot submit outcome from status '${booking.status}'`
      );
    }
    claimedBooking = claimed;
  }

  claimedBooking.completionOutcome = {
    outcome,
    submittedAt,
    beforePhotos,
    afterPhotos,
    workerNotes,
    materialsUsed,
    refusalReason,
    couldNotCompleteReason,
    declineReason,
  };

  switch (outcome) {
    case 'customer_paid': {
      // status already set to 'awaiting_customer_confirmation' by the atomic claim above.
      claimedBooking.actualCompletedAt = claimedBooking.actualCompletedAt || submittedAt;

      // ── Itemized invoice (no money movement yet) ──────────────────────────
      const materials = Array.isArray(payload.materials) ? payload.materials : [];
      if (materials.length > 50) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Too many material lines.');
      }
      for (const m of materials) {
        if (!m.name || !String(m.name).trim()) {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'Material name required.');
        }
        if (!(Number(m.qty) >= 1)) {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'Material qty must be ≥ 1.');
        }
        if (!(Number(m.unitPrice) > 0)) {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'Material unitPrice must be > 0.');
        }
      }

      const labor = Number(payload.laborAmount) || 0;
      const matSum = materials.reduce((s, m) => s + Number(m.qty) * Number(m.unitPrice), 0);
      const rate = (claimedBooking.platformFeeRate ?? 10) / 100;

      claimedBooking.laborAmount = money(labor);
      claimedBooking.materials = materials;
      claimedBooking.subtotal = money(labor + matSum);
      claimedBooking.platformFee = money(labor * rate); // Adj.14 — labor only
      claimedBooking.grandTotal = money(claimedBooking.subtotal + claimedBooking.platformFee);

      const cfg = await settings.get();
      const vatRate = cfg?.vat?.rate ?? 0.14;
      // VAT is the portion INSIDE grandTotal (inclusive), NOT rate × subtotal (Guard B / P1).
      claimedBooking.vat = money(
        claimedBooking.grandTotal - claimedBooking.grandTotal / (1 + vatRate)
      ); // reporting only

      const bandMax = claimedBooking.seedRangeSnapshot?.max || 0;
      const mult = cfg?.pricing?.overBandMultiplier ?? 1.5;
      claimedBooking.isOverBand = bandMax > 0 && claimedBooking.grandTotal > money(bandMax * mult);
      if (claimedBooking.isOverBand || claimedBooking.grandTotal >= HIGH_VALUE_THRESHOLD_EGP) { // R1 + over-band
        claimedBooking.flaggedForReview = true;
        claimedBooking.flagReason = claimedBooking.isOverBand ? 'over_band_invoice' : 'high_value_invoice';
      }

      const hours = Number(cfg?.escrow?.autoConfirmHours || 48);
      claimedBooking.customerConfirmAutoAt = new Date(submittedAt.getTime() + hours * 3600 * 1000);
      break;
    }
    case 'customer_refused_payment':
      claimedBooking.status = 'payment_refused';
      claimedBooking.refusalVerification = {
        status: 'pending',
        notifiedAt: new Date(),
      };
      break;
    case 'could_not_complete':
      claimedBooking.status = 'incomplete_review';
      break;
    case 'customer_declined_work': {
      // status already set to 'customer_declined' (terminal) by the atomic claim above.
      //
      // P4: capture-at-submit is the ONE intentional exception in this file. Every
      // other outcome either captures money later (customer_paid -> admin/auto
      // release) or never captures at all. A declined job has no customer-approval
      // step to wait for, so settling the callout/inspection fee here — right when
      // the worker reports the decline — is correct and terminal. Because we DO
      // capture money in this branch, we must update paymentStatus + write an audit
      // entry exactly like releaseHeldPayment does; leaving the payment in 'held'
      // after a real capture would desync booking.paymentStatus from reality.
      const service = await Service.findById(claimedBooking.service);
      const calloutFee = money(service?.inspectionFee || 0);

      if (['online', 'card'].includes(claimedBooking.paymentMethod) && calloutFee > 0) {
        const payment = await Payment.findOne({ booking: claimedBooking._id, status: 'held' });
        if (payment) {
          const session = await mongoose.startSession();
          try {
            await session.withTransaction(async () => {
              const { remainingAmount } = await getPaymentService().settleToAmount(payment, claimedBooking, calloutFee, session);

              payment.status = 'released';
              payment.releasedAt = new Date();
              payment.releaseApprovedAt = new Date();
              await payment.save({ session });

              claimedBooking.paymentStatus = 'released';
              await claimedBooking.save({ session });

              await adminAction.record({
                actionType: 'callout_fee_captured',
                targetType: 'payment',
                targetId: payment._id,
                details: {
                  bookingId: claimedBooking._id,
                  calloutFee,
                  declineReason,
                },
                session,
              });

              // Mirror releaseHeldPayment / dispute partial_refund: the worker must
              // receive the callout earning AFTER cash-debt offset (settleToAmount's
              // settleCashDebtsFromAmount already settled debts oldest-first from
              // workerEarning). Without this credit, the leftover after debts never
              // reached wallet.balance — a confirmed money bug. Reconcile AFTER the
              // payment is saved as 'released' so the pending-balance recompute
              // correctly excludes this payment (it's no longer held/disputed).
              const { wallet } = await getPaymentService().reconcileWorkerWalletState(payment.worker || claimedBooking.worker, session);
              await wallet.credit(remainingAmount);
            });
          } finally {
            await session.endSession();
          }
        }
      }
      // CASH (or no held payment / no service / inspectionFee 0): no-op — nothing to
      // capture. Booking is still terminal 'customer_declined'.
      break;
    }
  }

  await claimedBooking.save();
  return claimedBooking;
}

module.exports = { submit, VALID_OUTCOMES };
