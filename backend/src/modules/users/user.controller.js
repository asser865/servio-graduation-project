// ─── Purpose ──────────────────────────────────────────────────────────────────
// User controller handles worker discovery, profile management, and all admin
// actions on user accounts. Analytics is computed here so we have a single
// aggregation endpoint rather than multiple counting endpoints.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const User            = require('./user.model');
const Review          = require('../reviews/review.model');
const Booking         = require('../bookings/booking.model');
const ApiError        = require('../../utils/ApiError');
const ApiResponse     = require('../../utils/ApiResponse');

// ── GET WORKERS (Public) ─────────────────────────────────────────────────────
// WHAT: Returns a list of all active and verified workers.
// HOW:  Optional ?category filter. Supports pagination (?page, ?limit).
const getWorkers = async (req, res) => {
  const { category, page = 1, limit = 10 } = req.query;

  const filter = { role: 'worker', isActive: true, isVerified: true };
  // Workers can belong to multiple categories — use $in for array field
  if (category) filter.categories = { $in: [category] };

  const skip = (Number(page) - 1) * Number(limit);

  const [workers, total] = await Promise.all([
    User.find(filter)
      .select('name profileImage categories averageRating totalReviews location')
      .sort({ averageRating: -1 })
      .skip(skip)
      .limit(Number(limit)),
    User.countDocuments(filter),
  ]);

  return ApiResponse.success(res, StatusCodes.OK, 'Workers retrieved successfully.', {
    workers,
    pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) },
  });
};

// ── GET WORKER PROFILE (Public) ──────────────────────────────────────────────
// WHAT: Returns full details for one worker plus their 10 most recent reviews.
// HOW:  GET /api/v1/users/workers/:id
const getWorkerProfile = async (req, res) => {
  const worker = await User.findOne({ _id: req.params.id, role: 'worker' })
    .select('-password');

  if (!worker) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found.');
  }

  // Fetch the worker's reviews to embed in the profile response
  const reviews = await Review.find({ worker: worker._id })
    .populate('user', 'name profileImage')
    .sort({ createdAt: -1 })
    .limit(10);

  return ApiResponse.success(res, StatusCodes.OK, 'Worker profile retrieved.', { worker, reviews });
};

// ── UPDATE OWN PROFILE (Authenticated) ───────────────────────────────────────
// WHAT: Allows any logged-in user to update their name, phone, or photo.
// HOW:  PATCH /api/v1/users/me
const updateProfile = async (req, res) => {
  // Prevent users from changing their role via this endpoint
  const allowedFields = ['name', 'phone', 'profileImage'];
  const updates = {};
  allowedFields.forEach((field) => {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  });

  const user = await User.findByIdAndUpdate(req.user.id, updates, {
    new: true, runValidators: true,
  });

  return ApiResponse.success(res, StatusCodes.OK, 'Profile updated successfully.', user);
};

// ── UPDATE WORKER AVAILABILITY (Worker Only) ──────────────────────────────────
// WHAT: Allows workers to set their weekly schedule days/times.
// HOW:  PATCH /api/v1/users/me/availability
const updateAvailability = async (req, res) => {
  const user = await User.findByIdAndUpdate(
    req.user.id,
    { availability: req.body.availability },
    { new: true, runValidators: true }
  );
  return ApiResponse.success(res, StatusCodes.OK, 'Availability updated.', user);
};

// ── GET ALL USERS (Admin Only) ───────────────────────────────────────────────
// WHAT: Returns a list of all users in the system.
// HOW:  Optional ?role filter. Supports pagination.
const getAllUsers = async (req, res) => {
  const { role, page = 1, limit = 20 } = req.query;
  const filter = {};
  if (role) filter.role = role;

  const skip = (Number(page) - 1) * Number(limit);
  const [users, total] = await Promise.all([
    User.find(filter).sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
    User.countDocuments(filter),
  ]);

  return ApiResponse.success(res, StatusCodes.OK, 'Users retrieved.', {
    users,
    pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) },
  });
};

// ── UPDATE USER STATUS (Admin Only) ──────────────────────────────────────────
// WHAT: Enables or disables a user account (banning/unbanning).
// HOW:  PATCH /api/v1/users/:id/status { "isActive": false }
const updateUserStatus = async (req, res) => {
  const { isActive } = req.body;
  if (typeof isActive !== 'boolean') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'isActive must be a boolean.');
  }

  const user = await User.findByIdAndUpdate(
    req.params.id,
    { isActive },
    { new: true }
  );
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');

  return ApiResponse.success(res, StatusCodes.OK, `User ${isActive ? 'activated' : 'deactivated'}.`, user);
};

// ── VERIFY WORKER (Admin Only) ────────────────────────────────────────────────
// WHAT: Approves a worker so they can appear in search and receive bookings.
// HOW:  PATCH /api/v1/users/workers/:id/verify { "isVerified": true }
const verifyWorker = async (req, res) => {
  const { isVerified } = req.body;
  if (typeof isVerified !== 'boolean') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'isVerified must be a boolean.');
  }

  const worker = await User.findOneAndUpdate(
    { _id: req.params.id, role: 'worker' },
    { isVerified },
    { new: true }
  );
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found.');

  return ApiResponse.success(res, StatusCodes.OK, `Worker ${isVerified ? 'approved' : 'rejected'}.`, worker);
};

// ── GET ANALYTICS (Admin Only) ────────────────────────────────────────────────
// WHAT: Returns counts of users, workers, and bookings by status.
// HOW:  GET /api/v1/users/analytics
const getAnalytics = async (req, res) => {
  // Run all aggregations in parallel for speed
  const [
    totalUsers,
    totalWorkers,
    totalAdmins,
    bookingStats,
  ] = await Promise.all([
    User.countDocuments({ role: 'user' }),
    User.countDocuments({ role: 'worker' }),
    User.countDocuments({ role: 'admin' }),
    Booking.aggregate([
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),
  ]);

  // Convert bookingStats array to a readable key-value object
  const bookingsByStatus = bookingStats.reduce((acc, item) => {
    acc[item._id] = item.count;
    return acc;
  }, {});

  return ApiResponse.success(res, StatusCodes.OK, 'Analytics retrieved.', {
    users:     totalUsers,
    workers:   totalWorkers,
    admins:    totalAdmins,
    bookings:  bookingsByStatus,
  });
};

module.exports = {
  getWorkers,
  getWorkerProfile,
  updateProfile,
  updateAvailability,
  getAllUsers,
  updateUserStatus,
  verifyWorker,
  getAnalytics,
};
