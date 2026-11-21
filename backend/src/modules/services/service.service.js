// ─── Purpose ──────────────────────────────────────────────────────────────────
// Centralises all service CRUD logic. Controllers stay thin by delegating here.
// Pagination is applied uniformly so every list endpoint behaves consistently.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Service        = require('./service.model');
const User           = require('../users/user.model');
const ApiError       = require('../../utils/ApiError');

// ── Technician aggregate (Option B) ──────────────────────────────────────────
// WHAT: A per-service techStats aggregate computed over the SAME "available
//       verified technician" filter used by user.controller.js#getWorkers, so
//       the marketplace card and the service drawer/modal read ONE backend
//       source and never disagree (card used to show service-level "New"
//       while the modal showed a client-side category aggregate).
// HOW:  Single Mongoose aggregation over the User collection — unwind each
//       worker's offered services, group by serviceId, attach the result to
//       each service as `techStats: { pros, reviews, rating, minStartsFrom }`.
async function buildTechStatsMap() {
  const rows = await User.aggregate([
    {
      $match: {
        role: 'worker',
        isActive: true,
        isVerified: true,
        isAvailable: true,
        'availability.0': { $exists: true },
        $or: [
          { suspendedUntil: { $exists: false } },
          { suspendedUntil: null },
          { suspendedUntil: { $lte: new Date() } },
        ],
      },
    },
    { $unwind: '$services' },
    {
      $group: {
        _id: '$services.serviceId',
        pros: { $sum: 1 },
        reviews: { $sum: { $ifNull: ['$totalReviews', 0] } },
        ratingWeighted: {
          $sum: {
            $multiply: [
              { $ifNull: ['$averageRating', 0] },
              { $ifNull: ['$totalReviews', 0] },
            ],
          },
        },
        minStartsFrom: { $min: '$services.startsFrom' },
      },
    },
  ]);

  const map = new Map();
  rows.forEach((row) => {
    map.set(String(row._id), {
      pros: row.pros,
      reviews: row.reviews,
      rating: row.reviews > 0 ? row.ratingWeighted / row.reviews : 0,
      minStartsFrom: row.minStartsFrom ?? null,
    });
  });
  return map;
}

function emptyTechStats() {
  return { pros: 0, reviews: 0, rating: 0, minStartsFrom: null };
}

function attachTechStats(service, techStatsMap) {
  const plain = typeof service.toObject === 'function' ? service.toObject() : service;
  plain.techStats = techStatsMap.get(String(plain._id)) || emptyTechStats();
  return plain;
}

/**
 * LIST ALL SERVICES
 * WHAT: Returns a paginated list of available services.
 * HOW:  Supports ?category filtering.
 */
const getAllServices = async ({ category, page = 1, limit = 100 }) => {
  const filter = { isActive: true };
  if (category) filter.category = category;

  const skip = (Number(page) - 1) * Number(limit);

  const [services, total, techStatsMap] = await Promise.all([
    Service.find(filter)
      .populate('createdBy', 'name email')
      .sort({ createdAt: 1 })
      .skip(skip)
      .limit(Number(limit)),
    Service.countDocuments(filter),
    buildTechStatsMap(),
  ]);

  const servicesWithStats = services.map((service) => attachTechStats(service, techStatsMap));

  return {
    services: servicesWithStats,
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
  const techStatsMap = await buildTechStatsMap();
  return attachTechStats(service, techStatsMap);
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
