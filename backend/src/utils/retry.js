async function retry(fn, { attempts = 3, baseMs = 200, maxMs = 5000, retryable = () => true } = {}) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (!retryable(e) || i === attempts - 1) throw e;
      const wait = Math.min(maxMs, baseMs * Math.pow(2, i)) + Math.floor(Math.random() * baseMs);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  throw lastErr;
}

const GATEWAY_RETRYABLE_CODES = ['ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND', 'EAI_AGAIN', 'gateway_timeout'];
const isGatewayRetryable = (e) =>
  GATEWAY_RETRYABLE_CODES.includes(e?.code) ||
  (typeof e?.status === 'number' && e.status >= 500 && e.status < 600);

module.exports = { retry, isGatewayRetryable, GATEWAY_RETRYABLE_CODES };
