const { StatusCodes } = require('http-status-codes');
const ContactMessage = require('./contact-message.model');
const ApiError = require('../../utils/ApiError');
const { sendContactReplyEmail } = require('../../utils/email');

async function populateMessage(query) {
  return query.populate('userId', 'name email');
}

class ContactMessageService {
  async create(userId, { name, email, subject, message }) {
    if (!name || !email || !subject || !message) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'name, email, subject, and message are required.');
    }

    const docData = { name, email, subject, message };
    if (userId) docData.userId = userId;

    const doc = await ContactMessage.create(docData);
    return populateMessage(ContactMessage.findById(doc._id));
  }

  async getAll({ status, page = 1, limit = 50 } = {}) {
    const filter = {};
    if (status) filter.status = status;
    const skip = (Number(page) - 1) * Number(limit);
    const [messages, total] = await Promise.all([
      populateMessage(
        ContactMessage.find(filter).sort({ createdAt: -1 }).skip(skip).limit(Number(limit))
      ),
      ContactMessage.countDocuments(filter),
    ]);
    return {
      messages,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async update(id, { status, adminReply }) {
    const allowedStatuses = ['new', 'replied', 'closed'];
    if (status && !allowedStatuses.includes(status)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid status value.');
    }
    const doc = await ContactMessage.findById(id);
    if (!doc) throw new ApiError(StatusCodes.NOT_FOUND, 'Contact message not found.');
    
    if (adminReply !== undefined && String(adminReply).trim()) {
      doc.adminReply = String(adminReply).trim().slice(0, 3000);
      doc.status = 'replied';
      
      // Trigger email sending
      try {
        await sendContactReplyEmail(
          doc.email,
          doc.name,
          doc.subject,
          doc.message,
          doc.adminReply
        );
      } catch (err) {
        console.error('Failed to send contact reply email:', err);
      }
    } else if (status) {
      doc.status = status;
    }

    await doc.save();
    return populateMessage(ContactMessage.findById(doc._id));
  }
}

module.exports = new ContactMessageService();
