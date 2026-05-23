const mongoose = require('mongoose');
const Booking = require('./booking.model');
const Payment = require('../payments/payment.model');
const Transaction = require('../payments/transaction.model');
const WorkerStrike = require('../users/worker-strike.model');
const User = require('../users/user.model');
const Wallet = require('../payments/wallet.model');
const adminSettings = require('../admin/admin-settings.service');
const getGateway = require('../payments/gateways');
const ApiError = require('../../utils/ApiError');
const { StatusCodes } = require('http-status-codes');
const { money } = require('../../utils/rounding');

const PRE_ACCEPT_STATUSES = ['pending'];
const POST_ACCEPT_CANCELLABLE = ['accepted', 'en_route', 'arrived', 'in_progress'];
const ALL_CANCELLABLE = [...PRE_ACCEPT_STATUSES, ...POST_ACCEPT_CANCELLABLE];

const r2 = money;

async function customerCancel(bookingId, { reason, by }) {
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const booking = await Booking.findById(bookingId).session(session);
      if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
      if (String(booking.user) !== String(by)) throw new ApiError(StatusCodes.FORBIDDEN, 'Not your booking.');
      if (!ALL_CANCELLABLE.includes(booking.status)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot cancel booking with status '${booking.status}'.`);
      }

      const cfg = await adminSettings.get();
      const isPreAccept = PRE_ACCEPT_STATUSES.includes(booking.status);
      const minutesSinceAccept = booking.acceptedAt
        ? (Date.now() - new Date(booking.acceptedAt).getTime()) / 60000
        : 0;
      const inGrace = !isPreAccept && booking.acceptedAt
        && minutesSinceAccept <= cfg.cancellation.customerFreeWindowMinutes;

      let refundAmount = 0;
      let refundDestination = 'none';
      let lateFee = 0;

      const payment = booking.paymentMethod === 'online'
        ? await Payment.findOne({ booking: booking._id, status: 'held' }).session(session)
        : null;

      if (payment) {
        if (isPreAccept || inGrace) {
          refundAmount = payment.amount;
        } else {
          lateFee = r2(payment.amount * (cfg.cancellation.customerLateFeePercent / 100));
          refundAmount = r2(payment.amount - lateFee);
        }

        if (refundAmount > 0) {
          if (payment.gatewayChargeId) {
            try {
              const gw = getGateway();
              const ref = await gw.refund({
                chargeId: payment.gatewayChargeId,
                amount: refundAmount,
                reason: `customer_cancel:${reason || ''}`,
              });
              payment.gatewayRefundId = ref?.refundId;
              refundDestination = 'gateway';
            } catch (_) {
              refundDestination = 'gateway_failed';
            }
          } else {
            refundDestination = 'gateway';
          }
          payment.status = refundAmount === payment.amount ? 'refunded' : 'partially_refunded';
          payment.refundedAt = new Date();
          payment.refundedAmount = (payment.refundedAmount || 0) + refundAmount;
          await payment.save({ session });

          const wkrId = payment.worker || booking.worker;
          if (wkrId) {
            const wallet = await Wallet.findOne({ worker: wkrId }).session(session);
            if (wallet && wallet.pendingBalance >= payment.workerEarning) {
              await wallet.deductPending(payment.workerEarning);
            }
          }

          await Transaction.create([{
            payment: payment._id,
            type: 'refund',
            amount: refundAmount,
            currency: payment.currency || 'egp',
            direction: 'credit',
            actor: by,
            note: `Customer cancel refund (reason: ${reason || 'n/a'})`,
          }], { session });
        }

        if (lateFee > 0) {
          await Transaction.create([{
            payment: payment._id,
            type: 'platform_late_fee',
            amount: lateFee,
            currency: payment.currency || 'egp',
            direction: 'credit',
            actor: by,
            note: `Customer late cancel fee — booking ${booking._id}`,
          }], { session });
        }
      }

      booking.status = 'cancelled';
      booking.cancelledAt = new Date();
      booking.cancelledBy = by;
      booking.cancelledByRole = 'user';
      booking.cancellationReason = (reason || '').slice(0, 240);
      booking.lateFeeAmount = lateFee;
      if (payment) booking.paymentStatus = refundAmount === payment.amount ? 'refunded' : 'disputed';
      await booking.save({ session });

      return { refundAmount, refundDestination, lateFee, status: booking.status };
    });
  } finally { session.endSession(); }
}

async function workerCancel(bookingId, { reason, by }) {
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const booking = await Booking.findById(bookingId).session(session);
      if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
      if (String(booking.worker) !== String(by)) throw new ApiError(StatusCodes.FORBIDDEN, 'Not your booking.');
      if (!POST_ACCEPT_CANCELLABLE.includes(booking.status)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot cancel booking with status '${booking.status}'.`);
      }

      const cfg = await adminSettings.get();
      const expiresAt = new Date(Date.now() + cfg.cancellation.workerStrikeWindowDays * 86400000);

      await WorkerStrike.create([{
        worker: by,
        booking: booking._id,
        reason: 'late_cancel',
        issuedAt: new Date(),
        expiresAt,
        notes: (reason || '').slice(0, 240),
      }], { session });

      const activeStrikes = await WorkerStrike.countDocuments({
        worker: by,
        expiresAt: { $gt: new Date() },
      }).session(session);

      let suspended = false;
      let suspendedUntil = null;
      if (activeStrikes >= cfg.cancellation.workerStrikesPerSuspension) {
        suspendedUntil = new Date(Date.now() + cfg.cancellation.workerSuspensionDays * 86400000);
        await User.findByIdAndUpdate(by, { suspendedUntil }, { session });
        suspended = true;
      }

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
              reason: `worker_cancel:${reason || ''}`,
            });
            payment.gatewayRefundId = ref?.refundId;
          } catch (_) { /* swallow — booking still cancels */ }
        }
        payment.status = 'refunded';
        payment.refundedAt = new Date();
        payment.refundedAmount = refundAmount;
        await payment.save({ session });

        const wkrId = payment.worker || by;
        const wallet = await Wallet.findOne({ worker: wkrId }).session(session);
        if (wallet && wallet.pendingBalance >= payment.workerEarning) {
          await wallet.deductPending(payment.workerEarning);
        }

        await Transaction.create([{
          payment: payment._id,
          type: 'refund',
          amount: refundAmount,
          currency: payment.currency || 'egp',
          direction: 'credit',
          actor: by,
          note: `Worker cancel — full refund (reason: ${reason || 'n/a'})`,
        }], { session });
      }

      const previousWorker = booking.worker;
      await Booking.findByIdAndUpdate(
        booking._id,
        {
          $set: {
            status: 're_pooling',
            rePooledFrom: previousWorker,
            rePooledAt: new Date(),
            cancelledAt: new Date(),
            cancelledBy: by,
            cancelledByRole: 'worker',
            cancellationReason: (reason || '').slice(0, 240),
            ...(payment ? { paymentStatus: 'refunded' } : {}),
          },
          $unset: { worker: 1 },
        },
        { session }
      );
      booking.status = 're_pooling';

      return {
        strikeIssued: true,
        activeStrikes,
        suspended,
        suspendedUntil,
        refundAmount,
        status: booking.status,
      };
    });
  } finally { session.endSession(); }
}

module.exports = { customerCancel, workerCancel };
