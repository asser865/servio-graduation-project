const PaymentGateway = require('./payment-gateway.interface');
const { retry, isGatewayRetryable } = require('../../../utils/retry');

const RETRY_OPTS = { attempts: 3, baseMs: 300, maxMs: 5000, retryable: isGatewayRetryable };

class StripeGateway extends PaymentGateway {
  get id() { return 'stripe'; }

  async authorize(args) {
    return retry(() => this._authorize(args), RETRY_OPTS);
  }
  async capture(args) {
    return retry(() => this._capture(args), RETRY_OPTS);
  }
  async refund(args) {
    return retry(() => this._refund(args), RETRY_OPTS);
  }

  async _authorize() { throw new Error('NotImplemented: StripeGateway.authorize'); }
  async _capture()   { throw new Error('NotImplemented: StripeGateway.capture (amount maps to amount_to_capture)'); }
  async _refund()    { throw new Error('NotImplemented: StripeGateway.refund'); }
  async verifyWebhook() { throw new Error('NotImplemented: StripeGateway.verifyWebhook'); }
  async attachPaymentMethod() { throw new Error('NotImplemented: StripeGateway.attachPaymentMethod'); }
  async detachPaymentMethod() { throw new Error('NotImplemented: StripeGateway.detachPaymentMethod'); }
}

module.exports = StripeGateway;
