const { StatusCodes }  = require('http-status-codes');
const messageService   = require('./message.service');
const ApiResponse      = require('../../utils/ApiResponse');

const send = async (req, res) => {
  const result = await messageService.sendMessage(req.user.id, req.body);
  return ApiResponse.success(res, StatusCodes.CREATED, 'Message sent', result);
};

const list = async (req, res) => {
  const result = await messageService.getMessages(req.user.id, req.params.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Messages retrieved', result);
};

const unread = async (req, res) => {
  const count = await messageService.getUnreadCount(req.user.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Unread count', { count });
};

const conversations = async (req, res) => {
  const convos = await messageService.getConversations(req.user.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Conversations retrieved', { conversations: convos });
};

const startConversation = async (req, res) => {
  const conversation = await messageService.startConversation(req.user.id, req.body);
  return ApiResponse.success(res, StatusCodes.OK, 'Conversation ready', { conversation });
};

module.exports = { send, list, unread, conversations, startConversation };
