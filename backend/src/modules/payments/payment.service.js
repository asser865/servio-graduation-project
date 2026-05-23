const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const Booking    = require('../bookings/booking.model');
const Payment    = require('./payment.model');
const SavedCard  = require('../savedCards/savedCard.model');
const Wallet     = require('./wallet.model');
const Transaction = require('./transaction.model');
const ApiError   = require('../../utils/ApiError');
const getGateway = require('./gateways');
const adminAction = require('../admin/admin-action.service');
const events = require('../../sockets/payment.events');
const notify = require('../notifications/dispatcher');

let cashDebtSvc;
const getCashDebtSvc = () => {
  if (!cashDebtSvc) cashDebtSvc = require('./cash-debt.service');
  return cashDebtSvc;
};

let adminSettingsSvc;
const getAdminSettingsSvc = () => {
  if (!adminSettingsSvc) adminSettingsSvc = require('../admin/admin-settings.service');
  return adminSettingsSvc;
};

const logTransaction = async (data, session) => {
  const [log] = await Transaction.create([data], session ? { session } : {});
  return log;
};

const getOrCreateWallet = async (workerId, session) => {
  let wallet = await Wallet.findOne({ worker: workerId }).session(session || null);
  if (!wallet) {
    [wallet] = await Wallet.create([{ worker: workerId }], session ? { session } : {});
  }
  return wallet;
};

class PaymentService {
  async holdPayment(bookingId, customerId, { savedCardId, useCredit = false }) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== customerId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    // Deadline check — must be first
    if (booking.paymentDeadline && Date.now() > new Date(booking.paymentDeadline).getTime()) {
      await Booking.findByIdAndUpdate(bookingId, { status: 'cancelled' }, { runValidators: false });
      throw new ApiError(StatusCodes.GONE, 'Payment deadline expired. Booking has been cancelled.');
    }

