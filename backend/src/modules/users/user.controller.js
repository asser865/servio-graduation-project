// ─── Purpose ──────────────────────────────────────────────────────────────────
// User controller handles worker discovery, profile management, and all admin
// actions on user accounts. Analytics is computed here so we have a single
// aggregation endpoint rather than multiple counting endpoints.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const User            = require('./user.model');
const Review          = require('../reviews/review.model');
const Booking         = require('../bookings/booking.model');
const Payment         = require('../payments/payment.model');
const Dispute         = require('../payments/dispute.model');
const Service         = require('../services/service.model');
const ApiError        = require('../../utils/ApiError');
const ApiResponse     = require('../../utils/ApiResponse');
const { logEvent }    = require('../admin/audit.service');
const { dispatchAvailabilityMatches } = require('../notifications/notify.service');

function normalizeWorkerDecision(body) {
  if (body?.decision === 'approved' || body?.isVerified === true) return 'approved';
  if (body?.decision === 'rejected' || body?.isVerified === false) return 'rejected';
  return '';
}
const getMe = async (req, res) => {
  const user = await User.findById(req.user.id).select('-password');
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');
  return ApiResponse.success(res, StatusCodes.OK, 'Profile retrieved.', user);
};


// ── GET WORKERS (Public) ─────────────────────────────────────────────────────
// WHAT: Returns a list of all active and verified workers.
// HOW:  Optional ?serviceId (canonical) or ?category (legacy) filter.
//       serviceId takes priority when both are provided.
const getWorkers = async (req, res) => {
  const { serviceId, category, page = 1, limit = 10 } = req.query;

  const filter = {
    role:     'worker',
    isActive: true,
    isVerified: true,
    isAvailable: true,
    'availability.0': { $exists: true },
  };

  if (serviceId) {
    // Canonical filter: match workers whose services array contains this ObjectId
    filter.services = serviceId;
  } else if (category) {
    // Legacy filter: keep backward compatibility with category string filter
    filter.categories = { $in: [category] };
  }

  const skip = (Number(page) - 1) * Number(limit);

  const [workers, total] = await Promise.all([
    User.find(filter)
      .select('name profileImage categories services skills averageRating totalReviews location locationLabel hourlyRate isVerified isAvailable serviceArea availability completedJobs yearsExperience bio')
      .populate('services', 'title category')
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
    .select('-password')
    .populate('services', 'title category basePrice priceUnit description');

  if (!worker) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found.');
  }

  // Hide services from categories not yet approved by admin
  const pendingCats = worker.pendingCategories || [];
  if (pendingCats.length && Array.isArray(worker.services)) {
    worker.services = worker.services.filter(s => !pendingCats.includes(s.category));
  }

  // Fetch the worker's reviews to embed in the profile response
  const reviews = await Review.find({ worker: worker._id })
    .populate('user', 'name profileImage')
    .sort({ createdAt: -1 })
    .limit(10);

  return ApiResponse.success(res, StatusCodes.OK, 'Worker profile retrieved.', { worker, reviews });
};

// ── UPDATE OWN PROFILE (Authenticated) ───────────────────────────────────────
// WHAT: Allows any logged-in user to update non-sensitive profile details.
// HOW:  PATCH /api/v1/users/me
const updateProfile = async (req, res) => {
  // Prevent users from changing their role via this endpoint
  const allowedFields = [
    'name',
    'bio',
    'phone',
    'profileImage',
    'address',
    'locationLabel',
    'hourlyRate',
    'skills',
    'yearsExperience',
    'availabilityType',
    'categories',
    'services',
    'isAvailable',
    'serviceArea',
    'idFrontUrl',
    'idFrontName',
    'idBackUrl',
    'idBackName',
    'idSelfieUrl',
    'idSelfieName',
    'cvUrl',
    'cvName',
    'portfolioFiles',
  ];
  const updates = {};
  allowedFields.forEach((field) => {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  });

  // Only workers may update their service assignments
  if (updates.services !== undefined && req.user?.role !== 'worker') {
    delete updates.services;
  }
  // Workers cannot self-update categories — handled via pendingCategories approval flow
  if (updates.categories !== undefined && req.user?.role === 'worker') {
    delete updates.categories;
  }

  const user = await User.findById(req.user.id);
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');

  // Validate submitted service IDs for workers
  if (updates.services !== undefined && Array.isArray(updates.services) && updates.services.length > 0) {
    const count = await Service.countDocuments({ _id: { $in: updates.services }, isActive: true });
    if (count !== updates.services.length) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'One or more selected services are invalid or inactive.');
    }
  }

  if (req.user?.role === 'worker') {
    const verificationFields = [
      'idFrontUrl',
      'idFrontName',
      'idBackUrl',
      'idBackName',
      'idSelfieUrl',
      'idSelfieName',
      'cvUrl',
      'cvName',
      'portfolioFiles',
    ];
    const touchedVerification = verificationFields.some((field) => req.body[field] !== undefined);
    if (touchedVerification) {
      updates.isVerified = false;
      updates.verificationStatus = 'pending';
      updates.verificationSubmittedAt = new Date();
      updates.verificationReviewedAt = null;
      updates.verificationReviewedBy = '';
      updates.verificationRejectionReason = '';
    }
  }

  Object.entries(updates).forEach(([field, value]) => {
    user.set(field, value);
  });

  try {
    await user.save({ validateModifiedOnly: true });
  } catch (err) {
    if (err.code === 11000 && (err.keyPattern?.email || err.keyValue?.email)) {
      throw new ApiError(StatusCodes.CONFLICT, 'An account with this email already exists.');
    }
    throw err;
  }

  // Detect new categories in submitted services and route to pendingCategories
  if (req.user?.role === 'worker' && Array.isArray(updates.services) && updates.services.length > 0) {
    const svcDocs      = await Service.find({ _id: { $in: updates.services } }).select('category');
    const requestedCats = [...new Set(svcDocs.map(s => s.category).filter(Boolean))];
    const verifiedCats  = user.categories || [];
    const alreadyPending = user.pendingCategories || [];
    const newPending    = requestedCats.filter(c => !verifiedCats.includes(c) && !alreadyPending.includes(c));
    if (newPending.length) {
      await User.findByIdAndUpdate(user._id, { $addToSet: { pendingCategories: { $each: newPending } } });
      user.pendingCategories = [...alreadyPending, ...newPending];
    }
  }

  return ApiResponse.success(res, StatusCodes.OK, 'Profile updated successfully.', user);
};

