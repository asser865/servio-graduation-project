const mongoose = require('mongoose');
const Booking = require('./booking.model');
const Payment = require('../payments/payment.model');
const Transaction = require('../payments/transaction.model');
const paymentService = require('../payments/payment.service');
const WorkerStrike = require('../users/worker-strike.model');
const adminSettings = require('../admin/admin-settings.service');
const getGateway = require('../payments/gateways');
const ApiError = require('../../utils/ApiError');
const { StatusCodes } = require('http-status-codes');
const notify = require('../notifications/dispatcher');
const { money: r2 } = require('../../utils/rounding');

const NOSHOW_ELIGIBLE = ['accepted', 'en_route', 'arrived', 'in_progress'];

async function markCustomerNoShow(bookingId, { by, evidence = [], note }) {
  const session = await mongoose.startSession();
  let result, customerId;
  try {
    result = await session.withTransaction(async () => {
      const booking = await Booking.findById(bookingId).session(session);
      if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
      if (String(booking.worker) !== String(by)) throw new ApiError(StatusCodes.FORBIDDEN, 'Not your booking.');
      if (!NOSHOW_ELIGIBLE.includes(booking.status)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Booking not eligible for no-show (status '${booking.status}').`);
      }

      const cfg = await adminSettings.get();
      const noShowFeePct = cfg.noShow?.customerNoShowFeePercent ?? 50;

      let workerCompensation = 0;
      let refundAmount = 0;
      const payment = booking.paymentMethod === 'online'
        ? await Payment.findOne({ booking: booking._id, status: 'held' }).session(session)
        : null;

      if (payment) {
        workerCompensation = r2(payment.amount * (noShowFeePct / 100));
        refundAmount = r2(payment.amount - workerCompensation);

        if (refundAmount > 0) {
          if (payment.gatewayChargeId) {
            try {
              const gw = getGateway();
              const ref = await gw.refund({
                chargeId: payment.gatewayChargeId,
                amount: refundAmount,
                reason: 'customer_no_show',
              });
              payment.gatewayRefundId = ref?.refundId;
            } catch (_) {}
          }
        }

        payment.status = refundAmount > 0 ? 'partially_refunded' : 'released';
        payment.releasedAt = new Date();
        payment.refundedAmount = (payment.refundedAmount || 0) + refundAmount;
        await payment.save({ session });

        booking.paymentStatus = refundAmount > 0 ? 'refunded' : 'released';
        const { wallet } = await paymentService.reconcileWorkerWalletState(booking.worker, session);
        wallet.balance = r2((wallet.balance || 0) + workerCompensation);
        wallet.totalEarned = r2((wallet.totalEarned || 0) + workerCompensation);
        await wallet.save({ session });

        await Transaction.create([{
          payment: payment._id,
          wallet: wallet._id,
          type: 'no_show_fee',
          amount: workerCompensation,
          currency: payment.currency || 'egp',
          direction: 'credit',
          actor: by,
          note: 'Customer no-show: worker compensation',
        }], { session });

        if (refundAmount > 0) {
          await Transaction.create([{
            payment: payment._id,
            type: 'refund',
            amount: refundAmount,
            currency: payment.currency || 'egp',
            direction: 'credit',
            actor: by,
            note: 'Customer no-show: residual refund',
          }], { session });
        }
      }

      booking.status = 'customer_no_show';
      booking.noShowMarkedAt = new Date();
      booking.noShowMarkedBy = by;
      booking.noShowEvidence = evidence;
      if (note) booking.cancellationReason = String(note).slice(0, 240);
      await booking.save({ session });

      customerId = booking.user;
      return { workerCompensation, refundAmount, status: booking.status };
    });
  } finally { session.endSession(); }

  if (customerId) {
    notify.safeDispatch('booking.no_show', {
      recipient: customerId,
      bookingId,
      kind: 'customer_no_show',
    });
  }
  return result;
}

async function markWorkerNoShow(bookingId, { by, note }) {
  const session = await mongoose.startSession();
  let result, workerId;
  try {
    result = await session.withTransaction(async () => {
      const booking = await Booking.findById(bookingId).session(session);
      if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
      if (String(booking.user) !== String(by)) throw new ApiError(StatusCodes.FORBIDDEN, 'Not your booking.');
      if (!booking.worker) throw new ApiError(StatusCodes.BAD_REQUEST, 'No worker assigned.');
      if (!NOSHOW_ELIGIBLE.includes(booking.status)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Booking not eligible for no-show (status '${booking.status}').`);
      }

      const cfg = await adminSettings.get();
      const expiresAt = new Date(Date.now() + cfg.cancellation.workerStrikeWindowDays * 86400000);

      await WorkerStrike.create([{
        worker: booking.worker,
        booking: booking._id,
        reason: 'no_show',
        issuedAt: new Date(),
        expiresAt,
        notes: (note || '').slice(0, 240),
      }], { session });

      let refundAmount = 0;
      const payment = booking.paymentMethod === 'online'
        ? await Payment.findOne({ booking: booking._id, status: 'held' }).session(session)
        : null;

      if (payment) {
        refundAmount = payment.amount;
        if (payment.gatewayChargeId) {
          try {
            const gw = getGateway();
            const ref = await gw.refund({
              chargeId: payment.gatewayChargeId,
              amount: refundAmount,
              reason: 'worker_no_show',
            });
            payment.gatewayRefundId = ref?.refundId;
          } catch (_) {}
        }
        payment.status = 'refunded';
        payment.refundedAt = new Date();
        payment.refundedAmount = refundAmount;
        await payment.save({ session });

        await paymentService.reconcileWorkerWalletState(booking.worker, session);

        await Transaction.create([{
          payment: payment._id,
          type: 'worker_no_show_refund',
          amount: refundAmount,
          currency: payment.currency || 'egp',
          direction: 'credit',
          actor: by,
          note: 'Worker no-show: full refund to customer',
        }], { session });
      }

      booking.status = 'worker_no_show';
      booking.noShowMarkedAt = new Date();
      booking.noShowMarkedBy = by;
      if (note) booking.cancellationReason = String(note).slice(0, 240);
      if (payment) booking.paymentStatus = 'refunded';
      await booking.save({ session });

      workerId = booking.worker;
      return { refundAmount, status: booking.status };
    });
  } finally { session.endSession(); }

  if (workerId) {
    notify.safeDispatch('booking.no_show', {
      recipient: workerId,
      bookingId,
      kind: 'worker_no_show',
    });
  }
  return result;
}

module.exports = { markCustomerNoShow, markWorkerNoShow };
