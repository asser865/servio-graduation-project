// ─── Purpose ──────────────────────────────────────────────────────────────────
// auth.service.js contains only business logic — no Express objects (req/res).
// This makes the logic unit-testable in isolation and keeps controllers thin.
// ─────────────────────────────────────────────────────────────────────────────

const crypto         = require('crypto');
const jwt            = require('jsonwebtoken');
const { StatusCodes } = require('http-status-codes');
const User           = require('../users/user.model');
const Service        = require('../services/service.model');
const ApiError       = require('../../utils/ApiError');
const { sendPasswordResetEmail } = require('../../utils/email');

/**
 * GENERATE JWT TOKEN
 * WHAT: Creates a cryptographically signed "Passport" (JWT) for the user.
 * WHY:  Allows the client to stay logged in without sending password every time.
 */
const generateToken = (userId, role, authVersion = 0) => {
  return jwt.sign(
    { id: userId, role, authVersion },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

/**
 * SEED AVAILABILITY
 * WHAT: Generates a weekly availability schedule from the availability type.
 * WHEN: Called after user creation for workers who selected an availability type.
 */
function seedAvailability(type) {
  const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  const WEEKENDS = ['saturday', 'sunday'];
  let days = [];
  if      (type === 'weekdays') days = WEEKDAYS;
  else if (type === 'weekends') days = WEEKENDS;
  else if (type === 'both')     days = [...WEEKDAYS, ...WEEKENDS];
  else                          return [];
  const from = type === 'weekends' ? '10:00' : '09:00';
  const to   = type === 'weekends' ? '15:00' : '17:00';
  return days.map(day => ({ day, from, to }));
}

/**
 * REGISTER NEW USER
 * WHAT: Validates email uniqueness and saves a new user to MongoDB.
 * HOW:  Hashes password automatically via Model pre-save hook.
 */
const registerUser = async (data) => {
  const {
    name,
    email,
    password,
    phone,
    role,
    address,
    locationLabel,
    serviceArea,
    coverageAreas,
    skills,
    hourlyRate,
    bio,
    yearsExperience,
    availabilityType,
    profileImage,
    idFrontUrl,
    idFrontName,
    idBackUrl,
    idBackName,
    idSelfieUrl,
    idSelfieName,
    cvUrl,
    cvName,
    portfolioFiles,
    services,
  } = data;

  // Prevent duplicate accounts — give a clear message instead of letting
  // Mongoose throw a generic duplicate key error.
  const existingUser = await User.findOne({ email });
  if (existingUser) {
    throw new ApiError(StatusCodes.CONFLICT, 'An account with this email already exists.');
  }

  // Automatically map skills to top-level categories if they aren't provided
  let categories = data.categories || [];
  if (categories.length === 0 && skills && Array.from(skills).length > 0) {
    const skillList = Array.isArray(skills) ? skills : Array.from(skills);
    const categoryEnum = [
      'plumbing',
      'electrical',
      'hvac',
      'carpentry',
      'appliance',
      'handyman',
      'renovation',
      'painting',
      'flooring',
      'drywall',
      'roofing',
      'cleaning',
      'pest-control',
      'landscaping',
      'installation',
      'other',
    ];
    const mapping = {
      'plumbing': 'plumbing',
      'electrical': 'electrical',
      'hvac': 'hvac',
      'painting': 'painting',
      'carpentry': 'carpentry',
      'cleaning': 'cleaning',
      'flooring': 'flooring',
      'roofing': 'roofing',
      'appliance-repair': 'appliance',
      'landscaping': 'landscaping',
      'general-maintenance': 'handyman',
    };

    const derived = new Set();
    skillList.forEach(s => {
      const lowerS = s.toLowerCase().trim().replace(/[\s_]+/g, '-');
      if (mapping[lowerS]) {
        derived.add(mapping[lowerS]);
      } else if (categoryEnum.includes(lowerS)) {
        derived.add(lowerS);
      } else {
        derived.add('other');
      }
    });
    categories = Array.from(derived);
  }

  const roleMap = { technician: 'worker', customer: 'user' };
  const normalizedRole = roleMap[role] || role || 'user';
  const isWorker = normalizedRole === 'worker';
  const normalizedCoverageAreas = Array.isArray(coverageAreas)
    ? [...new Set(coverageAreas.map(area => String(area || '').trim()).filter(Boolean))]
    : [];
  const initialServiceArea = serviceArea !== undefined ? serviceArea : locationLabel;

  // Validate submitted service IDs for workers
  let validatedServices = [];
  if (isWorker && Array.isArray(services) && services.length > 0) {
    const count = await Service.countDocuments({ _id: { $in: services }, isActive: true });
    if (count !== services.length) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'One or more selected services are invalid or inactive.');
    }
    validatedServices = services;
  }

  // Password hashing is handled by the pre-save hook in user.model.js
  const user = await User.create({
    name, email, password, phone, address,
    role: normalizedRole,
    isVerified: !isWorker,
    verificationStatus: isWorker ? 'pending' : 'approved',
    ...(isWorker && { verificationSubmittedAt: new Date() }),
    ...(profileImage  !== undefined && { profileImage }),
    // Worker-specific fields (ignored/undefined for customer registrations)
    ...(locationLabel !== undefined && { locationLabel }),
    ...(initialServiceArea !== undefined && { serviceArea: initialServiceArea }),
    ...(normalizedCoverageAreas.length > 0 && { coverageAreas: normalizedCoverageAreas }),
    ...(skills        !== undefined && { skills }),
    ...(categories.length > 0          && { categories }),
    ...(hourlyRate    !== undefined && { hourlyRate }),
    ...(bio           !== undefined && { bio }),
    ...(yearsExperience !== undefined && { yearsExperience }),
    ...(availabilityType !== undefined && { availabilityType }),
    ...(idFrontUrl    !== undefined && { idFrontUrl }),
    ...(idFrontName   !== undefined && { idFrontName }),
    ...(idBackUrl     !== undefined && { idBackUrl }),
    ...(idBackName    !== undefined && { idBackName }),
    ...(idSelfieUrl   !== undefined && { idSelfieUrl }),
    ...(idSelfieName  !== undefined && { idSelfieName }),
    ...(cvUrl         !== undefined && { cvUrl }),
    ...(cvName        !== undefined && { cvName }),
    ...(portfolioFiles !== undefined && { portfolioFiles }),
    ...(isWorker && validatedServices.length > 0 && { services: validatedServices }),
  });

  // Auto-seed weekly availability from availabilityType chosen at signup
  if (isWorker && availabilityType) {
    const seeded = seedAvailability(availabilityType);
    if (seeded.length) {
      await User.findByIdAndUpdate(user._id, { availability: seeded });
      user.availability = seeded;
    }
  }

  const token = generateToken(user._id, user.role, user.authVersion);

  return { user, token };
};

