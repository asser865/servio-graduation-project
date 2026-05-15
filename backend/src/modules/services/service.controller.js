// ─── Purpose ──────────────────────────────────────────────────────────────────
// Service controller — maps HTTP actions to service layer calls.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes }  = require('http-status-codes');
const serviceService   = require('./service.service');
const User             = require('../users/user.model');
const ApiError         = require('../../utils/ApiError');
const ApiResponse      = require('../../utils/ApiResponse');
const { logEvent }     = require('../admin/audit.service');

const getAll = async (req, res) => {
  const { category, page, limit } = req.query;
  const result = await serviceService.getAllServices({ category, page, limit });
  return ApiResponse.success(res, StatusCodes.OK, 'Services retrieved successfully.', result);
};

const getOne = async (req, res) => {
  const service = await serviceService.getServiceById(req.params.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Service retrieved successfully.', service);
};

const create = async (req, res) => {
  const service = await serviceService.createService(req.body, req.user.id);
  logEvent({ req, type: 'service', action: 'Service created', target: service.title || service._id?.toString() });
  return ApiResponse.success(res, StatusCodes.CREATED, 'Service created successfully.', service);
};

const update = async (req, res) => {
  const service = await serviceService.updateService(req.params.id, req.body);
  logEvent({ req, type: 'service', action: 'Service updated', target: service.title || service._id?.toString() });
  return ApiResponse.success(res, StatusCodes.OK, 'Service updated successfully.', service);
};

const remove = async (req, res) => {
  await serviceService.deleteService(req.params.id);
  logEvent({ req, type: 'service', action: 'Service deleted', target: req.params.id, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Service deactivated successfully.', null);
};

// ── GET TECHNICIANS FOR A SERVICE (Public) ────────────────────────────────────
// WHAT: Returns all active, verified workers assigned to a specific service.
// HOW:  GET /api/v1/services/:serviceId/technicians
// Reuses the same query as GET /api/v1/users/workers?serviceId= to avoid duplication.
const getTechnicians = async (req, res) => {
  const { serviceId } = req.params;
  const { page = 1, limit = 10 } = req.query;

  // Verify the service exists and is active
  const service = await serviceService.getServiceById(serviceId);
  if (!service || !service.isActive) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found or no longer available.');
  }

  const filter = {
    role: 'worker',
    isActive: true,
    isVerified: true,
    isAvailable: true,
    'availability.0': { $exists: true },
    $or: [
      { services: serviceId },
      { categories: { $in: [service.category] } },
    ],
  };
  const skip = (Number(page) - 1) * Number(limit);

  const [workers, total] = await Promise.all([
    User.find(filter)
      .select('name profileImage categories services skills averageRating totalReviews location locationLabel serviceArea coverageAreas hourlyRate isVerified availability')
      .populate('services', 'title category')
      .sort({ averageRating: -1 })
      .skip(skip)
      .limit(Number(limit)),
    User.countDocuments(filter),
  ]);

  return ApiResponse.success(res, StatusCodes.OK, 'Technicians retrieved successfully.', {
    service: { _id: service._id, title: service.title, category: service.category },
    workers,
    pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) },
  });
};

module.exports = { getAll, getOne, create, update, remove, getTechnicians };
