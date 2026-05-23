'use strict';

const { StatusCodes } = require('http-status-codes');
const Notification    = require('./notification.model');
const NotificationPreference = require('./preferences.model');
const ApiResponse     = require('../../utils/ApiResponse');

const DEFAULT_CHANNELS = { email: true, inApp: true, push: true, sms: false };

// GET /api/v1/notifications
const getNotifications = async (req, res) => {
  const userId = req.user.id;
  const limit  = Math.min(parseInt(req.query.limit) || 50, 100);
  const skip   = parseInt(req.query.skip) || 0;

  const [notifications, unreadCount] = await Promise.all([
    Notification.find({ userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Notification.countDocuments({ userId, isRead: false }),
  ]);

  return ApiResponse.success(res, StatusCodes.OK, 'Notifications fetched.', {
    notifications,
    unreadCount,
    total: notifications.length,
  });
};

// GET /api/v1/notifications/unread-count
const getUnreadCount = async (req, res) => {
  const count = await Notification.countDocuments({ userId: req.user.id, isRead: false });
  return ApiResponse.success(res, StatusCodes.OK, 'Unread count.', { unreadCount: count });
};

// PATCH /api/v1/notifications/:id/read
const markOneRead = async (req, res) => {
  const notif = await Notification.findOneAndUpdate(
    { _id: req.params.id, userId: req.user.id },
    { isRead: true },
    { new: true }
  );
  if (!notif) return ApiResponse.error(res, StatusCodes.NOT_FOUND, 'Notification not found.');
  return ApiResponse.success(res, StatusCodes.OK, 'Marked as read.', { notification: notif });
};

// PATCH /api/v1/notifications/read-all
const markAllRead = async (req, res) => {
  await Notification.updateMany({ userId: req.user.id, isRead: false }, { isRead: true });
  return ApiResponse.success(res, StatusCodes.OK, 'All notifications marked as read.');
};

// DELETE /api/v1/notifications
const clearAll = async (req, res) => {
  await Notification.deleteMany({ userId: req.user.id });
  return ApiResponse.success(res, StatusCodes.OK, 'All notifications cleared.');
};

// DELETE /api/v1/notifications/:id
const deleteOne = async (req, res) => {
  await Notification.deleteOne({ _id: req.params.id, userId: req.user.id });
  return ApiResponse.success(res, StatusCodes.OK, 'Notification deleted.');
};

// GET /api/v1/notifications/preferences
const getPreferences = async (req, res) => {
  const pref = await NotificationPreference.findOne({ user: req.user.id });
  const channels = { ...DEFAULT_CHANNELS, ...(pref?.channels || {}) };
  return ApiResponse.success(res, StatusCodes.OK, 'Preferences fetched.', { channels });
};

// PUT /api/v1/notifications/preferences
const updatePreferences = async (req, res) => {
  const body = req.body || {};
  const channels = body.channels && typeof body.channels === 'object' ? body.channels : null;
  if (!channels) return ApiResponse.error(res, StatusCodes.BAD_REQUEST, 'channels object required.');

  const updates = {};
  for (const [k, v] of Object.entries(channels)) {
    if (!Object.prototype.hasOwnProperty.call(DEFAULT_CHANNELS, k)) continue;
    updates[`channels.${k}`] = !!v;
  }
  if (Object.keys(updates).length === 0) {
    return ApiResponse.error(res, StatusCodes.BAD_REQUEST, 'No valid channel keys provided.');
  }

  const pref = await NotificationPreference.findOneAndUpdate(
    { user: req.user.id },
    { $set: updates },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  const merged = { ...DEFAULT_CHANNELS, ...(pref?.channels || {}) };
  return ApiResponse.success(res, StatusCodes.OK, 'Preferences updated.', { channels: merged });
};

module.exports = {
  getNotifications, getUnreadCount, markOneRead, markAllRead, clearAll, deleteOne,
  getPreferences, updatePreferences,
};
