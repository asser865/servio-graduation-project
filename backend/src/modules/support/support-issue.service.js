const { StatusCodes } = require('http-status-codes');
const Booking = require('../bookings/booking.model');
const SupportIssue = require('./support-issue.model');
const disputeService = require('../payments/dispute.service');
const notifSvc = require('../notifications/notification.service');
const ApiError = require('../../utils/ApiError');

const ACTIVE_STATUSES = ['open', 'reviewing', 'waiting_customer', 'waiting_worker'];
const COMPLETED_REPORT_WINDOW_MS = 48 * 60 * 60 * 1000;

const TYPE_BY_STATUS = {
  accepted: ['late', 'no_show', 'other'],
  en_route: ['late', 'no_show', 'other'],
  arrived: ['during_work_problem', 'safety', 'other'],
  in_progress: ['during_work_problem', 'safety', 'other'],
  completed: ['post_completion', 'other'],
};

function normalizeEvidence(evidence) {
  return Array.isArray(evidence)
    ? evidence.map(item => String(item || '').trim()).filter(Boolean).slice(0, 6)
    : [];
}

function assertTypeAllowed(booking, type) {
  const allowed = TYPE_BY_STATUS[booking.status] || [];
  if (!allowed.includes(type)) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Issue type '${type}' is not allowed for booking status '${booking.status}'.`
    );
  }
  if (booking.status === 'completed') {
    const completedAt = booking.updatedAt || booking.customerConfirmedAt || booking.createdAt;
    if (!completedAt || Date.now() - new Date(completedAt).getTime() > COMPLETED_REPORT_WINDOW_MS) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Completed bookings can only be reported within 48 hours.');
    }
  }
}

function priorityForType(type, requestedPriority) {
  if (type === 'safety') return 'urgent';
  if (['late', 'no_show'].includes(type)) return requestedPriority === 'urgent' ? 'urgent' : 'high';
  return ['normal', 'high', 'urgent'].includes(requestedPriority) ? requestedPriority : 'normal';
}

async function populateIssue(query) {
  return query
    .populate({
      path: 'booking',
      select: 'scheduledDate scheduledTime status paymentMethod paymentStatus totalPrice estimatedTotal serviceCategory service user worker updatedAt customerConfirmedAt',
      populate: [
        { path: 'user', select: 'name email phone' },
        { path: 'worker', select: 'name email phone profileImage' },
        { path: 'service', select: 'title category' },
      ],
    })
    .populate('customer', 'name email phone')
    .populate('worker', 'name email phone profileImage')
    .populate('resolvedBy', 'name email');
}

class SupportIssueService {
  async createIssue(userId, { bookingId, type, description, evidence = [], priority }) {
    if (!bookingId || !type || !description) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'bookingId, type, and description are required.');
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== userId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    assertTypeAllowed(booking, type);

    const existing = await SupportIssue.findOne({
      booking: bookingId,
      customer: userId,
      type,
      status: { $in: ACTIVE_STATUSES },
    });
    if (existing) {
      throw new ApiError(StatusCodes.CONFLICT, 'You already have an active support issue for this booking.');
    }

    const issue = await SupportIssue.create({
      booking: bookingId,
      customer: userId,
      worker: booking.worker,
      type,
      priority: priorityForType(type, priority),
      description,
      evidence: normalizeEvidence(evidence),
    });

    const populated = await populateIssue(SupportIssue.findById(issue._id));
    Promise.resolve(notifSvc.notifySupportIssueOpened(populated)).catch(() => {});
    return populated;
  }

  async getMyIssues(userId, { status, page = 1, limit = 20 } = {}) {
    const filter = { customer: userId };
    if (status) filter.status = status;
    const skip = (Number(page) - 1) * Number(limit);
    const [issues, total] = await Promise.all([
      populateIssue(SupportIssue.find(filter).sort({ createdAt: -1 }).skip(skip).limit(Number(limit))),
      SupportIssue.countDocuments(filter),
    ]);
    return {
      issues,
      pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) },
    };
  }

  async getAdminIssues({ status, priority, type, page = 1, limit = 50 } = {}) {
    const filter = {};
    if (status) filter.status = status;
    if (priority) filter.priority = priority;
    if (type) filter.type = type;
    const skip = (Number(page) - 1) * Number(limit);
    const [issues, total] = await Promise.all([
      populateIssue(SupportIssue.find(filter).sort({ priority: -1, createdAt: -1 }).skip(skip).limit(Number(limit))),
      SupportIssue.countDocuments(filter),
    ]);
    return {
      issues,
      pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) },
    };
  }

  async updateStatus(issueId, { status, adminNotes = '' }) {
    const allowed = ['open', 'reviewing', 'waiting_customer', 'waiting_worker', 'closed'];
    if (!allowed.includes(status)) throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid support issue status.');
    const issue = await SupportIssue.findById(issueId);
    if (!issue) throw new ApiError(StatusCodes.NOT_FOUND, 'Support issue not found.');
    if (issue.status === 'resolved') throw new ApiError(StatusCodes.BAD_REQUEST, 'Resolved issues cannot be reopened.');
    issue.status = status;
    if (adminNotes) issue.adminNotes = String(adminNotes).trim().slice(0, 1000);
    await issue.save();
    const populated = await populateIssue(SupportIssue.findById(issue._id));
    Promise.resolve(notifSvc.notifySupportIssueUpdated(populated)).catch(() => {});
    return populated;
  }

  async resolveIssue(issueId, adminId, { resolution, adminNotes = '' }) {
    if (!resolution) throw new ApiError(StatusCodes.BAD_REQUEST, 'resolution is required.');
    const issue = await SupportIssue.findById(issueId);
    if (!issue) throw new ApiError(StatusCodes.NOT_FOUND, 'Support issue not found.');
    if (issue.status === 'resolved') throw new ApiError(StatusCodes.BAD_REQUEST, 'Support issue is already resolved.');
    issue.status = 'resolved';
    issue.resolution = String(resolution).trim().slice(0, 1500);
    if (adminNotes) issue.adminNotes = String(adminNotes).trim().slice(0, 1000);
    issue.resolvedBy = adminId;
    issue.resolvedAt = new Date();
    await issue.save();
    const populated = await populateIssue(SupportIssue.findById(issue._id));
    Promise.resolve(notifSvc.notifySupportIssueResolved(populated)).catch(() => {});
    return populated;
  }

  async escalateToDispute(issueId, adminId, { resolution = '' } = {}) {
    const issue = await populateIssue(SupportIssue.findById(issueId));
    if (!issue) throw new ApiError(StatusCodes.NOT_FOUND, 'Support issue not found.');
    if (!issue.booking || issue.booking.status !== 'awaiting_customer_confirmation') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Only completion-review support issues can be escalated to a payment dispute.');
    }

    const dispute = await disputeService.openDispute(
      issue.booking._id,
      issue.customer._id || issue.customer,
      resolution || issue.description,
      issue.evidence,
      issue.type === 'safety' ? 'safety' : 'other'
    );

    issue.status = 'closed';
    issue.adminNotes = 'Escalated to payment dispute.';
    issue.resolvedBy = adminId;
    issue.resolvedAt = new Date();
    await issue.save();

    return { issue, dispute };
  }
}

module.exports = new SupportIssueService();
