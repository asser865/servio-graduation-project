const COMPLETION_OUTCOME_VALUES = ['customer_paid', 'customer_refused_payment', 'could_not_complete'];

module.exports = {
  findById: jest.fn(),
  findOneAndUpdate: jest.fn(),
  COMPLETION_OUTCOME_VALUES,
  CUSTOMER_FEEDBACK_ACTIONS: ['confirmed', 'reported_issue', 'system_auto_confirmed'],
  CUSTOMER_ISSUE_REASONS: [
    'work_not_done',
    'work_damaged_property',
    'overcharged',
    'tech_unprofessional',
    'incomplete',
    'tech_did_not_arrive',
    'other',
  ],
};
