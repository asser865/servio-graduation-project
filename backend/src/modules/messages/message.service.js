const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const Message = require('./message.model');
const Conversation = require('./conversation.model');
const Booking = require('../bookings/booking.model');
const User = require('../users/user.model');
const ApiError = require('../../utils/ApiError');

const PARTICIPANT_SELECT = 'name role profileImage';

function idsEqual(a, b) {
  return a?.toString() === b?.toString();
}

function normalizeText(payload) {
  return (payload.content || payload.body || payload.text || '').trim();
}

function assertObjectId(value, label) {
  if (!mongoose.Types.ObjectId.isValid(value)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Valid ${label} required`);
  }
}

function unreadValue(conversation, userId) {
  const counts = conversation.unreadCounts;
  if (!counts) return 0;
  if (typeof counts.get === 'function') return counts.get(userId.toString()) || 0;
  return counts[userId.toString()] || 0;
}

function setUnreadValue(conversation, userId, value) {
  const key = userId.toString();
  if (!conversation.unreadCounts) conversation.unreadCounts = {};
  if (typeof conversation.unreadCounts.set === 'function') {
    conversation.unreadCounts.set(key, value);
  } else {
    conversation.unreadCounts[key] = value;
  }
}

async function ensureParticipant(conversation, userId) {
  const isParticipant = conversation.participants.some((id) => idsEqual(id, userId));
  if (!isParticipant) throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
}

async function findOrCreateConversation({ senderId, receiverId, bookingId }) {
  let customerId;
  let workerId;
  let booking = null;

  if (bookingId) {
    assertObjectId(bookingId, 'booking ID');
    booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');

    const isParticipant = idsEqual(booking.user, senderId) || idsEqual(booking.worker, senderId);
    if (!isParticipant) throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');

    customerId = booking.user;
    workerId = booking.worker;
    receiverId = idsEqual(customerId, senderId) ? workerId : customerId;
  } else {
    if (!receiverId) throw new ApiError(StatusCodes.BAD_REQUEST, 'receiverId is required');
    assertObjectId(receiverId, 'receiver ID');
    if (idsEqual(senderId, receiverId)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Sender and receiver cannot be the same user');
    }

    const [sender, receiver] = await Promise.all([
      User.findById(senderId).select('role isActive'),
      User.findById(receiverId).select('role isActive'),
    ]);
    if (!sender) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Sender not found');
    if (!receiver || !receiver.isActive) throw new ApiError(StatusCodes.NOT_FOUND, 'Receiver not found');

    if (sender.role === 'user' && receiver.role === 'worker') {
      customerId = senderId;
      workerId = receiverId;
    } else if (sender.role === 'worker' && receiver.role === 'user') {
      customerId = receiverId;
      workerId = senderId;
    } else {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Messages are only allowed between customers and workers');
    }
  }

  const filter = booking
    ? { customer: customerId, worker: workerId, booking: booking._id }
    : { customer: customerId, worker: workerId, booking: null };

  let conversation = await Conversation.findOne(filter);
  if (!conversation) {
    conversation = await Conversation.create({
      participants: [customerId, workerId],
      customer: customerId,
      worker: workerId,
      booking: booking ? booking._id : null,
      unreadCounts: {
        [customerId.toString()]: 0,
        [workerId.toString()]: 0,
      },
    });
  }

  return { conversation, receiverId };
}

async function resolveConversation(senderId, payload) {
  if (payload.conversationId) {
    assertObjectId(payload.conversationId, 'conversation ID');
    const conversation = await Conversation.findById(payload.conversationId);
    if (!conversation) throw new ApiError(StatusCodes.NOT_FOUND, 'Conversation not found');
    await ensureParticipant(conversation, senderId);
    const receiverId = conversation.participants.find((id) => !idsEqual(id, senderId));
    return { conversation, receiverId };
  }

  return findOrCreateConversation({
    senderId,
    receiverId: payload.receiverId || payload.workerId || payload.customerId,
    bookingId: payload.bookingId,
  });
}

async function sendMessage(senderId, payload) {
  const content = normalizeText(payload);
  if (!content) throw new ApiError(StatusCodes.BAD_REQUEST, 'Message content required');
  if (content.length > 2000) throw new ApiError(StatusCodes.BAD_REQUEST, 'Message content cannot exceed 2000 characters');

  const { conversation, receiverId } = await resolveConversation(senderId, payload);
  if (!receiverId || idsEqual(receiverId, senderId)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Receiver is invalid');
  }

  const message = await Message.create({
    conversation: conversation._id,
    booking: conversation.booking || null,
    sender: senderId,
    recipient: receiverId,
    content,
  });

  const receiverKey = receiverId.toString();
  const nextUnread = unreadValue(conversation, receiverKey) + 1;
  conversation.lastMessage = message._id;
  conversation.lastMessageText = content;
  conversation.lastMessageAt = message.createdAt;
  setUnreadValue(conversation, receiverKey, nextUnread);
  await conversation.save();

  const populated = await message.populate([
    { path: 'sender', select: PARTICIPANT_SELECT },
    { path: 'recipient', select: PARTICIPANT_SELECT },
  ]);

  return {
    message: serializeMessage(populated),
    conversation: await serializeConversationById(conversation._id, senderId),
  };
}

async function startConversation(userId, payload) {
  const { conversation } = await findOrCreateConversation({
    senderId: userId,
    receiverId: payload.receiverId || payload.workerId || payload.customerId,
    bookingId: payload.bookingId,
  });
  return serializeConversationById(conversation._id, userId);
}

async function getMessages(userId, conversationOrBookingId) {
  assertObjectId(conversationOrBookingId, 'conversation ID');
  let conversation = await Conversation.findById(conversationOrBookingId);
  if (!conversation) {
    const { conversation: byBooking } = await findOrCreateConversation({
      senderId: userId,
      bookingId: conversationOrBookingId,
    });
    conversation = byBooking;
  }

  await ensureParticipant(conversation, userId);
  await Message.updateMany(
    { conversation: conversation._id, recipient: userId, read: false },
    { read: true, readAt: new Date() }
  );
  setUnreadValue(conversation, userId, 0);
  await conversation.save();

  const messages = await Message.find({ conversation: conversation._id })
    .sort({ createdAt: 1 })
    .populate('sender', PARTICIPANT_SELECT)
    .populate('recipient', PARTICIPANT_SELECT);

  return {
    conversation: await serializeConversationById(conversation._id, userId),
    messages: messages.map(serializeMessage),
  };
}

async function getUnreadCount(userId) {
  return Message.countDocuments({ recipient: userId, read: false });
}

async function getConversations(userId) {
  const conversations = await Conversation.find({ participants: userId })
    .sort({ lastMessageAt: -1, updatedAt: -1 })
    .limit(100)
    .populate('customer', PARTICIPANT_SELECT)
    .populate('worker', PARTICIPANT_SELECT)
    .populate('booking', 'serviceName serviceCategory status scheduledDate')
    .populate('lastMessage');

  return conversations.map((conversation) => serializeConversation(conversation, userId));
}

async function deleteConversation(userId, conversationId) {
  assertObjectId(conversationId, 'conversation ID');
  const conversation = await Conversation.findById(conversationId);
  if (!conversation) throw new ApiError(StatusCodes.NOT_FOUND, 'Conversation not found');

  await ensureParticipant(conversation, userId);

  const messageDeleteResult = await Message.deleteMany({ conversation: conversation._id });
  await Conversation.deleteOne({ _id: conversation._id });

  return {
    conversationId: conversation._id?.toString(),
    deletedMessages: messageDeleteResult.deletedCount || 0,
  };
}

async function archiveConversation(userId, conversationId, archive = true) {
  assertObjectId(conversationId, 'conversation ID');
  const conversation = await Conversation.findById(conversationId);
  if (!conversation) throw new ApiError(StatusCodes.NOT_FOUND, 'Conversation not found');
  await ensureParticipant(conversation, userId);

  const uid = userId.toString();
  const alreadyArchived = conversation.archivedBy.some((id) => id.toString() === uid);

  if (archive && !alreadyArchived) {
    conversation.archivedBy.push(userId);
    await conversation.save();
  } else if (!archive && alreadyArchived) {
    conversation.archivedBy = conversation.archivedBy.filter((id) => id.toString() !== uid);
    await conversation.save();
  }

  return serializeConversationById(conversation._id, userId);
}

function userSummary(user) {
  if (!user) return null;
  return {
    _id: user._id,
    id: user._id?.toString(),
    name: user.name,
    role: user.role,
    profileImage: user.profileImage || null,
    avatar: user.profileImage || null,
  };
}

function serializeMessage(message) {
  const senderId = message.sender?._id || message.sender;
  const recipientId = message.recipient?._id || message.recipient;
  return {
    _id: message._id,
    id: message._id?.toString(),
    conversation: message.conversation,
    conversationId: message.conversation?.toString(),
    booking: message.booking,
    bookingId: message.booking?.toString() || null,
    sender: message.sender,
    senderId: senderId?.toString(),
    receiver: message.recipient,
    receiverId: recipientId?.toString(),
    recipient: message.recipient,
    content: message.content,
    body: message.content,
    text: message.content,
    read: message.read,
    readAt: message.readAt,
    createdAt: message.createdAt,
    updatedAt: message.updatedAt,
  };
}

async function serializeConversationById(conversationId, viewerId) {
  const conversation = await Conversation.findById(conversationId)
    .populate('customer', PARTICIPANT_SELECT)
    .populate('worker', PARTICIPANT_SELECT)
    .populate('booking', 'serviceName serviceCategory status scheduledDate')
    .populate('lastMessage');
  return serializeConversation(conversation, viewerId);
}

function serializeConversation(conversation, viewerId) {
  const isCustomer = idsEqual(conversation.customer?._id || conversation.customer, viewerId);
  const otherUser = isCustomer ? conversation.worker : conversation.customer;
  const lastMessage = conversation.lastMessage
    ? serializeMessage(conversation.lastMessage)
    : null;

  return {
    _id: conversation._id,
    id: conversation._id?.toString(),
    conversationId: conversation._id?.toString(),
    participants: conversation.participants,
    customer: userSummary(conversation.customer),
    worker: userSummary(conversation.worker),
    otherUser: userSummary(otherUser),
    booking: conversation.booking || null,
    bookingId: conversation.booking?._id?.toString() || conversation.booking?.toString() || null,
    lastMessage,
    lastMessageText: conversation.lastMessageText || lastMessage?.content || '',
    lastMessageAt: conversation.lastMessageAt || lastMessage?.createdAt || conversation.updatedAt,
    updatedAt: conversation.lastMessageAt || conversation.updatedAt,
    unreadCount: unreadValue(conversation, viewerId),
    isArchived: (conversation.archivedBy || []).some((id) => id.toString() === viewerId.toString()),
    createdAt: conversation.createdAt,
  };
}

module.exports = {
  sendMessage,
  startConversation,
  getMessages,
  getUnreadCount,
  getConversations,
  deleteConversation,
  archiveConversation,
  findOrCreateConversation,
};
