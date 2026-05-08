const { Router } = require('express');
const { body } = require('express-validator');
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
  body('skills').optional().isArray().withMessage('Skills must be an array'),
  body('skills.*').optional().isString().trim().notEmpty().withMessage('Each skill must be a non-empty string'),
  body('categories').optional().isArray().withMessage('Categories must be an array'),
  body('categories.*').optional().isIn(['plumbing', 'electrical', 'painting', 'flooring', 'carpentry', 'cleaning', 'hvac', 'other']).withMessage('Invalid category'),
  body('services').optional().isArray().withMessage('Services must be an array'),
  body('services.*').optional().isMongoId().withMessage('Each service must be a valid MongoDB ObjectId'),
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
];

router.post('/me/addresses', protect, validate(addressValidation), userController.addAddress);
router.patch('/me/addresses/:addrId', protect, validate(addressValidation), userController.updateAddress);
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
