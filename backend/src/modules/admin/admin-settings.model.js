const mongoose = require('mongoose');

const adminSettingsSchema = new mongoose.Schema({
  key: { type: String, default: 'global', unique: true },
  escrow: {
    autoConfirmHours:             { type: Number, default: 48 },
    reminderHours:                { type: [Number], default: [24, 44] },
    postConfirmDisputeGraceHours: { type: Number, default: 24 },
    autoApproveEnabled:           { type: Boolean, default: false },
    autoApproveMaxAmount:         { type: Number, default: 50 },
  },
  cancellation: {
    lateFeePercent:     { type: Number, default: 50 },
    lateFeeStartStatus: { type: [String], default: ['en_route', 'arrived'] },
    strikeWindowDays:   { type: Number, default: 30 },
    strikeThreshold:    { type: Number, default: 3 },
    strikeBlockHours:   { type: Number, default: 24 },
    customerFreeWindowMinutes:   { type: Number, default: 15 },
    customerLateFeePercent:      { type: Number, default: 20 },
    workerStrikeWindowDays:      { type: Number, default: 30 },
    workerStrikesPerSuspension:  { type: Number, default: 3 },
    workerSuspensionDays:        { type: Number, default: 7 },
  },
  noShow: {
    workerWaitMinutes:           { type: Number, default: 30 },
    customerPingIntervalMinutes: { type: Number, default: 5 },
    workerLateGraceMinutes:      { type: Number, default: 60 },
    retainedWorkerPercent:       { type: Number, default: 70 },
    customerNoShowFeePercent:    { type: Number, default: 50 },
  },
  rePool: { retryWindowMinutes: { type: Number, default: 30 } },
  debt: {
    warningThreshold:       { type: Number, default: 200 },
    blockThreshold:         { type: Number, default: 300 },
    absoluteBlockThreshold: { type: Number, default: 500 },
    blockedCategories:      { type: [String], default: ['cash'] },
  },
  apology: {
    enabled:           { type: Boolean, default: true },
    defaultPctOfBase:  { type: Number, default: 0.2 },
    capAmount:         { type: Number, default: 10 },
    defaultExpiryDays: { type: Number, default: 90 },
  },
  vat: {
    rate:               { type: Number, default: 0.14 },
    registrationNumber: { type: String, default: '' },
    label:              { type: String, default: 'VAT' },
  },
  pricing: {
    overBandMultiplier: { type: Number, default: 1.5 },
  },
  payout: {
    minAmount:              { type: Number, default: 50 },
    processingBusinessDays: { type: Number, default: 3 },
  },
  dispute: {
    slaHours:                    { type: Number, default: 72 },
    autoEscalateAfterHours:      { type: Number, default: 72 },
    workerResponseDeadlineHours: { type: Number, default: 24 },
  },
  receipts: { retentionYears: { type: Number, default: 7 } },
  audit:    { retentionYears: { type: Number, default: 7 } },
  ratelimit: {
    disputeOpenPerDay:   { type: Number, default: 3 },
    settleSubmitPerHour: { type: Number, default: 5 },
    payoutRequestPerDay: { type: Number, default: 2 },
  },
  i18n: {
    defaultLocale:    { type: String, default: 'en' },
    supportedLocales: { type: [String], default: ['en', 'ar'] },
  },
  currency: {
    default:   { type: String, default: 'EGP' },
    supported: { type: [String], default: ['EGP'] },
  },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

module.exports = mongoose.model('AdminSettings', adminSettingsSchema);
