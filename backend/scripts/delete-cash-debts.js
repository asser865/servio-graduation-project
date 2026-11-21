'use strict';
require('dotenv').config();
const mongoose = require('mongoose');
const CashDebt = require('../src/modules/payments/cash-debt.model');

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  const debts = await CashDebt.find({ status: { $ne: 'paid' } }).lean();
  console.log(`Found ${debts.length} outstanding/partially_paid debt(s):`);
  debts.forEach(d => console.log(`  ${d._id} worker=${d.worker} amount=${d.amount} status=${d.status}`));
  const result = await CashDebt.deleteMany({ status: { $ne: 'paid' } });
  console.log(`Deleted ${result.deletedCount} debt record(s).`);
  await mongoose.disconnect();
}

main().catch(err => { console.error(err); process.exit(1); });
