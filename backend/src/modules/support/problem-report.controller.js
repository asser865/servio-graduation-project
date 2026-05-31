const { StatusCodes } = require('http-status-codes');
const problemReportService = require('./problem-report.service');
const ApiResponse = require('../../utils/ApiResponse');

const createReport = async (req, res) => {
  const report = await problemReportService.createReport(req.user.id, req.body);
  return ApiResponse.success(res, StatusCodes.CREATED, 'Problem report submitted.', report);
};

const getAllReports = async (req, res) => {
  const result = await problemReportService.getAllReports(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Problem reports retrieved.', result);
};

const updateReport = async (req, res) => {
  const report = await problemReportService.updateReport(req.params.id, req.body);
  return ApiResponse.success(res, StatusCodes.OK, 'Problem report updated.', report);
};

module.exports = {
  createReport,
  getAllReports,
  updateReport,
};
