// ─── Purpose ──────────────────────────────────────────────────────────────────
// Stripe configuration. Initialises the SDK lazily (on first use) to avoid
// crashing at startup when STRIPE_SECRET_KEY is not yet configured.
//
// TWO separate keys are needed:
//   STRIPE_SECRET_KEY      — your server-side API key (sk_test_... / sk_live_...)
//   STRIPE_WEBHOOK_SECRET  — the signing secret for webhook events (whsec_...)
//   These are DIFFERENT credentials. Never confuse them.
//
// Get both from: https://dashboard.stripe.com/apikeys
//                https://dashboard.stripe.com/webhooks
// ─────────────────────────────────────────────────────────────────────────────

const Stripe          = require('stripe');
const ApiError        = require('../utils/ApiError');
const { StatusCodes } = require('http-status-codes');

// Lazy-loaded Stripe instance — not created until first API call.
// This prevents the server from crashing at startup if the key is a placeholder.
let _stripe = null;

const getStripe = () => {
  if (!_stripe) {
    if (!process.env.STRIPE_SECRET_KEY || process.env.STRIPE_SECRET_KEY.startsWith('sk_test_your')) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Stripe is not configured. Please set STRIPE_SECRET_KEY in your .env file.'
      );
    }
    _stripe = Stripe(process.env.STRIPE_SECRET_KEY);
  }
  return _stripe;
};

// Proxy object — calling stripe.anyMethod() lazily loads the Stripe instance
const stripe = new Proxy({}, {
  get: (_, prop) => {
    const instance = getStripe();
    const value = instance[prop];
    return typeof value === 'function' ? value.bind(instance) : value;
  },
});

// ── verifyWebhookSignature ────────────────────────────────────────────────────
// WHAT: Validates that a webhook request genuinely came from Stripe.
// WHY:  Without this check, anyone could POST fake events to trigger
//       money movement. Stripe signs every event with STRIPE_WEBHOOK_SECRET.
// HOW:  Requires the raw (un-parsed) request body — that's why the webhook
//       route must use express.raw() and NOT express.json().
const verifyWebhookSignature = (rawBody, signature) => {
  if (!process.env.STRIPE_WEBHOOK_SECRET) {
    throw new ApiError(
      StatusCodes.INTERNAL_SERVER_ERROR,
      'Webhook secret is not configured. Please set STRIPE_WEBHOOK_SECRET in your .env file.'
    );
  }

  try {
    return getStripe().webhooks.constructEvent(
      rawBody,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Webhook signature verification failed: ${err.message}`
    );
  }
};

module.exports = { stripe, verifyWebhookSignature };
