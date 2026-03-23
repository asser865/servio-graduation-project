// ─── Purpose ──────────────────────────────────────────────────────────────────
// Centralises all service CRUD logic. Controllers stay thin by delegating here.
// Pagination is applied uniformly so every list endpoint behaves consistently.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Service        = require('./service.model');
const ApiError       = require('../../utils/ApiError');

// ── getAllServices ─────────────────────────────────────────────────────────────
const getAllServices = async ({ category, page = 1, limit = 10 }) => {
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

// ── getServiceById ─────────────────────────────────────────────────────────────
const getServiceById = async (id) => {
  const service = await Service.findById(id).populate('createdBy', 'name email');
  if (!service) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found.');
  }
  return service;
};

// ── createService ──────────────────────────────────────────────────────────────
const createService = async (data, adminId) => {
  const service = await Service.create({ ...data, createdBy: adminId });
  return service;
};

// ── updateService ──────────────────────────────────────────────────────────────
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

// ── deleteService ──────────────────────────────────────────────────────────────
// Soft-delete by setting isActive = false rather than removing the document.
// This preserves booking history that references this service.
const deleteService = async (id) => {
  const service = await Service.findByIdAndUpdate(
    id,
    { isActive: false },
    { new: true }
  );
  if (!service) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found.');
  }
  return service;
};

module.exports = { getAllServices, getServiceById, createService, updateService, deleteService };
