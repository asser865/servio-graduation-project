'use strict';

const { StatusCodes } = require('http-status-codes');
const NotifyRequest   = require('./notifyRequest.model');
const ApiResponse     = require('../../utils/ApiResponse');

// POST /api/v1/notify
const subscribe = async (req, res) => {
  const { serviceCategory, serviceArea = '' } = req.body;

  const email    = req.user.email;
  const userId   = req.user.id;
  const category = serviceCategory.toLowerCase().trim();

  const existing = await NotifyRequest.findOne({ email, serviceCategory: category, fulfilledAt: null });
  if (existing) {
    return ApiResponse.success(res, StatusCodes.OK, 'Already subscribed for this service.', { subscribed: true });
  }

  await NotifyRequest.create({ email, userId, serviceCategory: category, serviceArea: serviceArea.trim() });
  return ApiResponse.success(res, StatusCodes.CREATED, 'You will be notified when a technician becomes available.', { subscribed: true });
};

// DELETE /api/v1/notify
const unsubscribe = async (req, res) => {
  const { serviceCategory } = req.body;
  const email    = req.user.email;
  const category = (serviceCategory || '').toLowerCase().trim();

  const result = await NotifyRequest.deleteOne({ email, serviceCategory: category, fulfilledAt: null });
  if (result.deletedCount === 0) {
    return ApiResponse.success(res, StatusCodes.OK, 'No active subscription found.', { unsubscribed: false });
  }
  return ApiResponse.success(res, StatusCodes.OK, 'Unsubscribed successfully.', { unsubscribed: true });
};

module.exports = { subscribe, unsubscribe };
