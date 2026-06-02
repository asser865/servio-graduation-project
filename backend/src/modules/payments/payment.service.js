const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const Booking    = require('../bookings/booking.model');
const Payment    = require('./payment.model');
const SavedCard  = require('../savedCards/savedCard.model');
const Wallet     = require('./wallet.model');
const CashDebt   = require('./cash-debt.model');
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

const PAYMENT_PENDING_STATUSES = ['held', 'disputed'];
const INACTIVE_BOOKING_STATUSES = ['cancelled', 'rejected', 're_pooling'];

function isMoneyDateInRange(date, { dateFrom, dateTo } = {}) {
  if (!date) return false;
  const value = new Date(date);
  if (Number.isNaN(value.getTime())) return false;
  if (dateFrom) {
    const from = new Date(dateFrom);
    if (!Number.isNaN(from.getTime()) && value < from) return false;
  }
  if (dateTo) {
    const to = new Date(dateTo);
    if (!Number.isNaN(to.getTime()) && value > to) return false;
  }
  return true;
}

function bookingTakeHomeSnapshot(booking) {
  const gross = roundMoney(booking?.totalPrice || 0);
  const fee = roundMoney(booking?.platformFeeAmount || 0);
  return {
    gross,
    fee,
    net: roundMoney(gross - fee),
  };
}

function bookingMoneyDate(booking) {
  return booking?.actualCompletedAt || booking?.updatedAt || booking?.scheduledDate || booking?.createdAt || null;
}

function startOfDay(date) {
  const value = new Date(date);
  value.setHours(0, 0, 0, 0);
  return value;
}

function formatShortBookingId(value) {
  return String(value || '').slice(-6).toUpperCase();
}

function validPendingBooking(booking) {
  if (!booking) return false;
  if (INACTIVE_BOOKING_STATUSES.includes(booking.status)) return false;
  return !['released', 'refunded', 'cash_pending_settlement', 'cash_settled', 'not_required'].includes(booking.paymentStatus);
}

