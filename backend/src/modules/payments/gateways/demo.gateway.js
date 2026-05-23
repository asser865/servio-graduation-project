const { nanoid } = require('nanoid');
const PaymentGateway = require('./payment-gateway.interface');
const { retry, isGatewayRetryable } = require('../../../utils/retry');

const RETRY_OPTS = { attempts: 3, baseMs: 200, maxMs: 3000, retryable: isGatewayRetryable };

class DemoGateway extends PaymentGateway {
  get id() { return 'demo'; }

  async authorize({ amount, currency, customerId, savedCardId, metadata }) {
    return retry(async () => {
      if (!amount || amount <= 0) throw new Error('Invalid amount');
      return {
        intentId: `demo_pi_${nanoid(21)}`,
        status: 'authorized',
        raw: { amount, currency, customerId, savedCardId, metadata, createdAt: new Date() },
      };
    }, RETRY_OPTS);
  }

  async capture({ intentId }) {
    return retry(async () => {
      if (!intentId || !intentId.startsWith('demo_pi_')) throw new Error('Invalid intent');
      return {
        chargeId: `demo_ch_${nanoid(21)}`,
        status: 'captured',
        raw: { intentId, capturedAt: new Date() },
      };
    }, RETRY_OPTS);
  }

  async refund({ chargeId, amount, reason }) {
    return retry(async () => {
      if (!chargeId) throw new Error('Invalid charge');
      return {
        refundId: `demo_rf_${nanoid(21)}`,
        status: 'refunded',
        raw: { chargeId, amount, reason, refundedAt: new Date() },
      };
    }, RETRY_OPTS);
  }

  async verifyWebhook({ rawBody, signature }) {
    return JSON.parse(rawBody.toString());
  }

  async attachPaymentMethod(userId, token) {
    const t = String(token || '');
    const brand =
      t.includes('mc') || t.includes('mastercard') ? 'mastercard' :
      t.includes('amex') ? 'amex' : 'visa';
    let hash = 0;
    for (let i = 0; i < t.length; i++) hash = (hash * 31 + t.charCodeAt(i)) >>> 0;
    const last4 = String(hash % 10000).padStart(4, '0');
    return {
      customerId:      `cus_demo_${userId}`,
      paymentMethodId: `pm_demo_${nanoid(16)}`,
      brand,
      last4,
      expMonth:        12,
      expYear:         new Date().getFullYear() + 2,
    };
  }

  async detachPaymentMethod(_paymentMethodId) {
    return true;
  }
}

module.exports = DemoGateway;
