'use strict';
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const fav = require('./favorite.service');
const { getWorkerBusyStateFromDB } = require('../bookings/availability.service');

exports.listMine = asyncHandler(async (req, res) => {
  const { limit, offset, q, category, minRating, availableNow, sort } = req.query;
  const data = await fav.listFavorites(req.user.id, {
    limit: limit ? Number(limit) : undefined,
    offset: offset ? Number(offset) : undefined,
    q, category,
    minRating,
    availableNow: availableNow === 'true' || availableNow === '1',
    sort,
  });

  const items = await Promise.all((data.items || []).map(async (w) => {
    let busyState;
    try { busyState = await getWorkerBusyStateFromDB(w._id); }
    catch (_) {
      busyState = { isBusy: false, label: null, busyUntil: null, remainingMin: null,
                    isOverrunning: false, extensionCount: 0, extensionsApplied: 0, bookingId: null };
    }
    busyState.bookingId = null;
    return { ...w, busyState };
  }));

  res.json({ ...data, items });
});

exports.listMyIds = asyncHandler(async (req, res) => {
  const ids = await fav.listFavoriteIds(req.user.id);
  res.json({ ids });
});

exports.add = asyncHandler(async (req, res) => {
  await fav.addFavorite(req.user.id, req.params.workerId);
  res.status(201).json({ ok: true });
});

exports.remove = asyncHandler(async (req, res) => {
  await fav.removeFavorite(req.user.id, req.params.workerId);
  res.json({ ok: true });
});

exports.myCountAsWorker = asyncHandler(async (req, res) => {
  const count = await fav.countFavoritedBy(req.user.id);
  res.json({ count });
});
