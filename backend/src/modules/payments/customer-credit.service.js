const mongoose = require('mongoose');
const CustomerCredit = require('./customer-credit.model');
const AdminAction = require('../admin/admin-action.model');
const ApiError = require('../../utils/ApiError');
const notify = require('../notifications/dispatcher');

async function issueCredit({ customer, amount, source, reason, issuedBy, relatedBooking, relatedPayment, expiresAt, ipAddress }) {
  const session = await mongoose.startSession();
  let credit;
  try {
    credit = await session.withTransaction(async () => {
      const [c] = await CustomerCredit.create([{
        customer, amount, source, reason, issuedBy, relatedBooking, relatedPayment, expiresAt,
      }], { session });

      if (issuedBy && (source === 'apology' || source === 'admin_grant')) {
        try {
          await AdminAction.create([{
            admin: issuedBy,
            actionType: 'credit_issue',
            targetType: 'user',
            targetId: customer,
            details: { amount, source, reason, creditId: c._id, relatedBooking },
            ipAddress,
          }], { session });
        } catch (_) { /* audit failures don't break issuance */ }
      }
      return c;
    });
  } finally { session.endSession(); }

  notify.safeDispatch('credit.issued', {
    customer,
    amount,
    currency: 'EGP',
    reason: reason || source,
    creditId: credit?._id,
  });

  return credit;
}

async function balance(customerId) {
  const credits = await CustomerCredit.find({
    customer: customerId,
    $or: [{ expiresAt: null }, { expiresAt: { $exists: false } }, { expiresAt: { $gt: new Date() } }],
  });
  return credits.reduce((sum, c) => sum + (c.amount - c.consumed), 0);
}

async function listForCustomer(customerId) {
  return CustomerCredit.find({ customer: customerId }).sort({ createdAt: -1 });
}

async function consume(customerId, amount, { booking, session } = {}) {
  if (amount <= 0) return { consumed: 0, details: [] };
  const ownSession = !session;
  if (ownSession) session = await mongoose.startSession();
  try {
    const run = async () => {
      let remaining = amount;
      const credits = await CustomerCredit.find({
        customer: customerId,
        $expr: { $gt: ['$amount', '$consumed'] },
        $or: [{ expiresAt: null }, { expiresAt: { $exists: false } }, { expiresAt: { $gt: new Date() } }],
      }).sort({ expiresAt: 1, createdAt: 1 }).session(session);

      const details = [];
      for (const c of credits) {
        if (remaining <= 0) break;
        const available = c.amount - c.consumed;
        const take = Math.min(available, remaining);
        c.consumed += take;
        if (booking && !c.relatedBooking) c.relatedBooking = booking;
        await c.save({ session });
        details.push({ credit: c._id, amount: take });
        remaining -= take;
      }
      const consumed = amount - remaining;
      if (consumed < amount) throw new ApiError(400, 'Insufficient customer credit');
      return { consumed, details };
    };
    return ownSession ? await session.withTransaction(run) : await run();
  } finally { if (ownSession) session.endSession(); }
}

module.exports = { issueCredit, balance, consume, listForCustomer };
