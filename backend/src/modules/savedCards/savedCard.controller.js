const { StatusCodes } = require('http-status-codes');
const SavedCard = require('./savedCard.model');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');

const MAX_CARDS = 3;

const getCards = async (req, res) => {
  const cards = await SavedCard.find({ userId: req.user.id }).sort({ createdAt: 1 });
  return ApiResponse.success(res, StatusCodes.OK, 'Cards retrieved.', cards);
};

const addCard = async (req, res) => {
  const count = await SavedCard.countDocuments({ userId: req.user.id });
  if (count >= MAX_CARDS) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Maximum ${MAX_CARDS} saved cards allowed.`);
  }

  const { last4, expiry, cardType, label } = req.body;
  if (!last4 || !expiry) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'last4 and expiry are required.');
  }

  const isDefault = count === 0;

  try {
    const card = await SavedCard.create({ userId: req.user.id, last4, expiry, cardType, label, isDefault });
    return ApiResponse.success(res, StatusCodes.CREATED, 'Card saved.', card);
  } catch (err) {
    if (err.code === 11000) {
      throw new ApiError(StatusCodes.CONFLICT, 'This card is already saved.');
    }
    throw err;
  }
};

const deleteCard = async (req, res) => {
  const card = await SavedCard.findOne({ _id: req.params.id, userId: req.user.id });
  if (!card) throw new ApiError(StatusCodes.NOT_FOUND, 'Card not found.');

  const wasDefault = card.isDefault;
  await SavedCard.deleteOne({ _id: card._id });

  if (wasDefault) {
    const next = await SavedCard.findOne({ userId: req.user.id }).sort({ createdAt: 1 });
    if (next) await SavedCard.updateOne({ _id: next._id }, { isDefault: true });
  }

  return ApiResponse.success(res, StatusCodes.OK, 'Card removed.');
};

const setDefault = async (req, res) => {
  const card = await SavedCard.findOne({ _id: req.params.id, userId: req.user.id });
  if (!card) throw new ApiError(StatusCodes.NOT_FOUND, 'Card not found.');

  await SavedCard.updateMany({ userId: req.user.id }, { isDefault: false });
  await SavedCard.updateOne({ _id: card._id }, { isDefault: true });

  const updated = await SavedCard.findById(card._id);
  return ApiResponse.success(res, StatusCodes.OK, 'Default card updated.', updated);
};

module.exports = { getCards, addCard, deleteCard, setDefault };
