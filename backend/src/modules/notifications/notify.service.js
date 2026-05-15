'use strict';

const NotifyRequest              = require('./notifyRequest.model');
const { sendTechAvailableEmail } = require('../../utils/email');
const { createNotification }     = require('./notification.service');

/**
 * Fire-and-forget: find unfulfilled NotifyRequests that match the worker's
 * categories, send each subscriber an email, and mark the request fulfilled.
 *
 * Called after a worker flips isAvailable → true. Never throws — must not
 * affect the main toggle response.
 *
 * @param {object} worker  - Mongoose user document (needs .name, .categories)
 * @param {string} baseUrl - Frontend base URL (process.env.FRONTEND_URL)
 */
async function dispatchAvailabilityMatches(worker, baseUrl) {
  const categories = (worker.categories || []).map(c => c.toLowerCase());
  if (!categories.length) return;

  let requests;
  try {
    requests = await NotifyRequest.find({
      fulfilledAt:     null,
      serviceCategory: { $in: categories },
    });
  } catch (err) {
    console.error('[notify] Failed to query NotifyRequests:', err.message);
    return;
  }

  for (const req of requests) {
    const bookingUrl = `${baseUrl}/html/technician-listing.html?service=${req.serviceCategory}`;
    try {
      await sendTechAvailableEmail(req.email, worker.name, req.serviceCategory, bookingUrl);
      req.fulfilledAt = new Date();
      await req.save();
      // Also create in-app notification if subscriber has an account
      if (req.userId) {
        createNotification(
          req.userId,
          'tech_available',
          `Technician Available for ${req.serviceCategory}`,
          `${worker.name} is now available for ${req.serviceCategory} in your area. Book now!`,
          null,
          bookingUrl
        );
      }
    } catch (err) {
      console.error(`[notify] Failed to notify ${req.email}:`, err.message);
    }
  }
}

module.exports = { dispatchAvailabilityMatches };