// ── UPDATE OWN EMAIL (Authenticated) ─────────────────────────────────────────
// WHAT: Isolated sensitive flow for changing email.
// HOW:  Verifies current password, relies on the unique email index, then
// atomically updates email + authVersion so the current JWT is invalidated.
const updateEmail = async (req, res) => {
  const requestedEmail = String(req.body.newEmail || '').trim().toLowerCase();
  const currentPassword = String(req.body.currentPassword || '');

  if (!requestedEmail || !currentPassword) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'New email and current password are required.');
  }

  const user = await User.findById(req.user.id).select('+password email authVersion');
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');

  if (requestedEmail === user.email) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'New email must be different from your current email.');
  }

  const passwordMatches = await user.comparePassword(currentPassword);
  if (!passwordMatches) {
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Incorrect current password.');
  }

  const existingUser = await User.findOne({
    email: requestedEmail,
    _id: { $ne: user._id },
  }).select('_id');
  if (existingUser) {
    throw new ApiError(StatusCodes.CONFLICT, 'An account with this email already exists.');
  }

  let updatedUser;
  try {
    updatedUser = await User.findOneAndUpdate(
      { _id: user._id, email: user.email },
      {
        $set: { email: requestedEmail },
        $inc: { authVersion: 1 },
      },
      { new: true, runValidators: true }
    );
  } catch (err) {
    if (err.code === 11000 && (err.keyPattern?.email || err.keyValue?.email)) {
      throw new ApiError(StatusCodes.CONFLICT, 'An account with this email already exists.');
    }
    throw err;
  }

  if (!updatedUser) {
    throw new ApiError(StatusCodes.CONFLICT, 'Email could not be updated because the profile changed. Please reload and try again.');
  }

  logEvent({
    req,
    type: 'user',
    action: 'User email updated',
    target: requestedEmail,
    actorEmail: requestedEmail,
  });

  return ApiResponse.success(res, StatusCodes.OK, 'Email updated successfully. Please log in again using your new email address.', {
    email: updatedUser.email,
    reauthRequired: true,
  });
};

