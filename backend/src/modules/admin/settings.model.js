const mongoose = require('mongoose');

const settingsSchema = new mongoose.Schema({
  commissionRate:       { type: Number, default: 10 },
  maxCashLiability:     { type: Number, default: 5000 },
  cashDebtWarningThreshold: { type: Number, default: 1000 },
  cashDebtBlockThreshold:   { type: Number, default: 5000 },
  cashDebtAutoBlockEnabled: { type: Boolean, default: true },
  autoReleaseWindow:    { type: Number, default: 48 },
  minDepositPct:        { type: Number, default: 20 },
  minBookingAmount:     { type: Number, default: 100 },
  cashPaymentsEnabled:  { type: Boolean, default: true },
  reqNationalId:        { type: Boolean, default: true },
  reqTradeLicense:      { type: Boolean, default: false },
  autoSuspendDisputes:  { type: Number, default: 3 },
  minRatingFlag:        { type: Number, default: 2 },
  maxCashJobsDay:       { type: Number, default: 5 },
  notifNewUser:         { type: Boolean, default: true },
  notifNewTech:         { type: Boolean, default: true },
  notifNewDispute:      { type: Boolean, default: true },
  notifOverduePayment:  { type: Boolean, default: true },
  notifDailySummary:    { type: Boolean, default: false },
  adminAlertEmail:      { type: String, default: '' },
  twoFAEnabled:         { type: Boolean, default: false },
  sessionTimeout:       { type: Number, default: 60 },
  maintenanceMode:      { type: Boolean, default: false },
  platformName:         { type: String, default: 'Servio' },
  supportEmail:         { type: String, default: '' },
  maxUploadSize:        { type: Number, default: 15 },
  flagAiMatch:          { type: Boolean, default: true },
  flagCashPayments:     { type: Boolean, default: true },
  flagTechSignup:       { type: Boolean, default: true },
  flagReviews:          { type: Boolean, default: true },
  travelBufferMin:        { type: Number, default: 30,  min: 0 },
  extensionMinutes:       { type: Number, default: 30,  min: 0 },
  maxExtensionMultiplier: { type: Number, default: 2,   min: 1 },
  stuckJobBufferMin:      { type: Number, default: 120, min: 0 },
  favoritesSoftCap:       { type: Number, default: 50,  min: 0 },

  // Max billable minutes per category. Key = category string, value = minutes.
  // e.g. { electrical: 180, plumbing: 240, cleaning: 300 }
  // Jobs exceeding cap are flagged for admin review before payout.
  categoryDurationCaps: {
    type:    Map,
    of:      Number,
    default: {
      electrical: 180,
      plumbing:   240,
      cleaning:   300,
      painting:   360,
      carpentry:  300,
      ac:         360,
    },
  },

  // Anomaly threshold: flag job if actualBilledMin > estimatedDurationMin * multiplier
  anomalyMultiplier: { type: Number, default: 2, min: 1 },
}, { timestamps: true });

module.exports = mongoose.model('Settings', settingsSchema);
