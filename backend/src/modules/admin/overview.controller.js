const { StatusCodes } = require('http-status-codes');
const ApiResponse = require('../../utils/ApiResponse');
const overviewService = require('./overview.service');

const getOverview = async (req, res) => {
  const overview = await overviewService.getOverview();
  return ApiResponse.success(res, StatusCodes.OK, 'Admin overview retrieved.', overview);
};

const getRevenueHistory = async (req, res) => {
  const days = req.query.days || 7;
  const data = await overviewService.getRevenueHistory(days);
  return ApiResponse.success(res, StatusCodes.OK, 'Revenue history retrieved.', data);
};

module.exports = { getOverview, getRevenueHistory };
