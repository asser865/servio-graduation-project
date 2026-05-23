const PERMISSIONS = Object.freeze({
  PAYMENTS_RELEASE:    'payments:release',
  PAYMENTS_REFUND:     'payments:refund',
  PAYMENTS_DISPUTE:    'payments:dispute',
  PAYMENTS_EMERGENCY:  'payments:emergency',
  SETTLEMENTS_VERIFY:  'settlements:verify',
  SETTLEMENTS_REJECT:  'settlements:reject',
  PAYOUTS_APPROVE:     'payouts:approve',
  PAYOUTS_MARK_PAID:   'payouts:mark_paid',
  PAYOUTS_REJECT:      'payouts:reject',
  CREDITS_ISSUE:       'credits:issue',
  CASH_DEBTS_WRITE:    'cash_debts:write',
  USERS_SUSPEND:       'users:suspend',
  SETTINGS_WRITE:      'settings:write',
});

module.exports = PERMISSIONS;
module.exports.ALL = Object.values(PERMISSIONS);
