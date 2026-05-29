'use strict';

const mongoose = require('mongoose');

const Payment = require('../modules/payments/payment.model');
const Wallet = require('../modules/payments/wallet.model');
const paymentService = require('../modules/payments/payment.service');

async function collectWorkerIds(targetWorkerId) {
  if (targetWorkerId) return [targetWorkerId];

  const [walletWorkers, paymentWorkers] = await Promise.all([
    Wallet.distinct('worker', {}),
    Payment.distinct('worker', {
      status: { $in: ['held', 'disputed', 'partially_refunded'] },
    }),
  ]);

  return [...new Set([...walletWorkers, ...paymentWorkers].map((value) => String(value || '')).filter(Boolean))];
}

async function run({ workerId } = {}) {
  const workerIds = await collectWorkerIds(workerId);

  for (const currentWorkerId of workerIds) {
    const session = await mongoose.startSession();
    let result = null;
    try {
      await session.withTransaction(async () => {
        result = await paymentService.reconcileWorkerWalletState(currentWorkerId, session);
      });
      console.log(
        `[wallet-reconcile] worker=${currentWorkerId} pending=${result?.expectedPendingBalance ?? 0} normalized=${result?.normalizedPayments ?? 0} skipped=${result?.skippedPendingReconcile ? 'yes' : 'no'}`
      );
    } finally {
      await session.endSession();
    }
  }
}

module.exports = { run };

if (require.main === module) {
  (async () => {
    const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
    if (!uri) throw new Error('MONGO_URI env var is required.');
    await mongoose.connect(uri);
    await run({ workerId: process.env.WORKER_ID || '' });
    await mongoose.disconnect();
  })().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