// ── TOGGLE AVAILABLE NOW (Worker Only) ──────────────────────────────────────
// WHAT: Immediately flips the worker's isAvailable flag.
// HOW:  PATCH /api/v1/users/me/available  { "isAvailable": true | false }
const toggleAvailableNow = async (req, res) => {
  const { isAvailable } = req.body;
  if (typeof isAvailable !== 'boolean') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'isAvailable must be a boolean.');
  }
  const user = await User.findByIdAndUpdate(
    req.user.id,
    { isAvailable },
    { new: true, runValidators: true }
  );
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');

  if (isAvailable) {
    const baseUrl = process.env.FRONTEND_URL || 'http://127.0.0.1:5502/temp_repo/servio_frontend';
    dispatchAvailabilityMatches(user, baseUrl).catch(err =>
      console.error('[notify] dispatchAvailabilityMatches error:', err.message)
    );
  }

  return ApiResponse.success(res, StatusCodes.OK, `Availability ${isAvailable ? 'enabled' : 'disabled'}.`, { isAvailable: user.isAvailable });
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

// ── UPDATE PASSWORD (Authenticated) ──────────────────────────────────────────
// WHAT: Allows any logged-in user to change their password safely.
// HOW:  PATCH /api/v1/users/me/password
const updatePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Please provide both current and new passwords.');
  }

  const passwordRegex = /^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;
  if (!passwordRegex.test(newPassword)) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      'New password must be at least 8 characters and include a letter, a number, and a special character.'
    );
  }

  const user = await User.findById(req.user.id).select('+password');
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');

  const isMatch = await user.comparePassword(currentPassword);
  if (!isMatch) {
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Incorrect current password.');
  }

  const isSameAsOld = await user.comparePassword(newPassword);
  if (isSameAsOld) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'New password must be different from your current password.');
  }

  user.password = newPassword;
  user.authVersion = (user.authVersion ?? 0) + 1;
  await user.save();

  return ApiResponse.success(res, StatusCodes.OK, 'Password updated successfully.', undefined);
};

// ── DELETE OWN ACCOUNT (Authenticated) ───────────────────────────────────────
// WHAT: Permanently removes a user's own account from the system.
// HOW:  DELETE /api/v1/users/me
const deleteMe = async (req, res) => {
  const user = await User.findByIdAndDelete(req.user.id);
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');
  return ApiResponse.success(res, StatusCodes.OK, 'Your account has been successfully deleted.');
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

  logEvent({ req, type: 'user', action: isActive ? 'User activated' : 'User suspended', target: user.email });

  return ApiResponse.success(res, StatusCodes.OK, `User ${isActive ? 'activated' : 'deactivated'}.`, user);
};

// ── VERIFY WORKER (Admin Only) ────────────────────────────────────────────────
// WHAT: Approves a worker so they can appear in search and receive bookings.
// HOW:  PATCH /api/v1/users/workers/:id/verify { "isVerified": true }
const verifyWorker = async (req, res) => {
  const decision = normalizeWorkerDecision(req.body);
  const rejectionReason = String(req.body?.rejectionReason || '').trim();
  if (!decision) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A review decision is required.');
  }
  if (decision === 'rejected' && !rejectionReason) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A rejection reason is required.');
  }

  const worker = await User.findOneAndUpdate(
    { _id: req.params.id, role: 'worker' },
    {
      isVerified: decision === 'approved',
      verificationStatus: decision,
      verificationReviewedAt: new Date(),
      verificationReviewedBy: req.user?.email || '',
      verificationRejectionReason: decision === 'rejected' ? rejectionReason : '',
    },
    { new: true }
  );
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found.');

  logEvent({
    req,
    type: 'user',
    action: decision === 'approved' ? 'Technician approved' : `Technician rejected: ${rejectionReason}`,
    target: worker.email,
    status: decision === 'approved' ? 'ok' : 'warn',
  });

  return ApiResponse.success(res, StatusCodes.OK, `Worker ${decision}.`, worker);
};

