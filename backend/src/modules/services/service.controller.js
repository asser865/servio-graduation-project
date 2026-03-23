// ─── Purpose ──────────────────────────────────────────────────────────────────
// Service controller — maps HTTP actions to service layer calls.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes }  = require('http-status-codes');
const serviceService   = require('./service.service');
const ApiResponse      = require('../../utils/ApiResponse');

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
  return ApiResponse.success(res, StatusCodes.CREATED, 'Service created successfully.', service);
};

const update = async (req, res) => {
  const service = await serviceService.updateService(req.params.id, req.body);
  return ApiResponse.success(res, StatusCodes.OK, 'Service updated successfully.', service);
};

const remove = async (req, res) => {
  await serviceService.deleteService(req.params.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Service deactivated successfully.', null);
};

module.exports = { getAll, getOne, create, update, remove };
