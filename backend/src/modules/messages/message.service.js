const Message  = require('./message.model');
const Booking  = require('../bookings/booking.model');
const ApiError = require('../../utils/ApiError');
const { StatusCodes } = require('http-status-codes');

async function sendMessage(senderId, { bookingId, content }) {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');

  const isParticipant =
    booking.user.toString()   === senderId.toString() ||
    booking.worker.toString() === senderId.toString();
  if (!isParticipant) throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');

  const recipientId = booking.user.toString() === senderId.toString()
    ? booking.worker
    : booking.user;

  const message = await Message.create({
    booking:   bookingId,
    sender:    senderId,
    recipient: recipientId,
    content,
  });

  return message.populate([
    { path: 'sender',    select: 'name role profileImage' },
    { path: 'recipient', select: 'name role profileImage' },
  ]);
}

async function getMessages(userId, bookingId) {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');

  const isParticipant =
    booking.user.toString()   === userId.toString() ||
    booking.worker.toString() === userId.toString();

  if (!isParticipant) throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');

  await Message.updateMany(
    { booking: bookingId, recipient: userId, read: false },
    { read: true }
  );

  return Message.find({ booking: bookingId })
    .sort({ createdAt: 1 })
    .populate('sender', 'name role profileImage')
    .populate('recipient', 'name role profileImage');
}

async function getUnreadCount(userId) {
  return Message.countDocuments({ recipient: userId, read: false });
}

async function getConversations(userId) {
  const mongoose = require('mongoose');
  const userObjId = new mongoose.Types.ObjectId(userId);
  const conversations = await Message.aggregate([
    { $match: { $or: [{ sender: userObjId }, { recipient: userObjId }] } },
    { $sort: { createdAt: -1 } },
    {
      $group: {
        _id: '$booking',
        lastMessage: { $first: '$$ROOT' },
        unreadCount: {
          $sum: {
            $cond: [{ $and: [{ $eq: ['$recipient', userObjId] }, { $eq: ['$read', false] }] }, 1, 0],
          },
        },
        otherUserId: {
          $first: {
            $cond: [{ $eq: ['$sender', userObjId] }, '$recipient', '$sender'],
          },
        },
      },
    },
    { $sort: { 'lastMessage.createdAt': -1 } },
    { $limit: 50 },
    { $lookup: { from: 'bookings', localField: '_id', foreignField: '_id', as: 'booking' } },
    { $unwind: { path: '$booking', preserveNullAndEmptyArrays: true } },
    { $lookup: { from: 'users', localField: 'otherUserId', foreignField: '_id', as: 'otherUserArr' } },
    { $unwind: { path: '$otherUserArr', preserveNullAndEmptyArrays: true } },
    {
      $addFields: {
        otherUser: {
          _id:          '$otherUserArr._id',
          name:         '$otherUserArr.name',
          profileImage: '$otherUserArr.profileImage',
          role:         '$otherUserArr.role',
        },
      },
    },
    { $project: { otherUserArr: 0, otherUserId: 0 } },
  ]);
  return conversations;
}

module.exports = { sendMessage, getMessages, getUnreadCount, getConversations };
