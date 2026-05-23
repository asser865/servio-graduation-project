const mongoose = require('mongoose');
const Invoice = require('./invoice.model');
const Counter = require('../../utils/counter.model');
const { money } = require('../../utils/rounding');

async function nextInvoiceNumber(year, session) {
  const doc = await Counter.findOneAndUpdate(
    { key: `invoice:${year}` },
    { $inc: { seq: 1 } },
    { upsert: true, new: true, session }
  );
  return `INV-${year}-${String(doc.seq).padStart(6, '0')}`;
}

async function create({ payment, booking, customer, worker, subtotal, vatRate = 0.14, currency = 'EGP', session: providedSession }) {
  const ownSession = !providedSession;
  const session = providedSession || await mongoose.startSession();
  try {
    const run = async () => {
      const year = new Date().getFullYear();
      const number = await nextInvoiceNumber(year, session);
      const vat = money(subtotal * vatRate);
      const total = money(subtotal + vat);
      const [doc] = await Invoice.create([{
        number, payment, booking, customer, worker, subtotal, vatRate, vat, total, currency,
      }], { session });
      return doc;
    };
    return ownSession ? await session.withTransaction(run) : await run();
  } finally { if (ownSession) session.endSession(); }
}

async function findForCustomer(customerId) {
  return Invoice.find({ customer: customerId }).sort({ createdAt: -1 });
}

async function findForWorker(workerId) {
  return Invoice.find({ worker: workerId }).sort({ createdAt: -1 });
}

async function findByPayment(paymentId) {
  return Invoice.findOne({ payment: paymentId });
}

module.exports = { create, findForCustomer, findForWorker, findByPayment, nextInvoiceNumber };
