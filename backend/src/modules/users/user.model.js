// ─── Purpose ──────────────────────────────────────────────────────────────────
// Central User schema for all three roles: user, worker, admin.
// Using a single collection with a role discriminator is simpler to query and
// manage than separate collections, and role-specific fields are optional so
// they don't pollute documents that don't need them.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

const SALT_ROUNDS = 12; // OWASP recommends ≥12 for bcrypt

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },

    email: {
      type:     String,
      required: [true, 'Email is required'],
      unique:   true,
      lowercase: true,
      trim:     true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email address'],
    },

    phone: {
      type:  String,
      trim:  true,
      match: [/^[+]?[\d\s\-().]{7,20}$/, 'Please provide a valid phone number'],
    },

    address: {
      street: { type: String, trim: true },
      city:   { type: String, trim: true },
      state:  { type: String, trim: true },
      zipCode:{ type: String, trim: true },
    },

    // Never returned in queries by default — use .select('+password') explicitly
    password: {
      type:     String,
      required: [true, 'Password is required'],
      minlength: [8, 'Password must be at least 8 characters'],
      select:   false,
    },

    role: {
      type:    String,
      enum:    ['user', 'worker', 'admin'],
      default: 'user',
    },

    profileImage: {
      type:    String,
      default: null,
    },

    isActive: {
      type:    Boolean,
      default: true,
    },

    authVersion: {
      type:    Number,
      default: 0,
      min:     0,
    },

    // workers must be verified by admin before appearing in listings
    isVerified: {
      type:    Boolean,
      default: false,
    },

    verificationStatus: {
      type:    String,
      enum:    ['pending', 'approved', 'rejected'],
      default: 'approved',
    },

    verificationSubmittedAt: {
      type:    Date,
      default: null,
    },

    verificationReviewedAt: {
      type:    Date,
      default: null,
    },

    verificationReviewedBy: {
      type:    String,
      default: '',
      trim:    true,
    },

    verificationRejectionReason: {
      type:    String,
      default: '',
      trim:    true,
    },

    // ── Worker-specific ──────────────────────────────────────────────────────
    // Categories the worker operates in (mirrors Service.category enum)
    // Kept for backward compatibility — prefer `services` (ObjectId refs) going forward.
    categories: {
      type: [String],
      enum: ['plumbing', 'electrical', 'painting', 'flooring', 'carpentry', 'cleaning', 'hvac', 'other'],
    },

    // Canonical service references — the source of truth for which services this worker offers.
    // Populated from the admin-managed `services` collection.
    services: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref:  'Service',
        },
      ],
      default: [],
    },

    // GeoJSON Point for location-based worker search
    location: {
      type: {
        type:        String,
        enum:        ['Point'],
        default:     'Point',
      },
      coordinates: {
        type:    [Number], // [longitude, latitude]
        default: [0, 0],
      },
    },

    // Computed rating kept in sync by a post-save hook on Review
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

    // Human-readable area/city label for display (e.g. 'Nasr City')
    // Separate from location (GeoJSON) which is used for spatial queries.
    locationLabel: {
      type:  String,
      trim:  true,
      default: '',
    },

    // ── Additional worker profile fields ─────────────────────────────────────
    hourlyRate: {
      type:    Number,
      default: 0,
      min:     [0, 'Hourly rate cannot be negative'],
    },

    // Professional bio / summary
    bio: {
      type:    String,
      trim:    true,
      default: '',
    },

    // Years of professional experience
    yearsExperience: {
      type:    Number,
      default: 0,
      min:     0,
    },

    // Simple availability label: 'weekdays' | 'weekends' | 'both'
    availabilityType: {
      type:    String,
      enum:    ['weekdays', 'weekends', 'both', ''],
      default: '',
    },

    // Specific skills (e.g. ['pipe repair', 'drain cleaning'])
    skills: {
      type:    [String],
      default: [],
    },

    // Incremented each time a booking is marked completed
    completedJobs: {
      type:    Number,
      default: 0,
    },

    // Weekly availability slots stored as { day: 'monday', from: '08:00', to: '18:00' }
    availability: [
      {
        day:  { type: String, enum: ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'] },
        from: { type: String },
        to:   { type: String },
      },
    ],

    // ── Verification document URLs ────────────────────────────────────────────
    // Stored as upload URLs and original filenames for admin review/download.
    idFrontUrl: { type: String, default: '' },
    idFrontName:{ type: String, default: '' },
    idBackUrl:  { type: String, default: '' },
    idBackName: { type: String, default: '' },
    idSelfieUrl:{ type: String, default: '' },
    idSelfieName:{ type: String, default: '' },
    cvUrl:      { type: String, default: '' },
    cvName:     { type: String, default: '' },
    portfolioFiles: {
      type: [
        new mongoose.Schema(
          {
            url:  { type: String, required: true },
            name: { type: String, default: '' },
          },
          { _id: false }
        ),
      ],
      default: [],
    },

    // ── Password reset ────────────────────────────────────────────────────────
    resetPasswordToken: {
      type:   String,
      select: false,
    },
    resetPasswordExpires: {
      type:   Date,
      select: false,
    },

  },
  {
    timestamps: true, // adds createdAt, updatedAt automatically
  }
);

// ── Geospatial index ──────────────────────────────────────────────────────────
// Required for $near and $geoWithin queries used in worker search.
userSchema.index({ location: '2dsphere' });

// ── Service index ─────────────────────────────────────────────────────────────
// Speeds up worker-discovery queries filtered by a specific service ID.
userSchema.index({ services: 1 });

// ── Pre-save hook — password hashing ─────────────────────────────────────────
// Only re-hash if the password field was actually modified (prevents double
// hashing on save calls that only update, e.g., isActive).
// In Mongoose v7+, async pre-hooks resolve via the returned promise.
// Do NOT accept or call next() — doing so throws "next is not a function".
userSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  this.password = await bcrypt.hash(this.password, SALT_ROUNDS);
});

// ── Instance method — password comparison ────────────────────────────────────
// Using bcrypt.compare instead of plain equality to guard against timing attacks.
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// ── toJSON transform — strip sensitive fields ─────────────────────────────────
// Belt-and-suspenders: even if password is accidentally fetched, strip it from
// any JSON serialisation so it never appears in API responses.
userSchema.set('toJSON', {
  transform(doc, ret) {
    delete ret.password;
    delete ret.__v;
    return ret;
  },
});

const User = mongoose.model('User', userSchema);

module.exports = User;