/**
 * LOGIN USER
 * WHAT: Verifies email and password against the database.
 * HOW:  Uses bcrypt.compare to check hashed password. Checks if account is active.
 */
const loginUser = async ({ email, password }) => {
  // Explicitly select password because the schema marks it select: false.
  // We ONLY bring it into memory here, for comparison — never expose it.
  const user = await User.findOne({ email }).select('+password');

  if (!user) {
    // Use the same error for "user not found" and "wrong password" to prevent
    // user enumeration attacks (attacker cannot tell which is wrong).
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Invalid email or password.');
  }

  if (!user.isActive) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Your account has been deactivated. Please contact support.');
  }

  const isMatch = await user.comparePassword(password);
  if (!isMatch) {
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Invalid email or password.');
  }

  const token = generateToken(user._id, user.role, user.authVersion);

  return { user, token };
};

/**
 * FORGOT PASSWORD
 * Generates a secure random token, stores its hash in the user document,
 * and sends a reset link to the user's email.
 */
const forgotPassword = async ({ email, clientUrl }) => {
  const user = await User.findOne({ email }).select('+resetPasswordToken +resetPasswordExpires');
  if (!user) {
    // Return silently — don't reveal whether the email exists (anti-enumeration)
    return { message: 'If that email is registered you will receive a reset link shortly.' };
  }

  // Generate a cryptographically secure token
  const rawToken  = crypto.randomBytes(32).toString('hex');
  const hashToken = crypto.createHash('sha256').update(rawToken).digest('hex');

  user.resetPasswordToken   = hashToken;
  user.resetPasswordExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
  await user.save({ validateModifiedOnly: true });

  const origin   = process.env.FRONTEND_URL || clientUrl || process.env.CLIENT_URL.split(',')[0].trim();
  const resetUrl = `${origin}/html/reset-password.html?token=${rawToken}`;

  await sendPasswordResetEmail(user.email, resetUrl);

  return {
    message: 'If that email is registered you will receive a reset link shortly.',
  };
};

/**
 * RESET PASSWORD
 * Verifies the token, checks expiry, updates the password, and clears the token.
 * Works for ALL roles (user / worker / admin) — the query is role-agnostic.
 */
const resetPassword = async ({ token, password }) => {
  if (!token || !password) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Token and new password are required.');
  }

  const hashToken = crypto.createHash('sha256').update(token).digest('hex');

  const user = await User.findOne({
    resetPasswordToken:   hashToken,
    resetPasswordExpires: { $gt: Date.now() },
  }).select('+password +resetPasswordToken +resetPasswordExpires');

  if (!user) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Password reset link is invalid or has expired.');
  }

  // The pre-save hook in user.model.js re-hashes whenever password is modified
  user.password             = password;
  user.resetPasswordToken   = undefined;
  user.resetPasswordExpires = undefined;
  await user.save({ validateModifiedOnly: true });

  const jwtToken = generateToken(user._id, user.role, user.authVersion);

  return { user, token: jwtToken };
};

module.exports = { registerUser, loginUser, generateToken, forgotPassword, resetPassword };
