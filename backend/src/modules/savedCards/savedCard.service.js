const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');
const SavedCard = require('./savedCard.model');
const getGateway = require('../payments/gateways');
const ApiError = require('../../utils/ApiError');

const MAX_CARDS = 3;

function brandToCardType(brand) {
  const b = String(brand || '').toLowerCase();
  if (b === 'visa' || b === 'mastercard' || b === 'amex') return b;
  return 'other';
}

function formatExpiry(month, year) {
  const mm = String(month).padStart(2, '0');
  const yy = String(year).slice(-2).padStart(2, '0');
  return `${mm}/${yy}`;
}

async function add(userId, { gatewayToken, gateway = 'demo', label } = {}) {
  if (!gatewayToken) throw new ApiError(StatusCodes.BAD_REQUEST, 'gatewayToken is required.');

  const count = await SavedCard.countDocuments({ userId });
  if (count >= MAX_CARDS) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Maximum ${MAX_CARDS} saved cards allowed.`);
  }

  const gw = getGateway();
  if (typeof gw.attachPaymentMethod !== 'function') {
    throw new ApiError(StatusCodes.NOT_IMPLEMENTED, 'Tokenization not supported by gateway.');
  }
  const pm = await gw.attachPaymentMethod(userId, gatewayToken);

  return SavedCard.create({
    userId,
    gateway,
    gatewayCustomerId:      pm.customerId,
    gatewayPaymentMethodId: pm.paymentMethodId,
    brand:                  pm.brand,
    cardType:               brandToCardType(pm.brand),
    last4:                  pm.last4,
    expiry:                 formatExpiry(pm.expMonth, pm.expYear),
    label,
    isDefault:              count === 0,
  });
}

async function listForUser(userId) {
  return SavedCard.find({ userId }).sort({ isDefault: -1, createdAt: -1 });
}

async function remove(userId, cardId) {
  const card = await SavedCard.findOne({ _id: cardId, userId });
  if (!card) throw new ApiError(StatusCodes.NOT_FOUND, 'Card not found.');

  if (card.gatewayPaymentMethodId) {
    try {
      const gw = getGateway();
      if (typeof gw.detachPaymentMethod === 'function') {
        await gw.detachPaymentMethod(card.gatewayPaymentMethodId);
      }
    } catch (_) { /* non-fatal: still detach locally */ }
  }

  const wasDefault = card.isDefault;
  await SavedCard.deleteOne({ _id: card._id });

  if (wasDefault) {
    const next = await SavedCard.findOne({ userId }).sort({ createdAt: -1 });
    if (next) { next.isDefault = true; await next.save(); }
  }
}

async function setDefault(userId, cardId) {
  const session = await mongoose.startSession();
  try {
    let updated;
    await session.withTransaction(async () => {
      await SavedCard.updateMany({ userId }, { $set: { isDefault: false } }, { session });
      updated = await SavedCard.findOneAndUpdate(
        { _id: cardId, userId },
        { $set: { isDefault: true } },
        { session, new: true }
      );
      if (!updated) throw new ApiError(StatusCodes.NOT_FOUND, 'Card not found.');
    });
    return updated;
  } finally { await session.endSession(); }
}

module.exports = { add, listForUser, remove, setDefault, MAX_CARDS };
