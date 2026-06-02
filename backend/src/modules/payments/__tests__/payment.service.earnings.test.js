const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../../bookings/booking.model');
const Payment = require('../payment.model');
const CashDebt = require('../cash-debt.model');
const Transaction = require('../transaction.model');
const Wallet = require('../wallet.model');
const service = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

describe('paymentService earnings breakdown', () => {
  test('returns canonical mixed cash and card take-home breakdown', async () => {
    const user = id();
    const worker = id();
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const cashDate = new Date(monthStart.getTime() + 3600000);
    const cardDate = new Date(monthStart.getTime() + 2 * 3600000);
    const releaseDate = new Date(monthStart.getTime() + 3 * 3600000);

    const cashBooking = await Booking.create({
      user,
      worker,
      service: id(),
      serviceCategory: 'Plumbing',
      serviceName: 'Leak repair',
      scheduledDate: cashDate,
      actualCompletedAt: cashDate,
      address: 'Nasr City, Cairo',
      status: 'completed',
      paymentMethod: 'cash',
      paymentStatus: 'cash_settled',
      estimatedTotal: 379.5,
      totalPrice: 345,
      platformFeeAmount: 34.5,
    });

    await CashDebt.create({
      worker,
      booking: cashBooking._id,
      amount: 34.5,
      paidAmount: 34.5,
      remaining: 0,
      status: 'paid',
      settlementMethod: 'auto_offset',
      paidBy: 'auto_wallet',
      paidAt: releaseDate,
    });

    const cardBooking = await Booking.create({
      user,
      worker,
      service: id(),
      serviceCategory: 'Plumbing',
      serviceName: 'Pipe replacement',
      scheduledDate: cardDate,
      actualCompletedAt: cardDate,
      address: 'Nasr City, Cairo',
      status: 'completed',
      paymentMethod: 'card',
      paymentStatus: 'released',
      estimatedTotal: 379.5,
      totalPrice: 345,
      platformFeeAmount: 34.5,
    });

    const payment = await Payment.create({
      booking: cardBooking._id,
      user,
      worker,
      amount: 379.5,
      platformFee: 34.5,
      workerEarning: 345,
      status: 'released',
      paymentMethod: 'online',
      skipFeeCalc: true,
      heldAt: new Date(cardDate.getTime() - 2 * 3600000),
      releasedAt: releaseDate,
    });

    const wallet = await Wallet.create({
      worker,
      balance: 310.5,
      totalEarned: 310.5,
      totalWithdrawn: 0,
      pendingBalance: 0,
    });

    await Transaction.create({
      payment: payment._id,
      wallet: wallet._id,
      type: 'release',
      amount: 310.5,
      currency: 'egp',
      direction: 'credit',
      actor: id(),
      note: `Escrow released to worker for booking ${cardBooking._id} (gross 345, after debt offset 310.5)`,
      createdAt: releaseDate,
    });

    const result = await service.getWorkerEarnings(worker);
    const breakdown = result.breakdown;

    expect(breakdown.availableToWithdraw).toBeCloseTo(310.5, 2);
    expect(breakdown.pendingRelease).toBe(0);
    expect(breakdown.pendingJobsCount).toBe(0);
    expect(breakdown.outstandingCashFees).toBe(0);
    expect(breakdown.collectedCashNet).toBeCloseTo(310.5, 2);
    expect(breakdown.cashCompletedJobsCount).toBe(1);
    expect(breakdown.walletReleasedNet).toBeCloseTo(310.5, 2);
    expect(breakdown.lifetimeTakeHome).toBeCloseTo(621, 2);
    expect(breakdown.thisMonthTakeHome).toBeCloseTo(621, 2);
    expect(breakdown.lastMonthTakeHome).toBe(0);
    expect(breakdown.cashFeesLifetime).toBeCloseTo(34.5, 2);
    expect(breakdown.averageCashFee).toBeCloseTo(34.5, 2);
    expect(breakdown.completedJobs).toBe(2);
    expect(breakdown.outstandingCashFeeItems).toHaveLength(0);
    expect(breakdown.sevenDayTrend).toHaveLength(7);

    const settlementTypes = breakdown.recentEarnings.map((item) => item.settlementType);
    expect(settlementTypes).toEqual(expect.arrayContaining(['cash_collected', 'released_after_offset']));

    const releasedItem = breakdown.recentEarnings.find((item) => item.bookingId.toString() === cardBooking._id.toString());
    expect(releasedItem.walletCreditAmount).toBeCloseTo(310.5, 2);
    expect(releasedItem.displayAmount).toBeCloseTo(310.5, 2);
  });

  test('reconcileWorkerWalletState clears cancelled holds and keeps valid pending money', async () => {
    const user = id();
    const worker = id();
    const now = new Date();

    await Wallet.create({
      worker,
      balance: 0,
      totalEarned: 0,
      totalWithdrawn: 0,
      pendingBalance: 690,
    });

    const activeBooking = await Booking.create({
      user,
      worker,
      service: id(),
      serviceCategory: 'Plumbing',
      serviceName: 'Valve install',
      scheduledDate: new Date(now.getTime() + 86400000),
      address: 'Heliopolis, Cairo',
      status: 'accepted',
      paymentMethod: 'card',
      paymentStatus: 'held',
      estimatedTotal: 379.5,
      totalPrice: 345,
      platformFeeAmount: 34.5,
    });

    const staleBooking = await Booking.create({
      user,
      worker,
      service: id(),
      serviceCategory: 'Plumbing',
      serviceName: 'Drain fix',
      scheduledDate: new Date(now.getTime() - 86400000),
      cancelledAt: new Date(now.getTime() - 43200000),
      address: 'Heliopolis, Cairo',
      status: 'cancelled',
      paymentMethod: 'card',
      paymentStatus: 'refunded',
      estimatedTotal: 379.5,
      totalPrice: 345,
      platformFeeAmount: 34.5,
    });

    const activePayment = await Payment.create({
      booking: activeBooking._id,
      user,
      worker,
      amount: 379.5,
      platformFee: 34.5,
      workerEarning: 345,
      status: 'held',
      paymentMethod: 'online',
      skipFeeCalc: true,
      heldAt: now,
    });

    const stalePayment = await Payment.create({
      booking: staleBooking._id,
      user,
      worker,
      amount: 379.5,
      platformFee: 34.5,
      workerEarning: 345,
      status: 'held',
      paymentMethod: 'online',
      skipFeeCalc: true,
      heldAt: new Date(now.getTime() - 86400000),
    });

    const reconciliation = await service.reconcileWorkerWalletState(worker);
    const walletAfter = await Wallet.findOne({ worker });
    const activeAfter = await Payment.findById(activePayment._id);
    const staleAfter = await Payment.findById(stalePayment._id);

    expect(reconciliation.expectedPendingBalance).toBeCloseTo(345, 2);
    expect(reconciliation.skippedPendingReconcile).toBe(false);
    expect(reconciliation.normalizedPayments).toBe(1);
    expect(walletAfter.pendingBalance).toBeCloseTo(345, 2);
    expect(activeAfter.status).toBe('held');
    expect(staleAfter.status).toBe('refunded');
    expect(staleAfter.refundedAt).toBeInstanceOf(Date);
  });
});
