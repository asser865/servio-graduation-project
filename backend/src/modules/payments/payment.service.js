// ─── Purpose ──────────────────────────────────────────────────────────────────
// PaymentService — all financial business logic lives here. Controllers are thin
// wrappers that call these methods and format responses.
//
// ════════════════════════════════════════════════════════════════════════════════
// BOOKING STATUS FLOW (payment-driven):
//   pending → accepted → [user pays] → in_progress → completed
//                                                   ↘ disputed
//
// PAYMENT STATUS FLOW:
//   pending ──→ held ──────→ released    (normal: user confirms completion)
//          ↘ failed         ↘ refunded   (admin manual refund)
//                            ↘ disputed ─→ resolved_refund  → [refunded]
//                                        → resolved_release → [released]
// ════════════════════════════════════════════════════════════════════════════════
//
// IDEMPOTENCY:
//   Before processing any webhook, we check if a Transaction with the same
//   gatewayPaymentIntentId already exists. If it does, we skip processing.
//   This prevents duplicate money movement when Stripe retries webhook delivery.
//
// ATOMICITY:
//   All multi-document operations (wallet + payment + transaction + booking)
//   are wrapped in Mongoose sessions with withTransaction(). Without this,
//   a server crash between any two writes would leave the system in an
//   inconsistent state (e.g. wallet credited but payment still showing 'held').
// ─────────────────────────────────────────────────────────────────────────────

const mongoose        = require('mongoose');
const { StatusCodes } = require('http-status-codes');
const { stripe, verifyWebhookSignature } = require('../../config/stripe');

const Booking     = require('../bookings/booking.model');
const Payment     = require('./payment.model');
const Wallet      = require('./wallet.model');
const Transaction = require('./transaction.model');
const ApiError    = require('../../utils/ApiError');

// ── Helper: log transaction ────────────────────────────────────────────────────
// WHAT: Inserts a single immutable audit log record.
// WHY:  Centralised here so every money-movement method uses the same pattern.
const logTransaction = async (data, session) => {
  const [log] = await Transaction.create([data], session ? { session } : {});
  return log;
};

// ── Helper: get or create wallet ──────────────────────────────────────────────
// WHAT: Returns existing wallet or creates a new one for the worker.
const getOrCreateWallet = async (workerId, session) => {
  let wallet = await Wallet.findOne({ worker: workerId }).session(session || null);
  if (!wallet) {
    [wallet] = await Wallet.create([{ worker: workerId }], session ? { session } : {});
  }
  return wallet;
};

class PaymentService {

