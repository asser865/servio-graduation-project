const { Router } = require('express');
const { body } = require('express-validator');
const mongoose = require('mongoose');
const userController = require('./user.controller');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');
const { validate } = require('../../middleware/validate.middleware');

const router = Router();

const profileUpdateValidation = [
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty'),
  body('phone').optional().trim().matches(/^[+]?[\d\s\-().]{7,20}$/).withMessage('Invalid phone number'),
  body('profileImage').optional().isURL().withMessage('Profile image must be a valid URL'),
  body('address').optional().isObject().withMessage('Address must be an object'),
  body('address.street').optional().trim().isLength({ max: 200 }).withMessage('Street cannot exceed 200 characters'),
  body('address.city').optional().trim().isLength({ max: 100 }).withMessage('City cannot exceed 100 characters'),
  body('address.state').optional().trim().isLength({ max: 100 }).withMessage('State cannot exceed 100 characters'),
  body('address.zipCode').optional().trim().isLength({ max: 30 }).withMessage('Zip code cannot exceed 30 characters'),
  body('bio').optional().trim().isLength({ max: 1000 }).withMessage('Bio cannot exceed 1000 characters'),
  body('hourlyRate').optional().isFloat({ min: 0 }).withMessage('Hourly rate must be a non-negative number'),
  body('locationLabel').optional().trim().isLength({ max: 200 }).withMessage('Location label too long'),
  body('yearsExperience').optional().isInt({ min: 0 }).withMessage('Years of experience must be a non-negative integer'),
  body('availabilityType').optional().isIn(['weekdays', 'weekends', 'both', '']).withMessage('Invalid availability type'),
  body('coverageAreas').optional().isArray().withMessage('Coverage areas must be an array'),
  body('coverageAreas.*').optional().isString().trim().notEmpty().isLength({ max: 100 }).withMessage('Each coverage area must be a non-empty string up to 100 characters'),
  body('skills').optional().isArray().withMessage('Skills must be an array'),
  body('skills.*').optional().isString().trim().notEmpty().withMessage('Each skill must be a non-empty string'),
  body('categories').optional().isArray().withMessage('Categories must be an array'),
  body('categories.*').optional().isIn([
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
  ]).withMessage('Invalid category'),
  // Accepts either the legacy flat shape (array of service ObjectIds) or the
  // canonical [{ serviceId, startsFrom }] subdoc shape used for per-worker pricing.
  body('services').optional().isArray().withMessage('Services must be an array'),
  body('services.*')
    .optional()
    .custom((entry) => {
      if (typeof entry === 'string') {
        return mongoose.Types.ObjectId.isValid(entry);
      }
      if (entry && typeof entry === 'object') {
        return mongoose.Types.ObjectId.isValid(entry.serviceId);
      }
      return false;
    })
    .withMessage('Each service must be a valid MongoDB ObjectId, or an object with a valid serviceId'),
  body('services.*.startsFrom')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('startsFrom must be a non-negative number'),
];

const emailUpdateValidation = [
  body('newEmail')
    .trim()
    .notEmpty().withMessage('New email is required')
    .isEmail().withMessage('Invalid email address')
    .normalizeEmail(),
  body('currentPassword')
    .isString()
    .notEmpty().withMessage('Current password is required'),
];

const availabilityValidation = [
  body('availability').isArray().withMessage('Availability must be an array'),
  body('availability.*.day')
    .isIn(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'])
    .withMessage('Invalid day'),
  body('availability.*.from').notEmpty().withMessage('From time is required'),
  body('availability.*.to').notEmpty().withMessage('To time is required'),
];

router.get('/workers', userController.getWorkers);
router.get('/workers/:id', userController.getWorkerProfile);

router.get('/me', protect, userController.getMe);
router.patch('/me', protect, validate(profileUpdateValidation), userController.updateProfile);
router.patch('/me/email', protect, validate(emailUpdateValidation), userController.updateEmail);
router.patch('/me/password', protect, userController.updatePassword);
router.delete('/me', protect, userController.deleteMe);

const addressValidation = [
  body('label').optional().trim().isLength({ max: 100 }).withMessage('Label cannot exceed 100 characters'),
  body('street').optional().trim().isLength({ max: 200 }).withMessage('Street cannot exceed 200 characters'),
  body('city').optional().trim().isLength({ max: 100 }).withMessage('City cannot exceed 100 characters'),
  body('state').optional().trim().isLength({ max: 100 }).withMessage('State cannot exceed 100 characters'),
  body('zipCode').optional().trim().isLength({ max: 30 }).withMessage('Zip code cannot exceed 30 characters'),
  body('lat').optional({ nullable: true }).isFloat({ min: -90, max: 90 }).withMessage('Latitude must be between -90 and 90'),
  body('lng').optional({ nullable: true }).isFloat({ min: -180, max: 180 }).withMessage('Longitude must be between -180 and 180'),
  body('apartment').optional().trim().isLength({ max: 50 }).withMessage('Apartment number cannot exceed 50 characters'),
];

router.post('/me/addresses', protect, validate(addressValidation), userController.addAddress);
router.patch('/me/addresses/:addrId', protect, validate(addressValidation), userController.updateAddress);
router.patch('/me/addresses/:addrId/default', protect, userController.setDefaultAddress);
router.delete('/me/addresses/:addrId', protect, userController.deleteAddress);

router.patch('/me/available', protect, authorize('worker'), userController.toggleAvailableNow);
router.patch('/me/availability', protect, authorize('worker'), validate(availabilityValidation), userController.updateAvailability);
router.patch('/me/blocked-dates', protect, authorize('worker'), userController.toggleBlockedDate);

router.get('/', protect, authorize('admin'), userController.getAllUsers);
router.patch('/:id/status', protect, authorize('admin'), userController.updateUserStatus);
router.patch('/workers/:id/verify', protect, authorize('admin'), userController.verifyWorker);
router.patch('/workers/:id/approve-category', protect, authorize('admin'), userController.approveWorkerCategory);
router.delete('/:id', protect, authorize('admin'), userController.deleteUser);
router.get('/analytics', protect, authorize('admin'), userController.getAnalytics);
router.get('/analytics/payments', protect, authorize('admin'), userController.getPaymentAnalytics);

module.exports = router;
