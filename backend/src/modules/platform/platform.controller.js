const { StatusCodes } = require('http-status-codes');
const ApiResponse = require('../../utils/ApiResponse');
const { getPublicPlatformSettings } = require('../bookings/booking.service');

const getSettings = async (req, res) => {
  const settings = await getPublicPlatformSettings();
  return ApiResponse.success(res, StatusCodes.OK, 'Platform settings retrieved.', settings);
};

module.exports = { getSettings };
