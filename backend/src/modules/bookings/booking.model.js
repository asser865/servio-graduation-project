// ─── Purpose ──────────────────────────────────────────────────────────────────
// Booking is the core transactional record — it links a user, a worker,
// and a service with a lifecycle managed by the status enum.
// The status machine is enforced in booking.service.js, not the schema.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

const BOOKING_STATUSES = ['pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'disputed'];

const bookingSchema = new mongoose.Schema(
  {
    user: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'User is required'],
    },

    worker: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'Worker is required'],
    },

    service: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Service',
      required: [true, 'Service is required'],
    },

    status: {
      type:    String,
      enum:    BOOKING_STATUSES,
      default: 'pending',
    },

    scheduledDate: {
      type:     Date,
      required: [true, 'Scheduled date is required'],
    },

    address: {
      type:     String,
      required: [true, 'Address is required'],
      trim:     true,
    },

    description: {
      type:  String,
      trim:  true,
      maxlength: [1000, 'Description cannot exceed 1000 characters'],
    },

    images: {
      type:    [String],
      default: [],
    },

    totalPrice: {
      type:  Number,
      min:   [0, 'Price cannot be negative'],
    },

    scheduledTime: {
      type:    String,
      trim:    true,
      default: '',
    },

    // Worker can add notes on completion (e.g., materials used)
    workerNotes: {
      type:  String,
      trim:  true,
    },

    // Required when status is cancelled or rejected
    cancellationReason: {
      type:  String,
      trim:  true,
    },
  },
  { timestamps: true }
);

// ── Indexes for common queries ────────────────────────────────────────────────
bookingSchema.index({ user:   1, status: 1 });
bookingSchema.index({ worker: 1, status: 1 });

const Booking = mongoose.model('Booking', bookingSchema);

module.exports = Booking;
