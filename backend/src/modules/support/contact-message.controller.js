const { StatusCodes } = require('http-status-codes');
const contactMessageService = require('./contact-message.service');
const ApiResponse = require('../../utils/ApiResponse');

const create = async (req, res) => {
  const userId = req.user ? req.user.id : null;
  const doc = await contactMessageService.create(userId, req.body);
  return ApiResponse.success(res, StatusCodes.CREATED, 'Message sent successfully.', doc);
};

const getAll = async (req, res) => {
  const result = await contactMessageService.getAll(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Contact messages retrieved.', result);
};

const update = async (req, res) => {
  const doc = await contactMessageService.update(req.params.id, req.body);
  return ApiResponse.success(res, StatusCodes.OK, 'Contact message updated.', doc);
};

module.exports = {
  create,
  getAll,
  update,
};
