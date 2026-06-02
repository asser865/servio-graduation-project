const mongoose = require('mongoose');
const Booking = require('../src/modules/bookings/booking.model');

describe('Booking schema — completion outcome fields', () => {
  it('accepts completionOutcome with valid enum', async () => {
    const b = new Booking({
      user: new mongoose.Types.ObjectId(),
      worker: new mongoose.Types.ObjectId(),
      service: new mongoose.Types.ObjectId(),
      scheduledDate: new Date(),
      totalPrice: 345,
      paymentMethod: 'cash',
      completionOutcome: {
        outcome: 'customer_paid',
        submittedAt: new Date(),
        beforePhotos: ['https://example.com/before.jpg'],
        afterPhotos: ['https://example.com/after.jpg'],
        materialsUsed: 'PVC pipe, sealant',
      },
    });
    const err = b.validateSync();
    expect(err?.errors?.['completionOutcome.outcome']).toBeUndefined();
  });

  it('rejects invalid completionOutcome enum', async () => {
    const b = new Booking({
      user: new mongoose.Types.ObjectId(),
      worker: new mongoose.Types.ObjectId(),
      service: new mongoose.Types.ObjectId(),
      scheduledDate: new Date(),
      totalPrice: 345,
      paymentMethod: 'cash',
      completionOutcome: { outcome: 'banana' },
    });
    const err = b.validateSync();
    expect(err?.errors?.['completionOutcome.outcome']).toBeDefined();
  });

  it('accepts customerFeedback with reported_issue', async () => {
    const b = new Booking({
      user: new mongoose.Types.ObjectId(),
      worker: new mongoose.Types.ObjectId(),
      service: new mongoose.Types.ObjectId(),
      scheduledDate: new Date(),
      totalPrice: 345,
      paymentMethod: 'cash',
      customerFeedback: {
        action: 'reported_issue',
        issueReason: 'work_not_done',
        rating: 1,
        notes: 'Tap still leaks',
        evidenceImages: ['https://example.com/leak.jpg'],
        submittedAt: new Date(),
      },
    });
    const err = b.validateSync();
    expect(err?.errors?.['customerFeedback.action']).toBeUndefined();
    expect(err?.errors?.['customerFeedback.issueReason']).toBeUndefined();
  });
});