// ── APPROVE WORKER CATEGORY (Admin Only) ─────────────────────────────────────
// WHAT: Moves a category from pendingCategories → categories so the worker can
//       appear in listings and accept bookings for that category.
// HOW:  PATCH /api/v1/users/workers/:id/approve-category  { category: 'electrical' }
const approveWorkerCategory = async (req, res) => {
  const { category } = req.body;
  if (!category) throw new ApiError(StatusCodes.BAD_REQUEST, 'Category is required.');

  const worker = await User.findOneAndUpdate(
    { _id: req.params.id, role: 'worker', pendingCategories: category },
    {
      $pull:     { pendingCategories: category },
      $addToSet: { categories: category },
    },
    { new: true }
  );
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or category not pending.');

  logEvent({ req, type: 'user', action: `Category approved: ${category}`, target: worker.email });
  return ApiResponse.success(res, StatusCodes.OK, `Category '${category}' approved.`, worker);
};

// ── DELETE USER (Admin Only) ──────────────────────────────────────────────────
// WHAT: Permanently removes a user from the system.
// HOW:  DELETE /api/v1/users/:id
const deleteUser = async (req, res) => {
  const user = await User.findByIdAndDelete(req.params.id);
  if (!user) throw new ApiError(StatusCodes.NOT_FOUND, 'User not found.');

  logEvent({ req, type: 'user', action: 'User account deleted', target: user.email, status: 'warn' });

  return ApiResponse.success(res, StatusCodes.OK, 'User deleted successfully.');
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

// ── GET PAYMENT ANALYTICS (Admin Only) ────────────────────────────────────────
// WHAT: Financial dashboard for admins — revenue, escrow, refunds, disputes.
// HOW:  GET /api/v1/users/analytics/payments
const getPaymentAnalytics = async (req, res) => {
  const twelveMonthsAgo = new Date();
  twelveMonthsAgo.setMonth(twelveMonthsAgo.getMonth() - 12);

  const [
    revenueResult,
    totalEscrow,
    totalRefunded,
    totalDisputes,
    openDisputes,
    paymentStatusStats,
    revenueByMonth,
  ] = await Promise.all([
    // Sum of all platform fees from released payments (actual revenue)
    Payment.aggregate([
      { $match: { status: 'released' } },
      { $group: { _id: null, total: { $sum: '$platformFee' } } },
    ]),
    // Total funds currently held in escrow
    Payment.aggregate([
      { $match: { status: { $in: ['held', 'disputed'] } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
    // Total refunded amount
    Payment.aggregate([
      { $match: { status: 'refunded' } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
    Dispute.countDocuments({}),
    Dispute.countDocuments({ status: 'open' }),
    // Payment count grouped by status
    Payment.aggregate([
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),
    // Monthly revenue (platform fee) for last 12 months
    Payment.aggregate([
      { $match: { status: 'released', createdAt: { $gte: twelveMonthsAgo } } },
      {
        $group: {
          _id:     { year: { $year: '$createdAt' }, month: { $month: '$createdAt' } },
          revenue: { $sum: '$platformFee' },
          count:   { $sum: 1 },
        },
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]),
  ]);

  const paymentsByStatus = paymentStatusStats.reduce((acc, item) => {
    acc[item._id] = item.count;
    return acc;
  }, {});
  return ApiResponse.success(res, StatusCodes.OK, 'Payment analytics retrieved.', {
    totalRevenue:    revenueResult[0]?.total  || 0,
    totalEscrow:     totalEscrow[0]?.total    || 0,
    totalRefunded:   totalRefunded[0]?.total  || 0,
    totalDisputes,
    openDisputes,
    paymentsByStatus,
    revenueByMonth,
  });
};

const toggleBlockedDate = async (req, res) => {
  const { date } = req.body;
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid date format. Use YYYY-MM-DD.');
  }
  const user = await User.findById(req.user.id);
  const idx  = (user.blockedDates || []).indexOf(date);
  if (idx === -1) {
    user.blockedDates.push(date);
  } else {
    user.blockedDates.splice(idx, 1);
  }
  await user.save();
  return ApiResponse.success(res, StatusCodes.OK, 'Blocked dates updated.', { blockedDates: user.blockedDates });
};

module.exports = {
  getWorkers,
  getWorkerProfile,
  getMe,
  deleteMe,
  updateProfile,
  updateEmail,
  toggleAvailableNow,
  toggleBlockedDate,
  updateAvailability,
  updatePassword,
  getAllUsers,
  updateUserStatus,
  verifyWorker,
  approveWorkerCategory,
  deleteUser,
  getAnalytics,
  getPaymentAnalytics,
};