function assertAdminApprovalBookingEligible(booking) {
  if (booking.status !== 'pending_admin_review') {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Booking must be in 'pending_admin_review' status. Current: '${booking.status}'.`
    );
  }
  if (booking.paymentMethod === 'cash') {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      'Manual cash approval is disabled. Cash platform fees are created automatically after a clean customer confirmation.'
    );
  }
  if (['card', 'online'].includes(booking.paymentMethod)) {
    if (!(booking.completionOutcome?.afterPhotos?.length > 0)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        'Missing completion evidence. At least one after photo is required before releasing card funds.'
      );
    }
    if (booking.customerFeedback?.action === 'reported_issue') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        'Cannot release card funds while a customer-reported issue is open.'
      );
    }
  }
}

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
    if (!['pending', 'accepted'].includes(booking.status)) {
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

    if (['card', 'online'].includes(booking.paymentMethod)) {
      const payment = await Payment.findOne({ booking: bookingId });
      if (!payment || payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
      }
      payment.releaseRequestedAt = new Date();
      payment.releaseRequestedBy = customerId;
      await payment.save();
    }

    await booking.save();
    if (booking.paymentMethod === 'cash') {
      const result = await require('./auto-fee-debt.service').createIfClean(booking._id);
      return result.booking || booking;
    }
    events.emitPaymentPendingReview({ booking });
    return booking;
  }

  async adminApproveCompletion(bookingId, adminId, { reasonCode = 'customer_confirmed', note = '' } = {}) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    assertAdminApprovalBookingEligible(booking);

    const session = await mongoose.startSession();
    let result;
    let pendingInvoiceId = null;

    try {
      await session.withTransaction(async () => {
        if (['card', 'online'].includes(booking.paymentMethod)) {
          const payment = await Payment.findOne({ booking: bookingId }).session(session);
          if (!payment || payment.status !== 'held') {
            throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
          }
          const release = await this.releaseHeldPayment(payment, booking, adminId, session, { reasonCode, note });
          pendingInvoiceId = release.invoiceId;
          booking.paymentStatus = 'released';
        }

        booking.status = 'completed';
        await booking.save({ session });
        result = booking;
      });
    } finally {
      await session.endSession();
    }

    // Generate receipt PDF outside transaction (Plan 3 Task 14)
    if (pendingInvoiceId) {
      const Invoice = require('./invoice.model');
      const receiptSvc = require('./receipt.service');
      try {
        const invoice = await Invoice.findById(pendingInvoiceId);
        if (invoice) await receiptSvc.generate(invoice);
      } catch (_) { /* receipt can be generated lazily by the download endpoint */ }
    }

    return result;
  }

  async validateAdminApproveCompletion(bookingOrId) {
    const booking = typeof bookingOrId === 'object' && bookingOrId?._id
      ? bookingOrId
      : await Booking.findById(bookingOrId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    assertAdminApprovalBookingEligible(booking);
    if (['card', 'online'].includes(booking.paymentMethod)) {
      const payment = await Payment.findOne({ booking: booking._id });
      if (!payment || payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
      }
    }
    return booking;
  }

  async releaseHeldPayment(payment, booking, adminId, session, { reasonCode = 'customer_confirmed', note = '' } = {}) {
    if (payment.lockedAt) {
      throw new ApiError(StatusCodes.CONFLICT, 'Payment is locked by admin.');
    }
    const workerId = payment.worker || booking.worker;

    const { remainingAmount } = await getCashDebtSvc().settleCashDebtsFromAmount(
      workerId,
      payment.workerEarning,
      session
    );

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
    if (booking.paymentStatus !== 'released') {
      booking.paymentStatus = 'released';
      await booking.save({ session });
    }

    const { wallet } = await this.reconcileWorkerWalletState(workerId, session);
    await wallet.credit(remainingAmount);

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
    await adminAction.record({
      adminId,
      actionType: 'payment_release',
      targetType: 'payment',
      targetId: payment._id,
      details: { amount: payment.amount, bookingId: booking._id, reasonCode, note },
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

    return { invoiceId };
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

      const { wallet } = await this.reconcileWorkerWalletState(payment.worker, session);

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
    const filter = {
      status: 'pending_admin_review',
      paymentMethod: { $ne: 'cash' },
    };
    if (paymentMethod) {
      filter.paymentMethod = paymentMethod === 'cash' ? { $in: [] } : paymentMethod;
    }

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
        workerEarning:       p?.workerEarning ?? (b.totalPrice != null && b.platformFeeAmount != null ? b.totalPrice - b.platformFeeAmount : null),
        platformFee:         p?.platformFee ?? b.platformFeeAmount ?? null,
        totalPaid:           p?.amount ?? b.totalPrice ?? 0,
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

  async getAdminPaymentDetail(paymentId) {
    const payment = await Payment.findById(paymentId)
      .populate('user', 'name email phone')
      .populate('worker', 'name email phone')
      .populate({
        path: 'booking',
        populate: [
          { path: 'user', select: 'name email phone' },
          { path: 'worker', select: 'name email phone' },
          { path: 'service', select: 'title category basePrice' },
        ],
      });

    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');

    const booking = payment.booking && typeof payment.booking === 'object' ? payment.booking : null;
    const Dispute = require('./dispute.model');
    const SupportIssue = require('../support/support-issue.model');
    const AdminAction = require('../admin/admin-action.model');

    const activeDisputeStatuses = ['open', 'reviewing', 'awaiting_evidence', 'appealed', 'escalated'];
    const activeSupportStatuses = ['open', 'reviewing', 'waiting_customer', 'waiting_worker'];
    const [disputes, supportIssues, auditTrail] = await Promise.all([
      booking ? Dispute.find({ booking: booking._id, status: { $in: activeDisputeStatuses } }).sort({ createdAt: -1 }).limit(10) : [],
      booking ? SupportIssue.find({ booking: booking._id, status: { $in: activeSupportStatuses } }).sort({ createdAt: -1 }).limit(10) : [],
      AdminAction.find({ targetType: 'payment', targetId: payment._id }).sort({ createdAt: -1 }).limit(20),
    ]);

    const amount = roundMoney(payment.amount || 0);
    const workerEarning = roundMoney(payment.workerEarning || 0);
    const platformFee = roundMoney(payment.platformFee || 0);
    const refundedAmount = roundMoney(payment.refundedAmount || 0);
    const remainingRefundable = Math.max(0, roundMoney(amount - refundedAmount));
    const releaseWindowHours = Number(process.env.ESCROW_RELEASE_WINDOW_HOURS || 48);
    const highRiskThreshold = Number(process.env.ESCROW_HIGH_RISK_AMOUNT || 2000);
    const customerConfirmedAt = booking?.customerConfirmedAt || null;
    const releaseEligibleAt = customerConfirmedAt
      ? new Date(new Date(customerConfirmedAt).getTime() + releaseWindowHours * 3600000)
      : null;

    const missingEvidence = [];
    if (!booking?.actualCompletedAt) missingEvidence.push('worker_completion_timestamp');
    if (!booking?.customerConfirmedAt) missingEvidence.push('customer_confirmation');
    if (
      ['card', 'online'].includes(booking?.paymentMethod)
      && !(booking?.completionOutcome?.afterPhotos?.length > 0)
    ) {
      missingEvidence.push('worker_completion_after_photo');
    }

    const hasOpenDispute = disputes.length > 0;
    const hasOpenSupportIssue = supportIssues.length > 0;
    const hasReportedIssue = booking?.customerFeedback?.action === 'reported_issue';
    const isLocked = Boolean(payment.lockedAt);
    const isHighValue = amount >= highRiskThreshold;
    const isFlagged = Boolean(booking?.flaggedForReview);

    const policyFlags = [];
    if (isLocked) policyFlags.push('payment_locked');
    if (hasOpenDispute) policyFlags.push('active_dispute');
    if (hasOpenSupportIssue) policyFlags.push('active_support_issue');
    if (hasReportedIssue) policyFlags.push('customer_reported_issue');
    if (isHighValue) policyFlags.push('high_value_payment');
    if (isFlagged) policyFlags.push('booking_flagged_for_review');
    if (missingEvidence.length) policyFlags.push('missing_required_evidence');

    const allowedActions = new Set();
    if (['held', 'released'].includes(payment.status)) {
      allowedActions.add('partial_refund');
      allowedActions.add('full_refund');
    }
    if (payment.status === 'held' && !isLocked) {
      allowedActions.add('request_evidence');
      allowedActions.add('lock');
      allowedActions.add('emergency_release');
      if (
        booking?.status === 'pending_admin_review'
        && !hasOpenDispute
        && !hasOpenSupportIssue
        && !hasReportedIssue
        && !missingEvidence.length
      ) {
        allowedActions.add('release');
      }
    }
    if (isLocked) allowedActions.add('unlock');
    if (hasOpenDispute || hasOpenSupportIssue || isHighValue || isFlagged) allowedActions.add('escalate');

    let recommendedAction = 'release';
    if (isLocked || hasOpenDispute || hasOpenSupportIssue || hasReportedIssue) recommendedAction = 'escalate';
    else if (missingEvidence.length) recommendedAction = 'request_evidence';
    else if (isHighValue || isFlagged) recommendedAction = 'manual_review';

    const riskLevel = isLocked || hasOpenDispute || isFlagged ? 'high'
      : hasOpenSupportIssue || isHighValue || missingEvidence.length ? 'medium'
      : 'low';

    const autoReleaseEligible = recommendedAction === 'release'
      && releaseEligibleAt
      && releaseEligibleAt.getTime() <= Date.now()
      && !isHighValue;

    return {
      payment: {
        id: payment._id,
        status: payment.status,
        currency: payment.currency,
        lockedAt: payment.lockedAt,
        lockReason: payment.lockReason,
        createdAt: payment.createdAt,
        heldAt: payment.heldAt,
        releasedAt: payment.releasedAt,
        refundedAt: payment.refundedAt,
      },
      booking: booking ? {
        id: booking._id,
        status: booking.status,
        paymentStatus: booking.paymentStatus,
        service: booking.service?.title || booking.serviceName || booking.serviceCategory,
        scheduledDate: booking.scheduledDate,
        address: booking.address,
        workerNotes: booking.workerNotes || '',
        workerCompletionImages: booking.workerCompletionImages || [],
        completionOutcome: booking.completionOutcome || {},
        customerFeedback: booking.customerFeedback || {},
        flaggedForReview: booking.flaggedForReview,
        flagReason: booking.flagReason || '',
      } : null,
      parties: {
        customer: payment.user || booking?.user || null,
        worker: payment.worker || booking?.worker || null,
      },
      paymentBreakdown: {
        amount,
        workerEarning,
        platformFee,
        refundedAmount,
        remainingRefundable,
      },
      timeline: {
        bookedAt: booking?.createdAt || null,
        paidAt: payment.heldAt || payment.createdAt,
        workerStartedAt: booking?.actualStartedAt || null,
        completedAt: booking?.actualCompletedAt || booking?.completedAt || null,
        customerConfirmedAt,
        reviewStartedAt: payment.releaseRequestedAt || customerConfirmedAt,
        releaseEligibleAt,
      },
      evidence: {
        workerNotes: booking?.workerNotes || '',
        workerCompletionImages: booking?.workerCompletionImages || [],
        completionAfterPhotos: booking?.completionOutcome?.afterPhotos || [],
        customerFeedback: booking?.customerFeedback || {},
        bookingImages: booking?.images || [],
        disputes: disputes.map(d => ({
          id: d._id,
          status: d.status,
          category: d.category,
          severity: d.severity,
          reason: d.reason,
          evidenceCount: Array.isArray(d.evidence) ? d.evidence.length : 0,
          createdAt: d.createdAt,
        })),
        supportIssues: supportIssues.map(issue => ({
          id: issue._id,
          type: issue.type,
          status: issue.status,
          priority: issue.priority,
          description: issue.description,
          evidenceCount: Array.isArray(issue.evidence) ? issue.evidence.length : 0,
          createdAt: issue.createdAt,
        })),
      },
      decisionPacket: {
        recommendedAction,
        allowedActions: Array.from(allowedActions),
        policyFlags,
        missingEvidence,
        riskLevel,
        autoReleaseEligible,
        releaseWindowHours,
      },
      auditTrail: auditTrail.map(action => ({
        id: action._id,
        actionType: action.actionType,
        details: action.details || {},
        admin: action.admin,
        createdAt: action.createdAt,
      })),
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

  async reconcileWorkerWalletState(workerId, session) {
    const wallet = await getOrCreateWallet(workerId, session);
    const candidatePayments = await Payment.find({
      worker: workerId,
      status: { $in: [...PAYMENT_PENDING_STATUSES, 'partially_refunded'] },
    })
      .populate('booking', 'status paymentStatus updatedAt cancelledAt')
      .session(session || null);

    const releaseTransactions = candidatePayments.length
      ? await Transaction.find({
        payment: { $in: candidatePayments.map((payment) => payment._id) },
        type: 'release',
      })
        .sort({ createdAt: 1 })
        .session(session || null)
      : [];

    const releaseTxByPayment = new Map();
    for (const tx of releaseTransactions) {
      const key = String(tx.payment || '');
      if (key && !releaseTxByPayment.has(key)) releaseTxByPayment.set(key, tx);
    }

    let normalizedPayments = 0;
    for (const payment of candidatePayments) {
      const booking = payment.booking;
      const releaseTx = releaseTxByPayment.get(String(payment._id));
      const shouldBeReleased = PAYMENT_PENDING_STATUSES.includes(payment.status)
        && (releaseTx || booking?.paymentStatus === 'released');
      const shouldBeRefunded = PAYMENT_PENDING_STATUSES.includes(payment.status)
        && !shouldBeReleased
        && (booking?.paymentStatus === 'refunded' || INACTIVE_BOOKING_STATUSES.includes(booking?.status));

      if (!shouldBeReleased && !shouldBeRefunded) continue;

      if (shouldBeReleased) {
        const releasedAt = releaseTx?.createdAt || booking?.updatedAt || new Date();
        payment.status = 'released';
        if (!payment.releasedAt) payment.releasedAt = releasedAt;
        if (!payment.releaseApprovedAt) payment.releaseApprovedAt = releasedAt;
      } else {
        payment.status = 'refunded';
        if (!payment.refundedAt) payment.refundedAt = booking?.cancelledAt || booking?.updatedAt || new Date();
      }

      await payment.save({ session });
      normalizedPayments += 1;
    }

    const hasPartialPending = candidatePayments.some(
      (payment) => payment.status === 'partially_refunded' && !payment.releasedAt && validPendingBooking(payment.booking)
    );

    if (hasPartialPending) {
      return {
        wallet,
        expectedPendingBalance: roundMoney(wallet.pendingBalance || 0),
        skippedPendingReconcile: true,
        normalizedPayments,
      };
    }

    const activePendingPayments = await Payment.find({
      worker: workerId,
      status: { $in: PAYMENT_PENDING_STATUSES },
    })
      .populate('booking', 'status paymentStatus')
      .session(session || null);

    const expectedPendingBalance = roundMoney(activePendingPayments.reduce((sum, payment) => {
      if (!validPendingBooking(payment.booking)) return sum;
      return sum + roundMoney(payment.workerEarning || 0);
    }, 0));

    if (roundMoney(wallet.pendingBalance || 0) !== expectedPendingBalance) {
      wallet.pendingBalance = expectedPendingBalance;
      await wallet.save({ session });
    }

    return {
      wallet,
      expectedPendingBalance,
      skippedPendingReconcile: false,
      normalizedPayments,
    };
  }

  async getWorkerEarnings(workerId, filters = {}) {
    await this.reconcileWorkerWalletState(workerId);

    const wallet = await getOrCreateWallet(workerId);
    const User = require('../users/user.model');
    const worker = await User.findById(workerId).select('completedJobs');

    const paymentQuery = {
      worker: workerId,
      status: { $in: ['held', 'released', 'disputed'] },
    };
    if (filters.status) paymentQuery.status = filters.status;

    const [cashBookings, cashDebts, onlinePayments, completedJobs] = await Promise.all([
      Booking.find({
        worker: workerId,
        paymentMethod: 'cash',
        status: 'completed',
      })
        .populate('user', 'name')
        .sort({ updatedAt: -1 }),
      CashDebt.find({
        worker: workerId,
        status: { $in: ['outstanding', 'partially_paid', 'paid'] },
      }),
      Payment.find(paymentQuery)
        .populate({
          path: 'booking',
          select: 'status paymentStatus paymentMethod scheduledDate updatedAt actualCompletedAt serviceCategory serviceName totalPrice platformFeeAmount address user',
          populate: { path: 'user', select: 'name' },
        })
        .sort({ createdAt: -1 }),
      Booking.countDocuments({ worker: workerId, status: 'completed' }),
    ]);

    const onlinePaymentIds = onlinePayments.map((payment) => payment._id);
    const releaseTransactions = onlinePaymentIds.length
      ? await Transaction.find({
        payment: { $in: onlinePaymentIds },
        type: 'release',
      }).sort({ createdAt: -1 })
      : [];

    const latestReleaseTxByPayment = new Map();
    for (const tx of releaseTransactions) {
      const key = String(tx.payment || '');
      if (key && !latestReleaseTxByPayment.has(key)) latestReleaseTxByPayment.set(key, tx);
    }

    const cashBookingById = new Map(cashBookings.map((booking) => [String(booking._id), booking]));
    const debtByBooking = new Map(cashDebts.map((debt) => [String(debt.booking), debt]));
    const outstandingCashFees = roundMoney(cashDebts.reduce((sum, debt) => {
      if (!['outstanding', 'partially_paid'].includes(debt.status)) return sum;
      return sum + roundMoney((debt.amount || 0) - (debt.paidAmount || 0));
    }, 0));
    const cashFeesLifetime = roundMoney(cashDebts.reduce((sum, debt) => sum + roundMoney(debt.amount || 0), 0));

    const monthStart = startOfDay(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
    const nextMonthStart = startOfDay(new Date(new Date().getFullYear(), new Date().getMonth() + 1, 1));
    const lastMonthStart = startOfDay(new Date(new Date().getFullYear(), new Date().getMonth() - 1, 1));
    const sevenDayStart = startOfDay(new Date(Date.now() - 6 * 86400000));
    const sevenDayTrend = new Array(7).fill(0);

    const cashItems = cashBookings.map((booking) => {
      const amount = bookingTakeHomeSnapshot(booking);
      const occurredAt = bookingMoneyDate(booking);
      const debt = debtByBooking.get(String(booking._id));
      const settlementNote = debt?.status === 'paid'
        ? 'Cash collected. Platform fee already settled.'
        : 'Cash collected. Platform fee tracked separately.';
      const item = {
        bookingId: booking._id,
        shortBookingId: formatShortBookingId(booking._id),
        paymentMethod: 'cash',
        customerName: booking.user?.name || '',
        serviceName: booking.serviceName || booking.serviceCategory || 'Service',
        gross: amount.gross,
        fee: amount.fee,
        takeHomeNet: amount.net,
        walletCreditAmount: 0,
        cashCollectedAmount: amount.net,
        displayAmount: amount.net,
        settlementType: 'cash_collected',
        settlementNote,
        releaseStatus: booking.paymentStatus || 'cash_settled',
        bookingStatus: booking.status,
        occurredAt,
        scheduledDate: booking.scheduledDate || null,
        address: booking.address || '',
      };

      if (occurredAt && occurredAt >= monthStart && occurredAt < nextMonthStart) {
        item._countsForMonth = true;
      }
      if (occurredAt && occurredAt >= lastMonthStart && occurredAt < monthStart) {
        item._countsForLastMonth = true;
      }
      if (occurredAt && occurredAt >= sevenDayStart) {
        const bucket = Math.floor((startOfDay(occurredAt).getTime() - sevenDayStart.getTime()) / 86400000);
        if (bucket >= 0 && bucket < sevenDayTrend.length) sevenDayTrend[bucket] = roundMoney(sevenDayTrend[bucket] + amount.net);
      }
      return item;
    });

    const paymentItems = onlinePayments
      .filter((payment) => payment.booking && (payment.status === 'released' || validPendingBooking(payment.booking)))
      .map((payment) => {
        const booking = payment.booking;
        const gross = roundMoney(booking?.totalPrice || payment.workerEarning || 0);
        const fee = roundMoney(booking?.platformFeeAmount || payment.platformFee || 0);
        const releaseTx = latestReleaseTxByPayment.get(String(payment._id));
        const releasedAmount = roundMoney(releaseTx?.amount || (payment.status === 'released' ? payment.workerEarning || 0 : 0));
        const occurredAt = releaseTx?.createdAt || payment.releasedAt || bookingMoneyDate(booking) || payment.createdAt;
        const isReleased = payment.status === 'released';
        const settlementType = isReleased
          ? (releasedAmount < roundMoney(payment.workerEarning || 0) ? 'released_after_offset' : 'released_to_wallet')
          : 'pending_release';
        const settlementNote = isReleased
          ? (releaseTx?.note || 'Released to wallet.')
          : 'Pending release approval.';
        const displayAmount = isReleased ? releasedAmount : roundMoney(payment.workerEarning || gross);
        const item = {
          bookingId: booking._id,
          shortBookingId: formatShortBookingId(booking._id),
          paymentId: payment._id,
          paymentMethod: booking.paymentMethod || payment.paymentMethod || 'online',
          customerName: booking.user?.name || '',
          serviceName: booking.serviceName || booking.serviceCategory || 'Service',
          gross,
          fee,
          takeHomeNet: displayAmount,
          walletCreditAmount: isReleased ? releasedAmount : 0,
          cashCollectedAmount: 0,
          displayAmount,
          settlementType,
          settlementNote,
          releaseStatus: payment.status,
          bookingStatus: booking.status,
          occurredAt,
          scheduledDate: booking.scheduledDate || null,
          address: booking.address || '',
        };

        if (isReleased && occurredAt && occurredAt >= monthStart && occurredAt < nextMonthStart) {
          item._countsForMonth = true;
        }
        if (isReleased && occurredAt && occurredAt >= lastMonthStart && occurredAt < monthStart) {
          item._countsForLastMonth = true;
        }
        if (isReleased && occurredAt && occurredAt >= sevenDayStart) {
          const bucket = Math.floor((startOfDay(occurredAt).getTime() - sevenDayStart.getTime()) / 86400000);
          if (bucket >= 0 && bucket < sevenDayTrend.length) sevenDayTrend[bucket] = roundMoney(sevenDayTrend[bucket] + releasedAmount);
        }
        return item;
      });

    const outstandingCashFeeItems = cashDebts
      .filter((debt) => ['outstanding', 'partially_paid'].includes(debt.status))
      .map((debt) => {
        const booking = cashBookingById.get(String(debt.booking));
        const amount = bookingTakeHomeSnapshot(booking);
        return {
          bookingId: debt.booking,
          shortBookingId: formatShortBookingId(debt.booking),
          gross: amount.gross,
          fee: roundMoney(debt.amount || 0),
          remaining: roundMoney((debt.amount || 0) - (debt.paidAmount || 0)),
          paidAmount: roundMoney(debt.paidAmount || 0),
          status: debt.status,
          occurredAt: bookingMoneyDate(booking) || debt.createdAt,
        };
      })
      .sort((a, b) => new Date(b.occurredAt || 0) - new Date(a.occurredAt || 0));

    const recentEarnings = [...cashItems, ...paymentItems]
      .sort((a, b) => new Date(b.occurredAt || 0) - new Date(a.occurredAt || 0))
      .slice(0, 10);

    const filteredPayments = onlinePayments.filter((payment) => {
      const matchDate = isMoneyDateInRange(
        payment.releasedAt || payment.heldAt || payment.createdAt,
        filters
      );
      return matchDate || (!filters.dateFrom && !filters.dateTo);
    });

    const summary = filteredPayments.reduce(
      (acc, payment) => {
        if (PAYMENT_PENDING_STATUSES.includes(payment.status) && validPendingBooking(payment.booking)) {
          acc.totalHeld = roundMoney(acc.totalHeld + (payment.workerEarning || 0));
        }
        if (payment.status === 'released') {
          const releaseTx = latestReleaseTxByPayment.get(String(payment._id));
          acc.totalReleased = roundMoney(acc.totalReleased + (releaseTx?.amount || payment.workerEarning || 0));
        }
        return acc;
      },
      { totalHeld: 0, totalReleased: 0 }
    );

    const cashNet = roundMoney(cashItems.reduce((sum, item) => sum + item.cashCollectedAmount, 0));
    const thisMonthTakeHome = roundMoney(
      [...cashItems, ...paymentItems].reduce((sum, item) => sum + (item._countsForMonth ? item.displayAmount : 0), 0)
    );
    const lastMonthTakeHome = roundMoney(
      [...cashItems, ...paymentItems].reduce((sum, item) => sum + (item._countsForLastMonth ? item.displayAmount : 0), 0)
    );
    const walletReleasedNet = roundMoney(wallet.totalEarned || 0);
    const pendingRelease = roundMoney(wallet.pendingBalance || 0);
    const pendingJobsCount = onlinePayments.filter(
      (payment) => PAYMENT_PENDING_STATUSES.includes(payment.status) && validPendingBooking(payment.booking)
    ).length;

    return {
      wallet,
      payoutMethod: wallet.payoutMethod,
      payments: filteredPayments,
      summary,
      completedJobs: completedJobs || worker?.completedJobs || 0,
      breakdown: {
        availableToWithdraw: roundMoney(wallet.balance || 0),
        pendingRelease,
        pendingJobsCount,
        outstandingCashFees,
        collectedCashNet: cashNet,
        cashCompletedJobsCount: cashItems.length,
        walletReleasedNet,
        lifetimeTakeHome: roundMoney(walletReleasedNet + cashNet),
        thisMonthTakeHome,
        lastMonthTakeHome,
        completedJobs: completedJobs || worker?.completedJobs || 0,
        cashFeesLifetime,
        averageCashFee: cashItems.length ? roundMoney(cashFeesLifetime / cashItems.length) : 0,
        outstandingCashFeeItems,
        recentEarnings,
        sevenDayTrend,
      },
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

const PARTIAL_REFUND_REASON_CODES = new Set([
  'service_incomplete',
  'quality_issue',
  'pricing_adjustment',
  'customer_goodwill',
  'admin_policy',
  'manual_adjustment',
]);

PaymentService.prototype.partialRefund = async function ({ bookingId, adminId, refundAmount, deductFrom, reason, reasonCode, ipAddress }) {
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const payment = await Payment.findOne({ booking: bookingId }).session(session);
      if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found');
      if (!['held', 'released'].includes(payment.status)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot refund status=${payment.status}`);
      }
      const amount = roundMoney(Number(refundAmount));
      if (!Number.isFinite(amount) || amount <= 0) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund amount must be greater than zero');
      }
      const normalizedReasonCode = String(reasonCode || '').trim();
      if (!PARTIAL_REFUND_REASON_CODES.has(normalizedReasonCode)) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Valid refund reasonCode is required');
      }
      const note = String(reason || '').trim();
      if (note.length < 5) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund reason note must be at least 5 chars');
      }
      const remainingRefundable = roundMoney((payment.amount || 0) - (payment.refundedAmount || 0));
      if (amount > remainingRefundable) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund exceeds remaining refundable amount');
      }

      const booking = await Booking.findById(bookingId).session(session);
      if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
      const AdminAction = require('../admin/admin-action.model');
      const previousRefundActions = await AdminAction.find({
        targetType: 'payment',
        targetId: payment._id,
        actionType: 'payment_partial_refund',
      }).session(session);
      const previousFromTech = roundMoney(previousRefundActions.reduce((sum, action) => sum + Number(action.details?.fromTech || 0), 0));
      const previousFromPlatform = roundMoney(previousRefundActions.reduce((sum, action) => sum + Number(action.details?.fromPlatform || 0), 0));
      const techShare = roundMoney(payment.workerEarning || 0);
      const platformShare = roundMoney(payment.platformFee || 0);
      const techAvailable = Math.max(0, roundMoney(techShare - previousFromTech));
      const platformAvailable = Math.max(0, roundMoney(platformShare - previousFromPlatform));
      let fromTech = 0, fromPlatform = 0;
      switch (deductFrom) {
        case 'tech':         fromTech = amount; break;
        case 'platform':     fromPlatform = amount; break;
        case 'proportional': {
          const ratio = amount / payment.amount;
          fromTech = roundMoney(techShare * ratio);
          fromPlatform = roundMoney(platformShare * ratio);
          break;
        }
        default: throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid deductFrom');
      }
      if (fromTech > techAvailable) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund exceeds available worker earnings');
      }
      if (fromPlatform > platformAvailable) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund exceeds available platform fee');
      }

      if (payment.gatewayChargeId) {
        const gateway = getGateway();
        const refund = await gateway.refund({
          chargeId: payment.gatewayChargeId,
          amount,
          reason: note,
        });
        payment.gatewayRefundId = refund.refundId;
      }

      payment.refundedAmount = roundMoney((payment.refundedAmount || 0) + amount);
      payment.status = payment.refundedAmount >= payment.amount ? 'refunded' : 'partially_refunded';
      payment.refundedAt = new Date();
      await payment.save({ session });

      const wallet = await Wallet.findOne({ worker: booking.worker }).session(session);
      if (fromTech > 0) {
        if (!wallet) throw new ApiError(StatusCodes.CONFLICT, 'Worker wallet not found');
        if (payment.releasedAt) {
          if (roundMoney(wallet.balance || 0) < fromTech) throw new ApiError(StatusCodes.BAD_REQUEST, 'Insufficient released worker balance for refund');
          wallet.balance = roundMoney((wallet.balance || 0) - fromTech);
        } else {
          if (roundMoney(wallet.pendingBalance || 0) < fromTech) throw new ApiError(StatusCodes.BAD_REQUEST, 'Insufficient pending worker balance for refund');
          wallet.pendingBalance = roundMoney((wallet.pendingBalance || 0) - fromTech);
        }
        await wallet.save({ session });
      }

      await adminAction.record({
        adminId, actionType: 'payment_partial_refund',
        targetType: 'payment', targetId: payment._id,
        details: { refundAmount: amount, fromTech, fromPlatform, reasonCode: normalizedReasonCode, reason: note },
        ipAddress, session,
      });
      return { payment, splits: { fromTech, fromPlatform } };
    });
  } finally {
    await session.endSession();
  }
};

PaymentService.prototype.forceRelease = async function (paymentId, { actor, reason, reasonCode = 'emergency_override', ipAddress } = {}) {
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

      await this.releaseHeldPayment(payment, booking, actor, session, { reasonCode, note: reason });
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
        details: { reason, reasonCode, amount: payment.amount, bookingId: booking._id },
        ipAddress,
        session,
      });

      result = payment;
    });
    return result;
  } finally { await session.endSession(); }
};

PaymentService.prototype.forceLock = async function (paymentId, { actor, reason, reasonCode = 'manual_lock', ipAddress } = {}) {
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
    details: { reason, reasonCode },
    ipAddress,
  });
  return payment;
};

PaymentService.prototype.forceUnlock = async function (paymentId, { actor, reason, reasonCode = 'manual_unlock', ipAddress } = {}) {
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
    details: { reason, reasonCode },
    ipAddress,
  });
  return payment;
};

module.exports = new PaymentService();
