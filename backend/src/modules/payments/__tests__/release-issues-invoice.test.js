const fs = require('fs');
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Payment = require('../payment.model');
const Booking = require('../../bookings/booking.model');
const SavedCard = require('../../savedCards/savedCard.model');
const Invoice = require('../invoice.model');
const service = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function holdAndApprove() {
  const user = id(), worker = id();
  const card = await SavedCard.create({ userId: user, last4: '4242', expiry: '12/30', cardType: 'visa' });
  const booking = await Booking.create({
    user, worker, service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: 'x',
    status: 'pending',
    paymentMethod: 'online',
    estimatedTotal: 1140, totalPrice: 1000, platformFeeAmount: 140,
  });
  await service.holdPayment(booking._id, user, { savedCardId: card._id });
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
  });
  await service.adminApproveCompletion(booking._id, id());
  return { booking };
}

describe('release auto-issues invoice', () => {
  test('writes Invoice with VAT 14% breakdown', async () => {
    const { booking } = await holdAndApprove();
    const payment = await Payment.findOne({ booking: booking._id });
    const invoice = await Invoice.findOne({ payment: payment._id });
    expect(invoice).toBeTruthy();
    expect(invoice.vatRate).toBe(0.14);
    expect(invoice.total).toBe(1140);
    expect(invoice.subtotal).toBeCloseTo(1000, 0);
    expect(invoice.number).toMatch(/^INV-\d{4}-\d{6}$/);
  });

  test('eventually creates PDF receipt file', async () => {
    const { booking } = await holdAndApprove();
    const payment = await Payment.findOne({ booking: booking._id });
    await new Promise(r => setTimeout(r, 500));
    const invoice = await Invoice.findOne({ payment: payment._id });
    expect(invoice.pdfPath).toBeTruthy();
    expect(fs.existsSync(invoice.pdfPath)).toBe(true);
    if (fs.existsSync(invoice.pdfPath)) fs.unlinkSync(invoice.pdfPath);
  });
});