    // Lifecycle validation (never create/update Payment on these)
    if (!['card', 'online'].includes(booking.paymentMethod)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'This booking does not use online payment.');
    }
    if (booking.status !== 'pending') {
      throw new ApiError(StatusCodes.CONFLICT, `Cannot hold payment for booking with status '${booking.status}'.`);
    }

    // Idempotency — check existing Payment
    const existing = await Payment.findOne({ booking: bookingId });
    if (existing && ['held', 'released', 'refunded', 'disputed'].includes(existing.status)) {
      throw new ApiError(StatusCodes.CONFLICT, `Payment already in status '${existing.status}'.`);
    }

    // Card lookup
    const card = savedCardId ? await SavedCard.findById(savedCardId) : null;

    // Demo failure conditions
    const buildFailureMeta = (failureReason) => ({
      demoCard: card ? { savedCardId: card._id, last4: card.last4, cardType: card.cardType, expiry: card.expiry, label: card.label } : undefined,
      failureReason,
    });

    if (!savedCardId || !card) {
      await this._upsertFailedPayment(booking, existing, buildFailureMeta('invalid_card'), customerId);
      throw new ApiError(StatusCodes.UNPROCESSABLE_ENTITY, 'Saved card not found.');
    }
    if (card.userId.toString() !== customerId.toString()) {
      await this._upsertFailedPayment(booking, existing, buildFailureMeta('invalid_card'), customerId);
      throw new ApiError(StatusCodes.FORBIDDEN, 'Card does not belong to you.');
    }
    if (card.last4 === '0000') {
      await this._upsertFailedPayment(booking, existing, buildFailureMeta('demo_decline'), customerId);
      throw new ApiError(StatusCodes.PAYMENT_REQUIRED, 'Card was declined (demo).');
    }

    // Credit pre-apply (Plan 3 Task 10)
    let creditApplied = 0;
    if (useCredit) {
      const customerCreditSvc = require('./customer-credit.service');
      const available = await customerCreditSvc.balance(customerId);
      creditApplied = Math.min(available, booking.estimatedTotal);
    }
    const gatewayChargeAmount = Math.max(0, booking.estimatedTotal - creditApplied);

    // Success path — call gateway first (for remaining amount)
    const gateway = getGateway();
    const authz = gatewayChargeAmount > 0
      ? await gateway.authorize({
          amount: gatewayChargeAmount,
          currency: 'EGP',
          customerId,
          savedCardId: card._id,
          metadata: { bookingId },
        })
      : { intentId: `credit_only_${Date.now()}` };

    const demoCard = { savedCardId: card._id, last4: card.last4, cardType: card.cardType, expiry: card.expiry, label: card.label };
    const paymentData = {
      booking: bookingId,
      user: customerId,
      worker: booking.worker,
      amount: booking.estimatedTotal,
      platformFee: booking.platformFeeAmount,
      workerEarning: booking.totalPrice,
      gateway: 'demo',
      gatewayId: gateway.id,
      gatewayIntentId: authz.intentId,
      heldAt: new Date(),
      status: 'held',
      paymentMethod: 'online',
      skipFeeCalc: true,
      creditApplied,
      gatewayChargeAmount,
      metadata: { demoCard },
    };

    const session = await mongoose.startSession();
    let savedPayment;

    try {
      await session.withTransaction(async () => {
        if (existing && existing.status === 'failed') {
          Object.assign(existing, paymentData);
          savedPayment = await existing.save({ session });
        } else {
          try {
            [savedPayment] = await Payment.create([paymentData], { session });
          } catch (err) {
            if (err.code === 11000) {
              throw new ApiError(StatusCodes.CONFLICT, 'Payment already exists for this booking.');
            }
            throw err;
          }
        }

        if (creditApplied > 0) {
          const customerCreditSvc = require('./customer-credit.service');
          await customerCreditSvc.consume(customerId, creditApplied, { booking: bookingId, session });
          await logTransaction({
            payment: savedPayment._id,
            type: 'credit_apply',
            amount: creditApplied,
            currency: 'egp',
            direction: 'debit',
            actor: customerId,
            note: `Customer credit applied to booking ${bookingId}`,
          }, session);
        }

        booking.paymentMeta = demoCard;
        booking.paymentStatus = 'held';
        await booking.save({ session });

        const wallet = await getOrCreateWallet(booking.worker, session);
        await wallet.addPending(savedPayment.workerEarning);

        await logTransaction({
          payment: savedPayment._id,
          wallet: wallet._id,
          type: 'hold',
          amount: savedPayment.amount,
          currency: savedPayment.currency,
          direction: 'debit',
          actor: customerId,
          note: `Escrow hold for booking #${String(bookingId).slice(-6)}`,
        }, session);
      });
    } finally {
      await session.endSession();
    }

    notify.safeDispatch('payment.held', {
      customer: customerId,
      amount: savedPayment.amount,
      currency: savedPayment.currency,
      bookingId,
    });

    return savedPayment;
  }

  async _upsertFailedPayment(booking, existing, metadata, customerId) {
    const failData = {
      status: 'failed',
      metadata,
    };
    if (existing && existing.status === 'failed') {
      Object.assign(existing, failData);
      await existing.save();
    } else if (!existing) {
      await Payment.create({
        booking: booking._id,
        user: customerId,
        worker: booking.worker,
        amount: booking.estimatedTotal,
        platformFee: booking.platformFeeAmount,
        workerEarning: booking.totalPrice,
        gateway: 'demo',
        paymentMethod: 'online',
        skipFeeCalc: true,
        ...failData,
      });
    }
    await Booking.findByIdAndUpdate(booking._id, { paymentStatus: 'failed' }, { runValidators: false });
  }

  async requestReleaseByCustomer(bookingId, customerId) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== customerId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }
    if (booking.status !== 'awaiting_customer_confirmation') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot confirm completion for booking with status '${booking.status}'.`
      );
    }

    booking.customerConfirmedAt = new Date();
    booking.customerConfirmedBy = customerId;
    booking.status = 'pending_admin_review';

    if (booking.paymentMethod === 'online') {
      const payment = await Payment.findOne({ booking: bookingId });
      if (!payment || payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
      }
      payment.releaseRequestedAt = new Date();
      payment.releaseRequestedBy = customerId;
      await payment.save();
    }

    await booking.save();
    events.emitPaymentPendingReview({ booking });
    return booking;
  }

  async adminApproveCompletion(bookingId, adminId) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.status !== 'pending_admin_review') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Booking must be in 'pending_admin_review' status. Current: '${booking.status}'.`
      );
    }

    const session = await mongoose.startSession();
    let result;

    await session.withTransaction(async () => {
      if (booking.paymentMethod === 'online') {
        const payment = await Payment.findOne({ booking: bookingId }).session(session);
        if (!payment || payment.status !== 'held') {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
        }
        await this.releaseHeldPayment(payment, booking, adminId, session);
        booking.paymentStatus = 'released';
      } else {
        const CashDebt = require('./cash-debt.model');
        await CashDebt.create([{
          worker: booking.worker,
          booking: booking._id,
          amount: booking.platformFeeAmount,
        }], { session });

        booking.paymentStatus = 'cash_pending_settlement';
      }

      booking.status = 'completed';
      await booking.save({ session });
      result = booking;
    });

    await session.endSession();

    // Generate receipt PDF outside transaction (Plan 3 Task 14)
    if (booking._pendingInvoiceId) {
      const Invoice = require('./invoice.model');
      const receiptSvc = require('./receipt.service');
      Invoice.findById(booking._pendingInvoiceId)
        .then(inv => inv && receiptSvc.generate(inv))
        .catch(() => {});
    }

    // Check thresholds outside transaction (non-critical)
    if (booking.paymentMethod === 'cash') {
      getCashDebtSvc().checkDebtThresholds(booking.worker).catch(() => {});
    }

    return result;
  }

  async releaseHeldPayment(payment, booking, adminId, session) {
    if (payment.lockedAt) {
      throw new ApiError(StatusCodes.CONFLICT, 'Payment is locked by admin.');
    }
    const workerId = payment.worker || booking.worker;

    const { remainingAmount } = await getCashDebtSvc().settleCashDebtsFromAmount(
      workerId,
      payment.workerEarning,
      session
    );

    const wallet = await getOrCreateWallet(workerId, session);
    await wallet.deductPending(payment.workerEarning);
    await wallet.credit(remainingAmount);

    if (payment.gatewayIntentId) {
      const gw = getGateway();
      const capture = await gw.capture({ intentId: payment.gatewayIntentId });
      payment.gatewayChargeId = capture.chargeId;
      payment.capturedAt = new Date();
    }
    payment.status = 'released';
    payment.releasedAt = new Date();
    payment.releaseApprovedAt = new Date();
    payment.releaseApprovedBy = adminId;
    await payment.save({ session });

    // Auto-issue invoice inside txn (Plan 3 Task 14)
    let invoiceId = null;
    try {
      const invoiceSvc = require('./invoice.service');
      const cfg = await getAdminSettingsSvc().get();
      const VAT_RATE = cfg?.vat?.rate ?? 0.14;
      const subtotal = roundMoney(payment.amount / (1 + VAT_RATE));
      const inv = await invoiceSvc.create({
        payment: payment._id,
        booking: payment.booking,
        customer: payment.user,
        worker: workerId,
        subtotal,
        vatRate: VAT_RATE,
        currency: (payment.currency || 'egp').toUpperCase(),
        session,
      });
      invoiceId = inv?._id;
    } catch (e) { /* non-fatal */ }
    if (invoiceId) booking._pendingInvoiceId = invoiceId;

    await adminAction.record({
      adminId,
      actionType: 'payment_release',
      targetType: 'payment',
      targetId: payment._id,
      details: { amount: payment.amount, bookingId: booking._id },
      session,
    });

    events.emitPaymentReleased({ payment, booking });

    notify.safeDispatch('payment.released', {
      worker: workerId,
      customer: payment.user,
      amount: remainingAmount,
      currency: payment.currency,
      bookingId: booking._id,
    });

    await logTransaction({
      payment: payment._id,
      wallet: wallet._id,
      type: 'release',
      amount: remainingAmount,
      currency: payment.currency,
      direction: 'credit',
      actor: adminId,
      note: `Escrow released to worker for booking ${payment.booking} (gross ${payment.workerEarning}, after debt offset ${remainingAmount})`,
    }, session);

    await logTransaction({
      payment: payment._id,
      type: 'fee',
      amount: payment.platformFee,
      currency: payment.currency,
      direction: 'credit',
      actor: adminId,
      note: `Platform fee for booking ${payment.booking}`,
    }, session);
  }

  async adminRejectCash(bookingId, adminId, reason) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.paymentMethod !== 'cash') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'This endpoint is for cash bookings only.');
    }

    const Dispute = require('./dispute.model');
    booking.status = 'disputed';
    await booking.save();

    const dispute = await Dispute.create({
      booking: bookingId,
      raisedBy: adminId,
      raisedByRole: 'admin',
      reason: reason || 'Rejected by admin',
    });

    return { booking, dispute };
  }

  async refundPayment(paymentId, adminId, reason) {
    const payment = await Payment.findById(paymentId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');
    if (payment.lockedAt) {
      throw new ApiError(StatusCodes.CONFLICT, 'Payment is locked by admin.');
    }

    const booking = await Booking.findById(payment.booking);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');

    if (!['pending_admin_review', 'disputed'].includes(booking.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot refund: booking status must be 'pending_admin_review' or 'disputed'. Current: '${booking.status}'.`
      );
    }
    if (!['held', 'disputed'].includes(payment.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot refund payment with status '${payment.status}'.`
      );
    }

    const session = await mongoose.startSession();
    let updatedPayment;

    await session.withTransaction(async () => {
      const wallet = await getOrCreateWallet(payment.worker, session);
      await wallet.deductPending(payment.workerEarning);

      if (payment.gatewayChargeId) {
        const gw = getGateway();
        const refund = await gw.refund({
          chargeId: payment.gatewayChargeId,
          amount: payment.amount,
          reason: reason || 'admin_refund',
        });
        payment.gatewayRefundId = refund.refundId;
      }
      payment.status = 'refunded';
      payment.refundedAt = new Date();
      updatedPayment = await payment.save({ session });

      await Booking.findByIdAndUpdate(
        payment.booking,
        { status: 'cancelled', paymentStatus: 'refunded' },
        { session }
      );

      await logTransaction({
        payment: payment._id,
        wallet: wallet._id,
        type: 'refund',
        amount: payment.amount,
        currency: payment.currency,
        direction: 'credit',
        actor: adminId,
        note: reason || `Admin refund by ${adminId}`,
      }, session);
    });

    await session.endSession();

    notify.safeDispatch('payment.refunded', {
      customer: updatedPayment.user,
      amount: updatedPayment.amount,
      currency: updatedPayment.currency,
      bookingId: updatedPayment.booking,
      reason,
    });

    return updatedPayment;
  }

  async getPendingApprovals({ paymentMethod, page = 1, limit = 20 } = {}) {
    const filter = { status: 'pending_admin_review' };
    if (paymentMethod) filter.paymentMethod = paymentMethod;

    const skip = (Number(page) - 1) * Number(limit);
    const [bookings, total] = await Promise.all([
      Booking.find(filter)
        .populate('user', 'name')
        .populate('worker', 'name')
        .populate('service', 'title')
        .sort({ customerConfirmedAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Booking.countDocuments(filter),
    ]);

    const bookingIds = bookings.map(b => b._id);
    const payments = await Payment.find({ booking: { $in: bookingIds } });
    const paymentMap = {};
    payments.forEach(p => { paymentMap[p.booking.toString()] = p; });

    const items = bookings.map(b => {
      const p = paymentMap[b._id.toString()];
      return {
        bookingId:           b._id,
        paymentId:           p?._id || null,
        customer:            { id: b.user?._id, name: b.user?.name },
        worker:              { id: b.worker?._id, name: b.worker?.name },
        service:             b.service?.title || b.serviceCategory,
        amount:              b.totalPrice,
        paymentMethod:       b.paymentMethod,
        workerEarning:       p?.workerEarning ?? null,
        platformFee:         p?.platformFee ?? null,
        totalPaid:           p?.amount || 0,
        customerConfirmedAt: b.customerConfirmedAt,
        paymentStatus:       b.paymentStatus,
      };
    });

    return {
      items,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async getPaymentByBooking(bookingId, requesterId, requesterRole) {
    const payment = await Payment.findByBooking(bookingId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');
    if (requesterRole === 'user' && payment.user._id.toString() !== requesterId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You cannot view this payment.');
    }
    if (requesterRole === 'worker' && payment.worker._id.toString() !== requesterId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You cannot view this payment.');
    }
    return payment;
  }

  async getWorkerEarnings(workerId, filters = {}) {
    const wallet = await getOrCreateWallet(workerId);
    const User = require('../users/user.model');
    const worker = await User.findById(workerId).select('completedJobs');

    const query = {
      worker: workerId,
      status: { $in: ['held', 'released'] },
    };


    if (filters.dateFrom || filters.dateTo) {
      query.createdAt = {};
      if (filters.dateFrom) query.createdAt.$gte = new Date(filters.dateFrom);
      if (filters.dateTo) query.createdAt.$lte = new Date(filters.dateTo);
    }
    if (filters.status) query.status = filters.status;
    const payments = await Payment.find(query)
      .populate('booking', 'scheduledDate address')
      .sort({ createdAt: -1 });
    const summary = payments.reduce(
      (acc, p) => {
        if (p.status === 'held') acc.totalHeld += p.workerEarning;
        if (p.status === 'released') acc.totalReleased += p.workerEarning;
        return acc;
      },
      { totalHeld: 0, totalReleased: 0 }
    );

    return {
      wallet,
      payments,
      summary,
      completedJobs: worker ? worker.completedJobs : 0
    };
  }

  async updateWorkerPayoutSettings(workerId, payload = {}) {
    const wallet = await getOrCreateWallet(workerId);

    if (payload.payoutMethod) wallet.payoutMethod = payload.payoutMethod;
    if (payload.payoutSchedule) wallet.payoutSchedule = payload.payoutSchedule;

    if (payload.payoutDetails) {
      wallet.payoutDetails = {
        ...wallet.payoutDetails,
        ...payload.payoutDetails,
      };
    }

    await wallet.save();
    return wallet;
  }
}

const { money: roundMoney } = require('../../utils/rounding');

const REFUND_WINDOW_DAYS = 90;

PaymentService.prototype.refundWithFallback = async function ({ paymentId, amount, reason, actor, session, evidence }) {
  const CustomerCredit = require('./customer-credit.model');
  const ownSession = !session;
  if (ownSession) session = await mongoose.startSession();
  try {
    const doRefund = async () => {
      const payment = await Payment.findById(paymentId).session(session);
      if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found');
      if (payment.lockedAt) {
        throw new ApiError(StatusCodes.CONFLICT, 'Payment is locked by admin.');
      }
      const available = payment.amount - (payment.refundedAmount || 0);
      if (amount > available) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund exceeds available amount');
      }

      const capturedAt = payment.capturedAt || payment.releasedAt || payment.heldAt || payment.createdAt;
      const ageDays = (Date.now() - new Date(capturedAt).getTime()) / 86400000;

      let destination = 'gateway';
      try {
        if (ageDays > REFUND_WINDOW_DAYS) throw new Error('refund_window_expired');
        if (payment.gatewayChargeId) {
          const gw = getGateway();
          const ref = await gw.refund({
            chargeId: payment.gatewayChargeId,
            amount,
            reason: reason || 'refund',
          });
          payment.gatewayRefundId = ref?.refundId;
        }
      } catch (e) {
        destination = 'wallet_credit';
        await CustomerCredit.create([{
          customer: payment.user,
          amount,
          source: 'refund_fallback',
          relatedPayment: payment._id,
          reason: reason || 'gateway refund unavailable',
          issuedBy: actor,
        }], { session });
      }

      payment.refundedAmount = roundMoney((payment.refundedAmount || 0) + amount);
      payment.status = payment.refundedAmount >= payment.amount ? 'refunded' : 'partially_refunded';
      payment.refundedAt = new Date();
      await payment.save({ session });

      await logTransaction({
        payment: payment._id,
        type: 'refund',
        amount,
        currency: payment.currency || 'egp',
        direction: 'credit',
        actor,
        note: `Refund (${destination}) — ${reason || 'n/a'}`,
      }, session);

      return { destination, amount };
    };

    return ownSession ? await session.withTransaction(doRefund) : await doRefund();
  } finally { if (ownSession) await session.endSession(); }
};

PaymentService.prototype.partialRefund = async function ({ bookingId, adminId, refundAmount, deductFrom, reason, ipAddress }) {
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const payment = await Payment.findOne({ booking: bookingId }).session(session);
      if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found');
      if (!['held', 'released'].includes(payment.status)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot refund status=${payment.status}`);
      }
      if (refundAmount > payment.amount) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund > payment amount');
      }

      const booking = await Booking.findById(bookingId).session(session);
      const techShare = payment.workerEarning;
      const platformShare = payment.platformFee;
      let fromTech = 0, fromPlatform = 0;
      switch (deductFrom) {
        case 'tech':         fromTech = refundAmount; break;
        case 'platform':     fromPlatform = refundAmount; break;
        case 'proportional': {
          const ratio = refundAmount / payment.amount;
          fromTech = roundMoney(techShare * ratio);
          fromPlatform = roundMoney(platformShare * ratio);
          break;
        }
        default: throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid deductFrom');
      }

      if (payment.gatewayChargeId) {
        const gateway = getGateway();
        const refund = await gateway.refund({
          chargeId: payment.gatewayChargeId,
          amount: refundAmount,
          reason,
        });
        payment.gatewayRefundId = refund.refundId;
      }

      payment.status = 'partially_refunded';
      payment.refundedAt = new Date();
      await payment.save({ session });

      const wallet = await Wallet.findOne({ worker: booking.worker }).session(session);
      if (wallet && fromTech > 0) {
        if (payment.releasedAt) wallet.balance = roundMoney((wallet.balance || 0) - fromTech);
        else wallet.pendingBalance = roundMoney((wallet.pendingBalance || 0) - fromTech);
        await wallet.save({ session });
      }

      await adminAction.record({
        adminId, actionType: 'payment_partial_refund',
        targetType: 'payment', targetId: payment._id,
        details: { refundAmount, fromTech, fromPlatform, reason },
        ipAddress, session,
      });
      return { payment, splits: { fromTech, fromPlatform } };
    });
  } finally {
    await session.endSession();
  }
};

PaymentService.prototype.forceRelease = async function (paymentId, { actor, reason, ipAddress } = {}) {
  if (!reason || reason.trim().length < 10) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Reason required (min 10 chars).');
  }
  const session = await mongoose.startSession();
  try {
    let result;
    await session.withTransaction(async () => {
      const payment = await Payment.findById(paymentId).session(session);
      if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');
      if (payment.lockedAt) {
        throw new ApiError(StatusCodes.CONFLICT, 'Payment is locked by admin.');
      }
      if (payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Only held payments can be force-released (current: ${payment.status}).`);
      }
      const booking = await Booking.findById(payment.booking).session(session);
      if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');

      await this.releaseHeldPayment(payment, booking, actor, session);
      if (booking.status !== 'completed') {
        booking.status = 'completed';
        booking.paymentStatus = 'released';
        await booking.save({ session });
      }

      await adminAction.record({
        adminId: actor,
        actionType: 'emergency_release',
        targetType: 'payment',
        targetId: payment._id,
        details: { reason, amount: payment.amount, bookingId: booking._id },
        ipAddress,
        session,
      });

      result = payment;
    });
    return result;
  } finally { await session.endSession(); }
};