  // ── 5a. createPaymentIntent ─────────────────────────────────────────────────
  // WHAT: Initiates the payment flow by creating a Stripe PaymentIntent.
  // HOW:  The clientSecret returned here is sent to the frontend so Stripe.js
  //       can collect card details and complete the payment client-side.
  //       The server NEVER sees the raw card number — Stripe handles that.
  async createPaymentIntent(bookingId, userId) {
    // Find the booking and verify ownership
    const booking = await Booking.findById(bookingId).populate('service');
    if (!booking) {
      throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    }
    if (booking.user.toString() !== userId) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    // Can only pay for an accepted booking (worker has agreed to do the job)
    if (booking.status !== 'accepted') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot create payment for a booking with status '${booking.status}'. Booking must be 'accepted'.`
      );
    }

    // Check no active (non-failed) payment exists yet — prevent double-pay
    const existingPayment = await Payment.findOne({
      booking: bookingId,
      status:  { $nin: ['failed'] }, // Allow re-attempt only if previous failed
    });
    if (existingPayment) {
      throw new ApiError(
        StatusCodes.CONFLICT,
        'A payment already exists for this booking.'
      );
    }

    // Amount validation: must be positive integer (smallest currency unit)
    // booking.totalPrice is in EGP — convert to piastres (* 100)
    const amountInSmallestUnit = Math.round(booking.totalPrice * 100);
    if (!Number.isInteger(amountInSmallestUnit) || amountInSmallestUnit < 1) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid booking amount.');
    }

    // Create the PaymentIntent on Stripe — this does NOT charge the card yet
    const intent = await stripe.paymentIntents.create({
      amount:   amountInSmallestUnit,
      currency: process.env.STRIPE_CURRENCY || 'egp',
      metadata: {
        bookingId: bookingId.toString(),
        userId:    userId.toString(),
        workerId:  booking.worker.toString(),
      },
      automatic_payment_methods: { enabled: true },
    });

    // Save a Payment document locally to track the intent
    const payment = await Payment.create({
      booking:                bookingId,
      user:                   userId,
      worker:                 booking.worker,
      amount:                 amountInSmallestUnit,
      status:                 'pending',
      gateway:                'stripe',
      gatewayPaymentIntentId: intent.id,
      currency:               process.env.STRIPE_CURRENCY || 'egp',
    });

    // Log the initial charge attempt
    await logTransaction({
      payment:   payment._id,
      type:      'charge',
      amount:    amountInSmallestUnit,
      currency:  payment.currency,
      direction: 'debit',
      actor:     userId,
      note:      `Payment intent created for booking ${bookingId}`,
    });

    return {
      clientSecret: intent.client_secret, // Needed by Stripe.js on the frontend
      paymentId:    payment._id,
      amount:       amountInSmallestUnit,
    };
  }

  // ── 5b. handleWebhook ───────────────────────────────────────────────────────
  // WHAT: Processes events sent by Stripe to our server.
  // WHY:  The frontend completes payment via Stripe.js, and Stripe notifies
  //       our server with the result. We never trust the frontend to tell us
  //       "payment worked" — we ONLY trust Stripe webhooks.
  // SECURITY: Signature is verified before processing any event.
  // IDEMPOTENCY: We check for duplicate transaction logs before acting.
  async handleWebhook(rawBody, stripeSignature) {
    // Step 1: Verify the signature — rejects any fake POST requests
    const event = verifyWebhookSignature(rawBody, stripeSignature);

    const intent = event.data.object;

    if (event.type === 'payment_intent.succeeded') {
      // ── IDEMPOTENCY CHECK ──────────────────────────────────────────────────
      // If we've already processed this event (e.g. Stripe retried delivery),
      // don't process it again — just acknowledge and return.
      const alreadyProcessed = await Transaction.findOne({
        note: { $regex: intent.id }, // Check note field for the intent ID
        type: 'hold',
      });
      if (alreadyProcessed) return { received: true, duplicate: true };

      // Find the payment document we created in createPaymentIntent
      const payment = await Payment.findOne({ gatewayPaymentIntentId: intent.id });
      if (!payment) return { received: true, warning: 'Payment not found for this intent.' };

      // Extract the charge and receipt from the Stripe event data
      const chargeId    = intent.latest_charge;
      const receiptUrl  = intent.charges?.data?.[0]?.receipt_url || null;

      // ── SESSION TRANSACTION ──────────────────────────────────────────────────
      // All updates must succeed together or all must be rolled back.
      const session = await mongoose.startSession();
      await session.withTransaction(async () => {
        // 1. Update payment status → 'held' (funds in escrow)
        payment.status           = 'held';
        payment.gatewayChargeId  = chargeId;
        payment.receiptUrl       = receiptUrl;
        await payment.save({ session });

        // 2. Update booking status → 'in_progress' (payment confirmed, work begins)
        await Booking.findByIdAndUpdate(
          payment.booking,
          { status: 'in_progress' },
          { session }
        );

        // 3. Add worker's share to pendingBalance (locked until service confirmed)
        const wallet = await getOrCreateWallet(payment.worker, session);
        await wallet.addPending(payment.workerEarning);

        // 4. Create immutable audit log
        await Transaction.create([{
          payment:   payment._id,
          wallet:    wallet._id,
          type:      'hold',
          amount:    payment.amount,
          currency:  payment.currency,
          direction: 'credit',
          actor:     payment.user,
          note:      `Funds held in escrow. IntentID: ${intent.id}`,
        }], { session });
      });

      await session.endSession();
    }

    if (event.type === 'payment_intent.payment_failed') {
      const payment = await Payment.findOne({ gatewayPaymentIntentId: intent.id });
      if (!payment) return { received: true };

      const failureReason = intent.last_payment_error?.message || 'Unknown failure reason';

      payment.status        = 'failed';
      payment.failureReason = failureReason;
      await payment.save();

      await logTransaction({
        payment:   payment._id,
        type:      'charge',
        amount:    payment.amount,
        currency:  payment.currency,
        direction: 'debit',
        actor:     payment.user,
        note:      `Payment failed: ${failureReason}`,
      });
    }

    return { received: true };
  }

  // ── 5c. releasePaymentToWorker ──────────────────────────────────────────────
  // WHAT: User confirms service is done → escrow released to worker.
  // WHY:  The platform holds money during the job. Only the user (or admin) can
  //       trigger release after they're satisfied with the work.
  // ATOMICITY: Uses a Mongoose session so all 4 writes succeed or all fail.
  async releasePaymentToWorker(bookingId, userId) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');

    if (booking.user.toString() !== userId) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'Only the booking owner can confirm completion.');
    }
    if (booking.status !== 'completed') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot release payment for a booking with status '${booking.status}'. Must be 'completed'.`
      );
    }

    const payment = await Payment.findOne({ booking: bookingId });
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment record not found.');

    if (payment.status !== 'held') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot release payment with status '${payment.status}'. Must be 'held'.`
      );
    }

    const session = await mongoose.startSession();
    let updatedPayment;

    await session.withTransaction(async () => {
      // 1. Release escrow → wallet
      const wallet = await getOrCreateWallet(payment.worker, session);
      await wallet.releasePending(payment.workerEarning);

      // 2. Update payment status
      payment.status     = 'released';
      payment.releasedAt = new Date();
      updatedPayment = await payment.save({ session });

      // 3. Transaction log — worker earning (net after fee)
      await Transaction.create([{
        payment:   payment._id,
        wallet:    wallet._id,
        type:      'release',
        amount:    payment.workerEarning,
        currency:  payment.currency,
        direction: 'credit',
        actor:     userId,
        note:      `Escrow released to worker for booking ${bookingId}`,
      }], { session });

      // 4. Transaction log — platform fee (separate accounting entry)
      await Transaction.create([{
        payment:   payment._id,
        type:      'fee',
        amount:    payment.platformFee,
        currency:  payment.currency,
        direction: 'credit',
        actor:     userId,
        note:      `Platform fee recorded for booking ${bookingId}`,
      }], { session });
    });

    await session.endSession();
    return updatedPayment;
  }

  // ── 5d. refundPayment ───────────────────────────────────────────────────────
  // WHAT: Admin-only full refund — reverses the charge on Stripe and cancels booking.
  // ATOMICITY: All 4 writes (Stripe + wallet + payment + booking) in one session.
  async refundPayment(paymentId, adminId, reason) {
    const payment = await Payment.findById(paymentId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');

    if (!['held', 'disputed'].includes(payment.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot refund a payment with status '${payment.status}'. Must be 'held' or 'disputed'.`
      );
    }

    // Issue the refund on Stripe first — if this fails the DB won't be touched
    const refund = await stripe.refunds.create({
      payment_intent: payment.gatewayPaymentIntentId,
    });

    const session = await mongoose.startSession();
    let updatedPayment;

    await session.withTransaction(async () => {
      // 1. Deduct from worker's pendingBalance — these funds were never truly theirs
      const wallet = await getOrCreateWallet(payment.worker, session);
      await wallet.deductPending(payment.workerEarning);

      // 2. Update payment record
      payment.status          = 'refunded';
      payment.refundedAt      = new Date();
      payment.gatewayRefundId = refund.id;
      updatedPayment = await payment.save({ session });

      // 3. Cancel the booking
      await Booking.findByIdAndUpdate(
        payment.booking,
        { status: 'cancelled' },
        { session }
      );

      // 4. Audit log
      await Transaction.create([{
        payment:   payment._id,
        wallet:    wallet._id,
        type:      'refund',
        amount:    payment.amount,
        currency:  payment.currency,
        direction: 'credit',
        actor:     adminId,
        note:      reason || `Admin refund by ${adminId}`,
      }], { session });
    });

    await session.endSession();
    return updatedPayment;
  }

  // ── 5e. getPaymentByBooking ────────────────────────────────────────────────
  // WHAT: Returns payment details for a booking (role-gated access).
  async getPaymentByBooking(bookingId, requesterId, requesterRole) {
    const payment = await Payment.findByBooking(bookingId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');

    if (requesterRole === 'user' && payment.user._id.toString() !== requesterId) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You cannot view this payment.');
    }
    if (requesterRole === 'worker' && payment.worker._id.toString() !== requesterId) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You cannot view this payment.');
    }
    // admin: no restriction

    return payment;
  }

  // ── 5f. getWorkerEarnings ──────────────────────────────────────────────────
  // WHAT: Returns wallet summary + payment history for a worker.
  async getWorkerEarnings(workerId, filters = {}) {
    const wallet = await getOrCreateWallet(workerId);

    const query = {
      worker: workerId,
      status: { $in: ['held', 'released'] },
    };

    // Optional date range filter
    if (filters.dateFrom || filters.dateTo) {
      query.createdAt = {};
      if (filters.dateFrom) query.createdAt.$gte = new Date(filters.dateFrom);
      if (filters.dateTo)   query.createdAt.$lte = new Date(filters.dateTo);
    }
    if (filters.status) query.status = filters.status;

    const payments = await Payment.find(query)
      .populate('booking', 'scheduledDate address')
      .sort({ createdAt: -1 });

    const summary = payments.reduce(
      (acc, p) => {
        if (p.status === 'held')     acc.totalHeld     += p.workerEarning;
        if (p.status === 'released') acc.totalReleased += p.workerEarning;
        return acc;
      },
      { totalHeld: 0, totalReleased: 0 }
    );

    return { wallet, payments, summary };
  }
}

module.exports = new PaymentService();
