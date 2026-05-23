const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Invoice = require('../invoice.model');
const receiptService = require('../receipt.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function makeInvoice() {
  return Invoice.create({
    number: `INV-2026-${String(Math.floor(Math.random() * 999999)).padStart(6, '0')}`,
    payment: id(),
    booking: id(),
    customer: id(),
    worker: id(),
    subtotal: 1000,
    vatRate: 0.14,
    vat: 140,
    total: 1140,
    currency: 'EGP',
    issuedAt: new Date(),
  });
}

describe('receipt service', () => {
  test('renders PDF to disk and returns path', async () => {
    const inv = await makeInvoice();
    const out = await receiptService.generate(inv);
    expect(out.path).toMatch(/\.pdf$/);
    expect(fs.existsSync(out.path)).toBe(true);
    const stat = fs.statSync(out.path);
    expect(stat.size).toBeGreaterThan(500);
    fs.unlinkSync(out.path);
  });

  test('updates invoice.pdfPath', async () => {
    const inv = await makeInvoice();
    await receiptService.generate(inv);
    const after = await Invoice.findById(inv._id);
    expect(after.pdfPath).toBeTruthy();
    if (fs.existsSync(after.pdfPath)) fs.unlinkSync(after.pdfPath);
  });
});
