const { StatusCodes } = require('http-status-codes');
const supportIssueService = require('./support-issue.service');
const ApiResponse = require('../../utils/ApiResponse');
const { logEvent } = require('../admin/audit.service');

const createIssue = async (req, res) => {
  const issue = await supportIssueService.createIssue(req.user.id, req.body);
  logEvent({ req, type: 'booking', action: 'Support issue opened', target: issue._id, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.CREATED, 'Support issue opened.', issue);
};

const getMyIssues = async (req, res) => {
  const result = await supportIssueService.getMyIssues(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Support issues retrieved.', result);
};

const getAdminIssues = async (req, res) => {
  const result = await supportIssueService.getAdminIssues(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Support issues retrieved.', result);
};

const updateStatus = async (req, res) => {
  const issue = await supportIssueService.updateStatus(req.params.id, req.body);
  logEvent({ req, type: 'booking', action: `Support issue status: ${issue.status}`, target: req.params.id });
  return ApiResponse.success(res, StatusCodes.OK, 'Support issue updated.', issue);
};

const resolveIssue = async (req, res) => {
  const issue = await supportIssueService.resolveIssue(req.params.id, req.user.id, req.body);
  logEvent({ req, type: 'booking', action: 'Support issue resolved', target: req.params.id });
  return ApiResponse.success(res, StatusCodes.OK, 'Support issue resolved.', issue);
};

const escalateToDispute = async (req, res) => {
  const result = await supportIssueService.escalateToDispute(req.params.id, req.user.id, req.body);
  logEvent({ req, type: 'booking', action: 'Support issue escalated to dispute', target: req.params.id, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Support issue escalated to dispute.', result);
};

module.exports = {
  createIssue,
  getMyIssues,
  getAdminIssues,
  updateStatus,
  resolveIssue,
  escalateToDispute,
};
