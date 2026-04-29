// ─── Purpose ──────────────────────────────────────────────────────────────────
// Service represents a type of home maintenance/finishing service that admin
// creates and workers fulfil. The category enum acts as a type-safe taxonomy.
// averageRating and totalReviews are denormalised here for fast reads.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

const SERVICE_CATEGORIES = ['plumbing', 'electrical', 'painting', 'flooring', 'carpentry', 'cleaning', 'hvac', 'other'];
const PRICE_UNITS        = ['per_hour', 'per_sqm', 'fixed'];

const serviceSchema = new mongoose.Schema(
  {
    title: {
      type:      String,
      required:  [true, 'Service title is required'],
      trim:      true,
      maxlength: [150, 'Title cannot exceed 150 characters'],
    },

    description: {
      type:      String,
      required:  [true, 'Service description is required'],
      trim:      true,
      maxlength: [2000, 'Description cannot exceed 2000 characters'],
    },

    titleAr: {
      type:      String,
      trim:      true,
      maxlength: [150, 'Arabic title cannot exceed 150 characters'],
      default:   '',
    },

    descriptionAr: {
      type:      String,
      trim:      true,
      maxlength: [2000, 'Arabic description cannot exceed 2000 characters'],
      default:   '',
    },

    category: {
      type:     String,
      enum:     SERVICE_CATEGORIES,
      required: [true, 'Category is required'],
    },

    basePrice: {
      type:     Number,
      required: [true, 'Base price is required'],
      min:      [0,    'Price cannot be negative'],
    },

    priceUnit: {
      type:     String,
      enum:     PRICE_UNITS,
      required: [true, 'Price unit is required'],
    },

    images: {
      type: [String],
      default: [],
    },

    isActive: {
      type:    Boolean,
      default: true,
    },

    // Admin who created the service catalogue entry
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'User',
      required: true,
    },

    // Denormalised rating — updated via Review post-save hook
    averageRating: {
      type:    Number,
      default: 0,
      min:     0,
      max:     5,
    },

    totalReviews: {
      type:    Number,
      default: 0,
    },
  },
  { timestamps: true }
);

// ── Index for fast category + active filtering ────────────────────────────────
serviceSchema.index({ category: 1, isActive: 1 });

const Service = mongoose.model('Service', serviceSchema);

module.exports = Service;
