'use strict';

const Notification = require('./notification.model');

/**
 * Create a single in-app notification. Fire-and-forget safe.
 * @param {string|ObjectId} userId
 * @param {string}  type         - enum value from notification.model.js
 * @param {string}  title
 * @param {string}  body
 * @param {string}  [referenceId]
 * @param {string}  [referenceUrl]
 */
async function createNotification(userId, type, title, body, referenceId = null, referenceUrl = null) {
  try {
    await Notification.create({ userId, type, title, body, referenceId, referenceUrl });
  } catch (err) {
    console.error('[notification] Failed to create notification:', err.message);
  }
}

/**
 * Convenience wrappers per booking status transition.
 * booking = plain object or Mongoose doc with { _id, user, worker, service }
 */
function notifyBookingCreated(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'your service';
  return createNotification(
    booking.worker,
    'booking_created',
    'New Booking Request',
    `A customer has requested ${svc}. Review and accept or decline.`,
    String(booking._id),
    url
  );
}

function notifyBookingAccepted(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'your service';
  return createNotification(
    booking.user,
    'booking_accepted',
    'Booking Confirmed ✓',
    `Your technician accepted the booking for ${svc}. They will be in touch soon.`,
    String(booking._id),
    url
  );
}

function notifyBookingRejected(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'your service';
  return createNotification(
    booking.user,
    'booking_rejected',
    'Booking Declined',
    `Your booking request for ${svc} was declined. You can find another technician.`,
    String(booking._id),
    url
  );
}

function notifyBookingEnRoute(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  return createNotification(
    booking.user,
    'booking_en_route',
    'Technician On the Way 🚗',
    'Your technician is on the way. Please be ready to receive them.',
    String(booking._id),
    url
  );
}

function notifyBookingArrived(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  return createNotification(
    booking.user,
    'booking_arrived',
    'Technician Arrived',
    'Your technician has arrived. Share the PIN to start the job.',
    String(booking._id),
    url
  );
}

function notifyBookingCompleted(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'the service';
  // Notify both parties
  createNotification(
    booking.user,
    'booking_completed',
    'Job Completed ✓',
    `${svc} has been completed. Don't forget to leave a review!`,
    String(booking._id),
    url
  );
  createNotification(
    booking.worker,
    'booking_completed',
    'Job Marked Complete',
    `${svc} has been marked as completed. Great work!`,
    String(booking._id),
    url
  );
}

function notifyBookingCancelled(booking, actorRole) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'your booking';
  if (actorRole === 'user') {
    // Notify worker
    createNotification(
      booking.worker,
      'booking_cancelled',
      'Booking Cancelled',
      `A customer cancelled their booking for ${svc}.`,
      String(booking._id),
      url
    );
  } else {
    // Notify customer
    createNotification(
      booking.user,
      'booking_cancelled',
      'Booking Cancelled',
      `Your booking for ${svc} was cancelled. You can rebook at any time.`,
      String(booking._id),
      url
    );
  }
}

function notifyAwaitingCustomerConfirmation(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'your service';
  return createNotification(
    booking.user,
    'booking_action_required',
    'Job Complete — Please Confirm',
    `Your technician has finished ${svc}. Please review and confirm completion to release payment.`,
    String(booking._id),
    url
  );
}

function notifyPendingAdminReview(booking) {
  const url = `./booking-details.html?id=${booking._id}`;
  const svc = booking.serviceName || booking.service?.title || 'the service';
  createNotification(
    booking.user,
    'booking_action_required',
    'Booking Under Review',
    `Your booking for ${svc} is being reviewed by our team. We'll update you shortly.`,
    String(booking._id),
    url
  );
  createNotification(
    booking.worker,
    'booking_action_required',
    'Booking Under Review',
    `The booking for ${svc} is under admin review. Hold tight.`,
    String(booking._id),
    url
  );
}

function notifyReviewReceived(workerId, reviewerName, rating, bookingId) {
  const url = `./booking-details.html?id=${bookingId}`;
  return createNotification(
    workerId,
    'review_received',
    `New ${rating}-star Review`,
    `${reviewerName} left you a ${rating}-star review. Great work!`,
    String(bookingId),
    url
  );
}

module.exports = {
  createNotification,
  notifyBookingCreated,
  notifyBookingAccepted,
  notifyBookingRejected,
  notifyBookingEnRoute,
  notifyBookingArrived,
  notifyBookingCompleted,
  notifyBookingCancelled,
  notifyAwaitingCustomerConfirmation,
  notifyPendingAdminReview,
  notifyReviewReceived,
};
