const { StatusCodes } = require('http-status-codes');
const mongoose = require('mongoose');

const Booking     = require('../bookings/booking.model');
const Payment     = require('./payment.model');
const Dispute     = require('./dispute.model');
const CashDebt    = require('./cash-debt.model');
const Transaction = require('./transaction.model');
const ApiError    = require('../../utils/ApiError');
const notifSvc    = require('../notifications/notification.service');
const notify      = require('../notifications/dispatcher');
const paymentEvents = require('../../sockets/payment.events');

let paymentService;
const getPaymentService = () => {
  if (!paymentService) paymentService = require('./payment.service');
  return paymentService;
};

let customerCreditService;
const getCustomerCreditService = () => {
  if (!customerCreditService) customerCreditService = require('./customer-credit.service');
  return customerCreditService;
};

const { money } = require('../../utils/rounding');

/**
 * I-C: return credit consumed at hold time (`holdPayment` -> customerCreditSvc.consume)
 * back to the customer. The hold splits funds across gateway + credit (Task 10's
 * `creditApplied`); a customer-win refund must give back BOTH, not just the gateway
 * portion. Issued as a fresh CustomerCredit grant (not an "un-consume" of the original
 * credit rows) because those rows may have been partially consumed by other bookings
 * since — this is intentionally outside the settle transaction (issueCredit owns its
 * own session) and is the dispute-resolution mirror of the consume() call at hold time.
 */
async function returnCreditIfAny(payment, booking, adminId, resolution) {
  const creditApplied = Number(payment.creditApplied || 0);
  if (!(creditApplied > 0)) return null;
  return getCustomerCreditService().issueCredit({
    customer: payment.user || booking.user,
    amount: creditApplied,
    source: 'refund_fallback',
    reason: `Dispute resolution credit return for booking ${booking._id}: ${String(resolution).slice(0, 100)}`,
    issuedBy: adminId,
    relatedBooking: booking._id,
    relatedPayment: payment._id,
  });
}

const ACTIVE_DISPUTE_STATUSES = ['open', 'reviewing', 'awaiting_evidence', 'escalated'];
const RESOLVED_STATUSES = ['resolved_refund', 'resolved_release', 'resolved_partial', 'resolved_redo', 'closed'];
const DISPUTABLE_BOOKING_STATUSES = ['awaiting_customer_confirmation'];

const MAX_EVIDENCE_PER_DISPUTE = 12;
const MAX_INTERNAL_NOTE_LEN = 2000;

const hoursFromNow = (h) => new Date(Date.now() + h * 60 * 60 * 1000);

function normalizeEvidenceItem(item, fallbackUploader, fallbackRole) {
  if (!item) return null;
  if (typeof item === 'string') {
    const url = item.trim();
    if (!url) return null;
    return {
      url,
      uploadedBy: fallbackUploader || undefined,
      uploadedByRole: fallbackRole || undefined,
      uploadedAt: new Date(),
    };
  }
  const url = String(item.url || item.secureUrl || item.path || '').trim();
  if (!url) return null;
  return {
    url,
    name: item.name || item.originalName || item.filename || undefined,
    mime: item.mime || item.mimeType || undefined,
    size: typeof item.size === 'number' ? item.size : undefined,
    uploadedBy: item.uploadedBy || fallbackUploader || undefined,
    uploadedByRole: item.uploadedByRole || fallbackRole || undefined,
    uploadedAt: item.uploadedAt ? new Date(item.uploadedAt) : new Date(),
  };
}

function normalizeEvidenceList(list, uploader, role, existingCount = 0) {
  if (!Array.isArray(list)) return [];
  const slots = Math.max(0, MAX_EVIDENCE_PER_DISPUTE - existingCount);
  return list
    .map((e) => normalizeEvidenceItem(e, uploader, role))
    .filter(Boolean)
    .slice(0, slots);
}

function pushHistory(dispute, status, by, byRole, note) {
  dispute.history.push({
    status,
    by: by || undefined,
    byRole: byRole || 'system',
    note: note || undefined,
    at: new Date(),
  });
}

function isCashBooking(booking) {
  return String(booking?.paymentMethod || '').toLowerCase() === 'cash';
}

