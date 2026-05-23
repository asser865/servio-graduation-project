class PaymentGateway {
  async authorize() { throw new Error('NotImplemented'); }
  async capture()   { throw new Error('NotImplemented'); }
  async refund()    { throw new Error('NotImplemented'); }
  async verifyWebhook() { throw new Error('NotImplemented'); }
  get id() { return 'base'; }
}

module.exports = PaymentGateway;
