const { StatusCodes } = require('http-status-codes');
const Settings        = require('./settings.model');
const ApiResponse     = require('../../utils/ApiResponse');
const adminSettingsSvc = require('./admin-settings.service');

// Bridge: mirror overlapping fields from legacy Settings → AdminSettings so the
// escrow/debt money paths (which read AdminSettings) honour admin UI changes.
function buildAdminSettingsPatch(body) {
  const patch = {};
  if (body.cashDebtWarningThreshold !== undefined) {
    patch.debt = patch.debt || {};
    patch.debt.warningThreshold = Number(body.cashDebtWarningThreshold);
  }
  if (body.cashDebtBlockThreshold !== undefined) {
    patch.debt = patch.debt || {};
    patch.debt.blockThreshold = Number(body.cashDebtBlockThreshold);
  }
  if (body.maxCashLiability !== undefined) {
    patch.debt = patch.debt || {};
    patch.debt.absoluteBlockThreshold = Number(body.maxCashLiability);
  }
  if (body.autoReleaseWindow !== undefined) {
    patch.escrow = { autoConfirmHours: Number(body.autoReleaseWindow) };
  }
  return patch;
}

const getSettings = async (req, res) => {
  let settings = await Settings.findOne();
  if (!settings) settings = await Settings.create({});
  return ApiResponse.success(res, StatusCodes.OK, 'Settings retrieved.', settings);
};

const updateSettings = async (req, res) => {
  let settings = await Settings.findOne();
  if (!settings) {
    settings = await Settings.create(req.body);
  } else {
    Object.assign(settings, req.body);
    await settings.save();
  }
  const adminPatch = buildAdminSettingsPatch(req.body);
  if (Object.keys(adminPatch).length) {
    try { await adminSettingsSvc.update(adminPatch, req.user?.id); }
    catch (_) { /* non-fatal — legacy update already saved */ }
  }
  return ApiResponse.success(res, StatusCodes.OK, 'Settings updated.', settings);
};

module.exports = { getSettings, updateSettings };