function assertActive(dispute) {
  if (!ACTIVE_DISPUTE_STATUSES.includes(dispute.status)) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Cannot perform this action on a dispute with status '${dispute.status}'.`
    );
  }
}

const populateForAdmin = (q) =>
  q
    .populate({
      path: 'booking',
      select: 'scheduledDate scheduledTime address status paymentMethod paymentStatus totalPrice estimatedTotal platformFeeAmount serviceCategory service user worker',
      populate: [
        { path: 'user', select: 'name email phone' },
        { path: 'worker', select: 'name email phone' },
        { path: 'service', select: 'title category basePrice' },
      ],
    })
    .populate('payment', 'amount status currency platformFee workerEarning')
    .populate('raisedBy', 'name email role')
    .populate('resolvedBy', 'name')
    .populate('assignedAdmin', 'name email')
    .populate('appealedBy', 'name email')
    .populate('history.by', 'name role')
    .populate('internalNotes.by', 'name')
    .populate('evidence.uploadedBy', 'name role');

class DisputeService {
  async openDispute(bookingId, userId, reason, evidence = [], category = 'other', extras = {}) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== userId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }
    if (!DISPUTABLE_BOOKING_STATUSES.includes(booking.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot open a dispute for a booking with status '${booking.status}'.`
      );
    }

    const existingDispute = await Dispute.findOne({
      booking: bookingId,
      status: { $in: ACTIVE_DISPUTE_STATUSES },
    });
    if (existingDispute) {
      throw new ApiError(StatusCodes.CONFLICT, 'An open dispute already exists for this booking.');
    }

    let payment = null;
    if (!isCashBooking(booking)) {
      payment = await Payment.findOne({ booking: bookingId });
      if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found for this booking.');
      if (payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot dispute a payment with status '${payment.status}'.`);
      }

      payment.status = 'disputed';
      await payment.save();

      await Booking.findByIdAndUpdate(bookingId, {
        status: 'disputed',
        paymentStatus: 'disputed',
      });

      await Transaction.create({
        payment: payment._id,
        type: 'dispute',
        amount: payment.amount,
        currency: payment.currency,
        direction: 'debit',
        actor: userId,
        note: `Dispute opened for booking ${bookingId}. Reason: ${reason.substring(0, 50)}`,
      });
    } else {
      await Booking.findByIdAndUpdate(bookingId, {
        status: 'disputed',
        paymentStatus: 'disputed',
      });
    }

    const normalizedEvidence = normalizeEvidenceList(evidence, userId, 'user', 0);
    const severity = ['low', 'medium', 'high', 'critical'].includes(extras.severity) ? extras.severity : 'medium';

    const dispute = await Dispute.create({
      booking: bookingId,
      payment: payment?._id,
      raisedBy: userId,
      raisedByRole: 'user',
      reason,
      category,
      severity,
      estimatedDamages: typeof extras.estimatedDamages === 'number' ? extras.estimatedDamages : undefined,
      evidence: normalizedEvidence,
      slaFirstResponseDueAt: hoursFromNow(Dispute.SLA_FIRST_RESPONSE_HOURS),
      slaResolveDueAt: hoursFromNow(Dispute.SLA_RESOLVE_HOURS),
      history: [
        {
          status: 'open',
          by: userId,
          byRole: 'user',
          note: `Dispute opened: ${reason.substring(0, 80)}`,
          at: new Date(),
        },
      ],
    });

    Promise.resolve(notifSvc.notifyDisputeOpened({ ...(dispute.toObject?.() || dispute), booking })).catch(() => {});
    paymentEvents.emitDisputeOpened({ dispute, booking });

    const counterparty = booking.user?.toString() === userId.toString() ? booking.worker : booking.user;
    notify.safeDispatch('dispute.opened', {
      recipient: counterparty,
      disputeId: dispute._id,
      bookingId: booking._id,
      reason,
    });

    return dispute;
  }

  async resolveDispute(disputeId, adminId, payload = {}) {
    const { resolution, decision, refundAmount, internalNote } = payload;
    if (!resolution || !decision) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'resolution and decision are required.');
    }
    if (!['refund', 'release', 'partial_refund', 'redo'].includes(decision)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, "decision must be one of: refund, release, partial_refund, redo.");
    }

    const dispute = await Dispute.findById(disputeId)
      .populate({
        path: 'booking',
        populate: [
          { path: 'user', select: 'name email' },
          { path: 'worker', select: 'name email' },
          { path: 'service', select: 'title category' },
        ],
      })
      .populate('payment');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    assertActive(dispute);

    const booking = dispute.booking;
    const payment = dispute.payment;
    const hasPayment = Boolean(payment);
    const ps = getPaymentService();

    if (decision === 'refund') {
      // Customer wins outright: no capture, hold lapses, payment marked refunded.
      // The hold split funds across gateway + credit (Task 10's creditApplied) — a
      // customer-win refund must give back BOTH (I-C), so we return any creditApplied
      // after the gateway-facing refund completes.
      if (hasPayment) {
        await ps.refundPayment(payment._id.toString(), adminId, resolution);
        await returnCreditIfAny(payment, booking, adminId, resolution);
      } else {
        booking.status = 'cancelled';
        booking.paymentStatus = 'not_required';
        booking.cancellationReason = resolution;
        await booking.save();
      }
      dispute.status = 'resolved_refund';
      dispute.refundAmount = hasPayment ? payment.amount : 0;
    } else if (decision === 'release') {
      // Customer loses outright: settle to the final grandTotal exactly like a normal
      // release (Task 10's settleToAmount, via releaseHeldPayment) — capture
      // min(grandTotal, hold). This IS the resolution of the open issue, so it is the
      // narrow, intentional exception to the "cannot release while issue open" guard
      // (payment.service.js assertAdminApprovalBookingEligible) — dispute resolution
      // never routes through that guard (it calls releaseHeldPayment directly, not
      // adminApproveCompletion), but allowOpenIssue exists precisely to make that
      // exception explicit and safe if a future caller wires the guard in here too.
      const session = await mongoose.startSession();
      try {
        await session.withTransaction(async () => {
          const freshBooking = await Booking.findById(booking._id).session(session);
          freshBooking.status = 'completed';

          if (hasPayment) {
            const freshPayment = await Payment.findById(payment._id).session(session);
            freshBooking.paymentStatus = 'released';
            await freshBooking.save({ session });
            await ps.releaseHeldPayment(freshPayment, freshBooking, adminId, session, {
              reasonCode: 'dispute_resolution',
              note: resolution,
              allowOpenIssue: true,
            });
            return;
          }

          freshBooking.paymentStatus = 'cash_pending_settlement';
          await freshBooking.save({ session });

          const existingDebt = await CashDebt.findOne({ booking: freshBooking._id }).session(session);
          if (!existingDebt && freshBooking.platformFeeAmount > 0) {
            await CashDebt.create([{
              worker: freshBooking.worker,
              booking: freshBooking._id,
              amount: freshBooking.platformFeeAmount,
            }], { session });
          }
        });
      } finally {
        await session.endSession();
      }
      dispute.status = 'resolved_release';
      dispute.refundAmount = 0;
    } else if (decision === 'partial_refund') {
      if (!hasPayment) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Partial refund requires an escrow payment (online/card booking).');
      }
      // The refundable ceiling is the FINAL invoice (grandTotal), not the hold —
      // the hold authorizes the worst-case ceiling (C-B) and is always >= grandTotal,
      // so bounding against payment.amount (the hold) would let an admin enter a
      // refundAmount larger than the invoice itself, driving settleTarget negative.
      const grand = booking.grandTotal || payment.amount; // I6: in-flight/legacy fallback
      const amt = Number(refundAmount);
      if (!Number.isFinite(amt) || amt <= 0 || amt >= grand) {
        throw new ApiError(
          StatusCodes.BAD_REQUEST,
          `refundAmount must be > 0 and < ${grand} for partial refund.`
        );
      }

      // Settle to grandTotal minus the refunded slice, via the SAME settleToAmount
      // helper release uses (Task 10/12 shared logic) — captures
      // money(grandTotal - refundAmount), clamped to the hold.
      const settleTarget = money(grand - amt);

      const session = await mongoose.startSession();
      let captureAmount;
      try {
        await session.withTransaction(async () => {
          const freshBooking = await Booking.findById(booking._id).session(session);
          const freshPayment = await Payment.findById(payment._id).session(session);

          const result = await ps.settleToAmount(freshPayment, freshBooking, settleTarget, session);
          captureAmount = result.captureAmount;

          freshPayment.status = 'released';
          freshPayment.releasedAt = new Date();
          freshPayment.releaseApprovedAt = new Date();
          freshPayment.releaseApprovedBy = adminId;
          freshPayment.refundedAmount = money((freshPayment.refundedAmount || 0) + amt);
          await freshPayment.save({ session });

          freshBooking.status = 'completed';
          freshBooking.paymentStatus = 'released';
          await freshBooking.save({ session });

          const { wallet } = await ps.reconcileWorkerWalletState(freshPayment.worker, session);
          await wallet.credit(result.remainingAmount);

          await Transaction.create([{
            payment: freshPayment._id,
            wallet: wallet._id,
            type: 'refund',
            amount: amt,
            currency: freshPayment.currency,
            direction: 'credit',
            actor: adminId,
            note: `Partial refund to customer: ${resolution.substring(0, 60)}`,
          }], { session });

          await Transaction.create([{
            payment: freshPayment._id,
            wallet: wallet._id,
            type: 'release',
            amount: result.remainingAmount,
            currency: freshPayment.currency,
            direction: 'credit',
            actor: adminId,
            note: `Partial release to worker (worker earning ${result.workerEarning}, after debt offset ${result.remainingAmount})`,
          }], { session });
        });
      } finally {
        await session.endSession();
      }

      // I-C: if the refunded slice exceeds what the gateway actually captured, the
      // shortfall was covered out of creditApplied at hold time — return that portion
      // to the customer's credit balance (the hold split funds across gateway + credit).
      const refreshedPayment = await Payment.findById(payment._id);
      const creditApplied = Number(refreshedPayment.creditApplied || 0);
      if (creditApplied > 0) {
        const gatewayCharged = Number(refreshedPayment.gatewayChargeAmount ?? (payment.amount - creditApplied));
        const shortfall = money(Math.max(0, gatewayCharged - captureAmount));
        const creditToReturn = money(Math.min(creditApplied, shortfall));
        if (creditToReturn > 0) {
          await getCustomerCreditService().issueCredit({
            customer: refreshedPayment.user || booking.user,
            amount: creditToReturn,
            source: 'refund_fallback',
            reason: `Dispute partial-refund credit return for booking ${booking._id}: ${String(resolution).slice(0, 100)}`,
            issuedBy: adminId,
            relatedBooking: booking._id,
            relatedPayment: refreshedPayment._id,
          });
        }
      }

      dispute.status = 'resolved_partial';
      dispute.refundAmount = amt;
    } else if (decision === 'redo') {
      // Tech sent back to redo job. Money stays in escrow. Booking goes back to in_progress.
      booking.status = 'in_progress';
      if (hasPayment) booking.paymentStatus = 'held';
      await booking.save();
      if (hasPayment && payment.status === 'disputed') {
        payment.status = 'held';
        await payment.save();
      }
      dispute.status = 'resolved_redo';
      dispute.refundAmount = 0;
    }

    dispute.resolution = resolution;
    dispute.decision = decision;
    dispute.resolvedBy = adminId;
    dispute.resolvedAt = new Date();
    if (!dispute.firstResponseAt) dispute.firstResponseAt = new Date();
    if (internalNote && typeof internalNote === 'string' && internalNote.trim()) {
      dispute.internalNotes.push({
        by: adminId,
        note: internalNote.trim().slice(0, MAX_INTERNAL_NOTE_LEN),
      });
    }
    pushHistory(dispute, dispute.status, adminId, 'admin', `Decision: ${decision}. ${resolution.substring(0, 120)}`);
    await dispute.save();

    Promise.resolve(notifSvc.notifyDisputeResolved(dispute)).catch(() => {});
    return dispute;
  }

  async markDisputeReviewing(disputeId, adminId) {
    const dispute = await Dispute.findById(disputeId).populate('booking', 'user worker');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    assertActive(dispute);

    dispute.status = 'reviewing';
    if (!dispute.firstResponseAt) dispute.firstResponseAt = new Date();
    if (adminId && !dispute.assignedAdmin) dispute.assignedAdmin = adminId;
    pushHistory(dispute, 'reviewing', adminId, 'admin');
    await dispute.save();
    Promise.resolve(notifSvc.notifyDisputeStatusChanged?.(dispute, 'reviewing')).catch(() => {});
    return dispute;
  }

  async assignAdmin(disputeId, adminId) {
    const dispute = await Dispute.findById(disputeId);
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    if (RESOLVED_STATUSES.includes(dispute.status)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Cannot reassign a resolved dispute.');
    }
    dispute.assignedAdmin = adminId;
    pushHistory(dispute, dispute.status, adminId, 'admin', 'Assigned admin owner');
    await dispute.save();
    return dispute;
  }

  async addInternalNote(disputeId, adminId, note) {
    if (!note || !note.trim()) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Note is required.');
    }
    const dispute = await Dispute.findById(disputeId);
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    dispute.internalNotes.push({
      by: adminId,
      note: note.trim().slice(0, MAX_INTERNAL_NOTE_LEN),
    });
    await dispute.save();
    return dispute;
  }

  async requestEvidence(disputeId, adminId, target = 'both', message) {
    if (!['user', 'worker', 'both'].includes(target)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, "target must be one of: user, worker, both.");
    }
    const dispute = await Dispute.findById(disputeId).populate('booking', 'user worker');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    assertActive(dispute);

    dispute.status = 'awaiting_evidence';
    dispute.evidenceRequestedFrom = target;
    dispute.evidenceRequestedAt = new Date();
    if (adminId && !dispute.assignedAdmin) dispute.assignedAdmin = adminId;
    if (!dispute.firstResponseAt) dispute.firstResponseAt = new Date();
    pushHistory(dispute, 'awaiting_evidence', adminId, 'admin', message || `Requested evidence from ${target}`);
    await dispute.save();

    Promise.resolve(notifSvc.notifyDisputeEvidenceRequested?.(dispute, target, message)).catch(() => {});
    return dispute;
  }

  async addEvidence(disputeId, userId, userRole, files = []) {
    const dispute = await Dispute.findById(disputeId).populate('booking', 'user worker');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    if (RESOLVED_STATUSES.includes(dispute.status)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Cannot add evidence to a resolved dispute.');
    }

    const booking = dispute.booking;
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');

    const isCustomer = booking.user?.toString() === userId.toString();
    const isWorker = booking.worker?.toString() === userId.toString();
    const isAdmin = userRole === 'admin';
    if (!isCustomer && !isWorker && !isAdmin) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You are not a party to this dispute.');
    }

    const role = isAdmin ? 'admin' : isCustomer ? 'user' : 'worker';
    const normalized = normalizeEvidenceList(files, userId, role, dispute.evidence.length);
    if (!normalized.length) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'No valid evidence files provided.');
    }
    dispute.evidence.push(...normalized);

    if (
      dispute.status === 'awaiting_evidence' &&
      (dispute.evidenceRequestedFrom === role || dispute.evidenceRequestedFrom === 'both')
    ) {
      dispute.status = 'reviewing';
      pushHistory(dispute, 'reviewing', userId, role, `Evidence received from ${role}`);
    } else {
      pushHistory(dispute, dispute.status, userId, role, `Added ${normalized.length} evidence file(s)`);
    }

    await dispute.save();
    Promise.resolve(notifSvc.notifyDisputeEvidenceAdded?.(dispute, role)).catch(() => {});

    const counterparty = role === 'user' ? booking.worker : booking.user;
    if (counterparty) {
      notify.safeDispatch('dispute.evidence_added', {
        recipient: counterparty,
        disputeId: dispute._id,
        bookingId: booking._id,
        byRole: role,
      });
    }

    return dispute;
  }

  async appealDispute(disputeId, userId, userRole, appealReason) {
    if (!appealReason || appealReason.trim().length < 20) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Appeal reason must be at least 20 characters.');
    }
    const dispute = await Dispute.findById(disputeId);
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    if (!['resolved_refund', 'resolved_release', 'resolved_partial', 'resolved_redo'].includes(dispute.status)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Only resolved disputes can be appealed.');
    }
    if (dispute.appealStatus) {
      throw new ApiError(StatusCodes.CONFLICT, 'This dispute has already been appealed.');
    }

    const APPEAL_WINDOW_HOURS = 48;
    const resolvedMs = dispute.resolvedAt ? new Date(dispute.resolvedAt).getTime() : 0;
    if (Date.now() - resolvedMs > APPEAL_WINDOW_HOURS * 3600 * 1000) {
      throw new ApiError(StatusCodes.BAD_REQUEST, `Appeal window of ${APPEAL_WINDOW_HOURS}h has expired.`);
    }

    const booking = await Booking.findById(dispute.booking).select('user worker');
    const isCustomer = booking?.user?.toString() === userId.toString();
    const isWorker = booking?.worker?.toString() === userId.toString();
    if (!isCustomer && !isWorker) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You are not a party to this dispute.');
    }

    dispute.status = 'appealed';
    dispute.appealStatus = 'pending';
    dispute.appealReason = appealReason.trim();
    dispute.appealedBy = userId;
    dispute.appealedByRole = isCustomer ? 'user' : 'worker';
    dispute.appealedAt = new Date();
    pushHistory(dispute, 'appealed', userId, dispute.appealedByRole, `Appeal: ${appealReason.substring(0, 100)}`);
    await dispute.save();
    Promise.resolve(notifSvc.notifyDisputeAppealed?.(dispute)).catch(() => {});
    return dispute;
  }

  async resolveAppeal(disputeId, adminId, outcome, note) {
    if (!['upheld', 'overturned'].includes(outcome)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, "outcome must be 'upheld' or 'overturned'.");
    }
    const dispute = await Dispute.findById(disputeId).populate('booking', 'user worker');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    if (dispute.appealStatus !== 'pending' && dispute.appealStatus !== 'reviewing') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'No active appeal on this dispute.');
    }

    dispute.appealStatus = outcome;
    dispute.appealResolvedAt = new Date();
    dispute.status = outcome === 'upheld'
      ? (dispute.decision === 'refund' ? 'resolved_refund'
        : dispute.decision === 'partial_refund' ? 'resolved_partial'
        : dispute.decision === 'redo' ? 'resolved_redo'
        : 'resolved_release')
      : 'reviewing';
    if (note && note.trim()) {
      dispute.internalNotes.push({ by: adminId, note: note.trim().slice(0, MAX_INTERNAL_NOTE_LEN) });
    }
    pushHistory(dispute, dispute.status, adminId, 'admin', `Appeal ${outcome}${note ? `: ${note.substring(0, 100)}` : ''}`);
    await dispute.save();
    return dispute;
  }

  async getDisputeById(disputeId) {
    const dispute = await populateForAdmin(Dispute.findById(disputeId));
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    return dispute;
  }

  async getDisputesByAdmin({ status, category, assignedAdmin, slaBreached, page = 1, limit = 20 } = {}) {
    const filter = {};
    if (status) filter.status = status;
    if (category) filter.category = category;
    if (assignedAdmin) filter.assignedAdmin = assignedAdmin;
    if (slaBreached === 'true' || slaBreached === true) {
      filter.slaResolveDueAt = { $lt: new Date() };
      filter.status = { $in: ACTIVE_DISPUTE_STATUSES };
    }

    const skip = (Number(page) - 1) * Number(limit);
    const [disputes, total] = await Promise.all([
      populateForAdmin(Dispute.find(filter))
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Dispute.countDocuments(filter),
    ]);

    return {
      disputes,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async getDisputesForWorker(workerId, { status, page = 1, limit = 20 } = {}) {
    const bookings = await Booking.find({ worker: workerId }).select('_id');
    const bookingIds = bookings.map((b) => b._id);
    if (!bookingIds.length) {
      return {
        disputes: [],
        pagination: { total: 0, page: Number(page), limit: Number(limit), totalPages: 0 },
      };
    }
    const filter = { booking: { $in: bookingIds } };
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);
    const [disputes, total] = await Promise.all([
      Dispute.find(filter)
        .populate({
          path: 'booking',
          select: 'scheduledDate scheduledTime status paymentMethod paymentStatus totalPrice estimatedTotal serviceCategory service user',
          populate: [
            { path: 'user', select: 'name email phone' },
            { path: 'service', select: 'title category' },
          ],
        })
        .populate('payment', 'amount status currency')
        .populate('raisedBy', 'name email role')
        .populate('resolvedBy', 'name')
        .populate('assignedAdmin', 'name')
        .populate('history.by', 'name role')
        .populate('evidence.uploadedBy', 'name role')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Dispute.countDocuments(filter),
    ]);

    return {
      disputes,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async getDisputeByIdForParty(disputeId, userId, userRole) {
    const dispute = await populateForAdmin(Dispute.findById(disputeId));
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    const booking = dispute.booking || {};
    const isCustomer = String(booking.user?._id || booking.user || '') === String(userId);
    const isWorker = String(booking.worker?._id || booking.worker || '') === String(userId);
    const isAdmin = userRole === 'admin';
    if (!isCustomer && !isWorker && !isAdmin) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You are not a party to this dispute.');
    }
    if (!isAdmin) {
      const obj = dispute.toObject ? dispute.toObject() : dispute;
      delete obj.internalNotes;
      return obj;
    }
    return dispute;
  }

  async getDisputesForCustomer(userId, { status, page = 1, limit = 20 } = {}) {
    const filter = { raisedBy: userId, raisedByRole: 'user' };
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);
    const [disputes, total] = await Promise.all([
      Dispute.find(filter)
        .populate({
          path: 'booking',
          select: 'scheduledDate scheduledTime status paymentMethod paymentStatus serviceCategory service worker',
          populate: [
            { path: 'worker', select: 'name profileImage' },
            { path: 'service', select: 'title category' },
          ],
        })
        .populate('payment', 'amount status currency')
        .populate('resolvedBy', 'name')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Dispute.countDocuments(filter),
    ]);

    return {
      disputes,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }
}

module.exports = new DisputeService();
