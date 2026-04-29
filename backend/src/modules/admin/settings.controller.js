const { StatusCodes } = require('http-status-codes');
const Settings        = require('./settings.model');
const ApiResponse     = require('../../utils/ApiResponse');

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
  return ApiResponse.success(res, StatusCodes.OK, 'Settings updated.', settings);
};

module.exports = { getSettings, updateSettings };
