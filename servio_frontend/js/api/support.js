import { api } from './client.js';

export const createSupportIssue = (body) =>
  api.post('/support/issues', body);

export const getMySupportIssues = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/support/issues/my${qs ? '?' + qs : ''}`);
};

export const getAdminSupportIssues = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/support/issues/admin${qs ? '?' + qs : ''}`);
};

export const updateSupportIssueStatus = (id, body) =>
  api.patch(`/support/issues/${id}/status`, body);

export const resolveSupportIssue = (id, body) =>
  api.patch(`/support/issues/${id}/resolve`, body);

export const escalateSupportIssueToDispute = (id, body = {}) =>
  api.patch(`/support/issues/${id}/escalate-dispute`, body);

// ── Problem Reports ───────────────────────────────────────────────────────────
export const getAdminProblemReports = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/reports/problems${qs ? '?' + qs : ''}`);
};

export const updateProblemReport = (id, body) =>
  api.patch(`/reports/problems/${id}`, body);

// ── Contact Messages ──────────────────────────────────────────────────────────
export const getAdminContactMessages = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/contact${qs ? '?' + qs : ''}`);
};

export const updateContactMessage = (id, body) =>
  api.patch(`/contact/${id}`, body);
