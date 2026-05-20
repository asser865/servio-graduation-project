'use strict';
const { StatusCodes } = require('http-status-codes');
const ApiError = require('../../utils/ApiError');
const User     = require('../users/user.model');
const Settings = require('../admin/settings.model');

async function getSoftCap() {
  const s = await Settings.findOne({}).lean();
  return s?.favoritesSoftCap ?? 50;
}

async function addFavorite(userId, workerId) {
  const me = await User.findById(userId);
  if (!me) throw new ApiError(StatusCodes.UNAUTHORIZED, 'User not found');
  if ((me.favorites || []).some(id => String(id) === String(workerId))) return;

  const cap = await getSoftCap();
  if ((me.favorites || []).length >= cap) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Favourites limit reached (${cap}). Remove some to add more.`);
  }

  const worker = await User.findOne({ _id: workerId, role: 'worker' });
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or not a worker');

  const next = [workerId, ...me.favorites.filter(id => String(id) !== String(workerId))];
  await User.updateOne({ _id: userId }, { $set: { favorites: next } });
}

async function removeFavorite(userId, workerId) {
  await User.updateOne({ _id: userId }, { $pull: { favorites: workerId } });
}

async function listFavoriteIds(userId) {
  const me = await User.findById(userId).select('favorites').lean();
  return (me?.favorites || []).map(String);
}

async function listFavorites(userId, { limit = 20, offset = 0, q, category, minRating, availableNow, sort = 'recent' } = {}) {
  const me = await User.findById(userId).select('favorites').lean();
  const ids = me?.favorites || [];
  if (ids.length === 0) return { total: 0, items: [] };

  const filter = { _id: { $in: ids }, role: 'worker', isActive: true };
  if (category)  filter.categories = category;
  if (minRating) filter.averageRating = { $gte: Number(minRating) };
  if (q)         filter.name = { $regex: q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
  if (availableNow) filter.isAvailable = true;

  const cursor = User.find(filter).select('name profileImage averageRating totalReviews categories locationLabel isAvailable');
  if (sort === 'rating') cursor.sort({ averageRating: -1, totalReviews: -1 });
  else if (sort === 'name')   cursor.sort({ name: 1 });

  const all = await cursor.lean();
  const ordered = sort === 'recent'
    ? ids.map(id => all.find(w => String(w._id) === String(id))).filter(Boolean)
    : all;

  return {
    total: ordered.length,
    items: ordered.slice(offset, offset + limit),
  };
}

async function countFavoritedBy(workerId) {
  return User.countDocuments({ favorites: workerId });
}

module.exports = { addFavorite, removeFavorite, listFavoriteIds, listFavorites, countFavoritedBy };
