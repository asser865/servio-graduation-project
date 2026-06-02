const { StatusCodes } = require('http-status-codes');
const ProblemReport = require('./problem-report.model');
const ApiError = require('../../utils/ApiError');

async function populateReport(query) {
  return query.populate('reporter', 'name email');
}

class ProblemReportService {
  async createReport(userId, { category, description, screenshotUrl }) {
    if (!category || !description) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'category and description are required.');
    }

    const docData = { category, description };
    if (screenshotUrl) docData.screenshotUrl = screenshotUrl;
    if (userId) docData.reporter = userId;

    const report = await ProblemReport.create(docData);
    return populateReport(ProblemReport.findById(report._id));
  }

  async getAllReports({ status, page = 1, limit = 50 } = {}) {
    const filter = {};
    if (status) filter.status = status;
    const skip = (Number(page) - 1) * Number(limit);
    const [reports, total] = await Promise.all([
      populateReport(
        ProblemReport.find(filter).sort({ createdAt: -1 }).skip(skip).limit(Number(limit))
      ),
      ProblemReport.countDocuments(filter),
    ]);
    return {
      reports,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async updateReport(id, { status, adminNotes }) {
    const allowedStatuses = ['open', 'resolved'];
    if (status && !allowedStatuses.includes(status)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid status value.');
    }
    const report = await ProblemReport.findById(id);
    if (!report) throw new ApiError(StatusCodes.NOT_FOUND, 'Problem report not found.');
    if (status) report.status = status;
    if (adminNotes !== undefined) report.adminNotes = String(adminNotes).trim().slice(0, 1000);
    await report.save();
    return populateReport(ProblemReport.findById(report._id));
  }
}

module.exports = new ProblemReportService();
