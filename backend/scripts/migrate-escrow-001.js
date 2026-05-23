require('dotenv').config();
const mongoose = require('mongoose');
const Booking = require('../src/modules/bookings/booking.model');
const Payment = require('../src/modules/payments/payment.model');
const settings = require('../src/modules/admin/admin-settings.service');
const auditService = require('../src/modules/admin/admin-action.service');

async function run() {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGO_URI not set');
  await mongoose.connect(uri);

  const cfg = await settings.get();
  const autoH = cfg.escrow?.autoConfirmHours ?? 72;

  const completed = await Booking.find({ status: 'completed', completedAt: { $exists: false } });
  for (const b of completed) {
    const p = await Payment.findOne({ booking: b._id, status: 'released' });
    if (p?.releasedAt) {
      b.completedAt = p.releasedAt;
      b.releasedAt = p.releasedAt;
      await b.save();
    }
  }

  const awaiting = await Booking.find({
    status: 'awaiting_customer_confirmation',
    customerConfirmAutoAt: { $exists: false },
  });
  for (const b of awaiting) {
    b.customerConfirmAutoAt = new Date(b.createdAt.getTime() + autoH * 3600 * 1000);
    await b.save();
  }

  try {
    await auditService.record({
      adminId: null,
      actionType: 'system_migration',
      targetType: 'booking',
      targetId: new mongoose.Types.ObjectId(),
      details: { migration: 'escrow-001', completed: completed.length, awaiting: awaiting.length },
    });
  } catch (e) {
    console.warn('audit record skipped:', e.message);
  }

  console.log(`Migration complete: completed=${completed.length}, awaiting=${awaiting.length}`);
  await mongoose.disconnect();
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
