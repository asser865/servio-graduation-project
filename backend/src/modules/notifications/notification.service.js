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

async function notifyDisputeOpened(dispute) {
  const booking = dispute.booking || {};
  const bookingId = String(booking._id || dispute.booking || dispute.bookingId || '');
  const customerId = booking.user?._id || booking.user || dispute.raisedBy;
  const workerId = booking.worker?._id || booking.worker;
  const url = `./booking-details.html?id=${bookingId}`;

  if (workerId) {
    createNotification(
      workerId,
      'dispute_opened',
      'Dispute Opened',
      'A customer opened a support case on one of your bookings. Keep job notes and evidence ready.',
      bookingId,
      url
    );
  }

  try {
    const User = require('../users/user.model');
    const admins = await User.find({ role: 'admin', isActive: { $ne: false } }).select('_id');
    admins.forEach((admin) => {
      createNotification(
        admin._id,
        'dispute_opened',
        'New Dispute',
        'A customer opened a dispute that needs admin review.',
        bookingId,
        './admin-dashboard.html#disputes'
      );
    });
  } catch (err) {
    console.error('[notification] Failed to notify admins about dispute:', err.message);
  }

  if (customerId) {
    createNotification(
      customerId,
      'dispute_opened',
      'Support Case Opened',
      'Your dispute is now with SERVIO support. We will update you after review.',
      bookingId,
      url
    );
  }
}

function notifyDisputeResolved(dispute) {
  const booking = dispute.booking || {};
  const bookingId = String(booking._id || dispute.booking || '');
  const customerId = booking.user?._id || booking.user || dispute.raisedBy;
  const workerId = booking.worker?._id || booking.worker;
  const url = `./booking-details.html?id=${bookingId}`;
  const result = dispute.decision === 'refund' ? 'A refund was issued.' : 'The booking was approved for release.';

  if (customerId) {
    createNotification(customerId, 'dispute_resolved', 'Dispute Resolved', result, bookingId, url);
  }
  if (workerId) {
    createNotification(workerId, 'dispute_resolved', 'Dispute Resolved', result, bookingId, url);
  }
}

async function notifySupportIssueOpened(issue) {
  const booking = issue.booking || {};
  const bookingId = String(booking._id || issue.booking || '');
  const customerId = issue.customer?._id || issue.customer;
  const workerId = issue.worker?._id || issue.worker || booking.worker;
  const customerUrl = `./booking-details.html?id=${bookingId}`;

  if (customerId) {
    createNotification(
      customerId,
      'support_issue_opened',
      'Support Case Opened',
      'Your support case was received. SERVIO support will review it and update you.',
      String(issue._id || bookingId),
      './customer-dashboard.html#support'
    );
  }

  if (workerId) {
    createNotification(
      workerId,
      'support_issue_opened',
      issue.priority === 'urgent' ? 'Urgent Support Case' : 'Support Case Opened',
      'A customer reported an issue on one of your bookings. Keep job notes and evidence ready.',
      bookingId,
      customerUrl
    );
  }

  try {
    const User = require('../users/user.model');
    const admins = await User.find({ role: 'admin', isActive: { $ne: false } }).select('_id');
    admins.forEach((admin) => {
      createNotification(
        admin._id,
        'support_issue_opened',
        issue.priority === 'urgent' ? 'Urgent Support Issue' : 'New Support Issue',
        'A customer opened a support issue that needs admin review.',
        String(issue._id || bookingId),
        './admin-dashboard.html#support'
      );
    });
  } catch (err) {
    console.error('[notification] Failed to notify admins about support issue:', err.message);
  }
}

function notifySupportIssueUpdated(issue) {
  const booking = issue.booking || {};
  const bookingId = String(booking._id || issue.booking || '');
  const customerId = issue.customer?._id || issue.customer;
  const workerId = issue.worker?._id || issue.worker || booking.worker;
  const body = `Support case status is now ${String(issue.status || 'updated').replace('_', ' ')}.`;
  if (customerId) createNotification(customerId, 'support_issue_updated', 'Support Case Updated', body, String(issue._id || bookingId), './customer-dashboard.html#support');
  if (workerId) createNotification(workerId, 'support_issue_updated', 'Support Case Updated', body, String(issue._id || bookingId), `./booking-details.html?id=${bookingId}`);
}

function notifySupportIssueResolved(issue) {
  const booking = issue.booking || {};
  const bookingId = String(booking._id || issue.booking || '');
  const customerId = issue.customer?._id || issue.customer;
  const workerId = issue.worker?._id || issue.worker || booking.worker;
  const body = issue.resolution || 'The support case has been resolved.';
  if (customerId) createNotification(customerId, 'support_issue_resolved', 'Support Case Resolved', body, String(issue._id || bookingId), './customer-dashboard.html#support');
  if (workerId) createNotification(workerId, 'support_issue_resolved', 'Support Case Resolved', body, String(issue._id || bookingId), `./booking-details.html?id=${bookingId}`);
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
  notifyDisputeOpened,
  notifyDisputeResolved,
  notifySupportIssueOpened,
  notifySupportIssueUpdated,
  notifySupportIssueResolved,
};
