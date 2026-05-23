const DemoGateway = require('./demo.gateway');
const StripeGateway = require('./stripe.gateway');

let instance = null;
let currentId = null;

function getGateway() {
  const want = process.env.PAYMENT_GATEWAY || 'demo';
  if (instance && currentId === want) return instance;
  switch (want) {
    case 'stripe': instance = new StripeGateway(); break;
    case 'demo':
    default:       instance = new DemoGateway();
  }
  currentId = want;
  return instance;
}

module.exports = getGateway;