PaymentService.prototype.forceLock = async function (paymentId, { actor, reason, ipAddress } = {}) {
  if (!reason || reason.trim().length < 10) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Reason required (min 10 chars).');
  }
  const payment = await Payment.findOneAndUpdate(
    { _id: paymentId, lockedAt: null },
    { $set: { lockedAt: new Date(), lockReason: reason, lockedBy: actor } },
    { new: true }
  );
  if (!payment) {
    const exists = await Payment.findById(paymentId);
    if (!exists) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');
    throw new ApiError(StatusCodes.CONFLICT, 'Payment already locked.');
  }
  await adminAction.record({
    adminId: actor,
    actionType: 'emergency_lock',
    targetType: 'payment',
    targetId: payment._id,
    details: { reason },
    ipAddress,
  });
  return payment;
};

PaymentService.prototype.forceUnlock = async function (paymentId, { actor, reason, ipAddress } = {}) {
  if (!reason || reason.trim().length < 5) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Reason required (min 5 chars).');
  }
  const payment = await Payment.findById(paymentId);
  if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');
  if (!payment.lockedAt) throw new ApiError(StatusCodes.BAD_REQUEST, 'Payment is not locked.');
  payment.lockedAt = undefined;
  payment.lockReason = undefined;
  payment.lockedBy = undefined;
  await payment.save();
  await adminAction.record({
    adminId: actor,
    actionType: 'emergency_unlock',
    targetType: 'payment',
    targetId: payment._id,
    details: { reason },
    ipAddress,
  });
  return payment;
};

module.exports = new PaymentService();
