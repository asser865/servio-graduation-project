// ─── Purpose ──────────────────────────────────────────────────────────────────
// Centralises all service CRUD logic. Controllers stay thin by delegating here.
// Pagination is applied uniformly so every list endpoint behaves consistently.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Service        = require('./service.model');
const ApiError       = require('../../utils/ApiError');

/**
 * LIST ALL SERVICES
 * WHAT: Returns a paginated list of available services.
 * HOW:  Supports ?category filtering.
 */
const getAllServices = async ({ category, page = 1, limit = 100 }) => {
  const filter = { isActive: true };
  if (category) filter.category = category;

  const skip = (Number(page) - 1) * Number(limit);

  const [services, total] = await Promise.all([
    Service.find(filter)
      .populate('createdBy', 'name email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit)),
    Service.countDocuments(filter),
  ]);

  return {
    services,
    pagination: {
      total,
      page:       Number(page),
      limit:      Number(limit),
      totalPages: Math.ceil(total / Number(limit)),
    },
  };
};

/**
 * GET SINGLE SERVICE
 * WHAT: Returns full details of one service by its ID.
 */
const getServiceById = async (id) => {
  const service = await Service.findById(id).populate('createdBy', 'name email');
  if (!service) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found.');
  }
  return service;
};

/**
 * CREATE SERVICE (Admin Only)
 * WHAT: Adds a new service type to the system catalog.
 */
const createService = async (data, adminId) => {
  const service = await Service.create({ ...data, createdBy: adminId });
  return service;
};

/**
 * UPDATE SERVICE (Admin Only)
 * WHAT: Modifies an existing service's details.
 */
const updateService = async (id, data) => {
  const service = await Service.findByIdAndUpdate(id, data, {
    new:         true,  // return updated document
    runValidators: true, // re-run schema validators on update
  });
  if (!service) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found.');
  }
  return service;
};

/**
 * DELETE SERVICE (Admin Only)
 * WHAT: Permanently removes a service from the catalogue.
 * NOTE: Uses hard delete so admin actions are reflected immediately in the DB.
 *       Booking documents will retain the service ID for history purposes.
 */
const deleteService = async (id) => {
  const service = await Service.findByIdAndDelete(id);
  if (!service) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found.');
  }
  return service;
};

module.exports = { getAllServices, getServiceById, createService, updateService, deleteService };
