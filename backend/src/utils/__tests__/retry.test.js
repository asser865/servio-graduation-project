const { retry, isGatewayRetryable } = require('../retry');

describe('retry util', () => {
  it('retries on transient errors with exponential backoff', async () => {
    let calls = 0;
    const fn = async () => {
      calls++;
      if (calls < 3) throw Object.assign(new Error('ECONNRESET'), { code: 'ECONNRESET' });
      return 'ok';
    };
    const out = await retry(fn, { attempts: 5, baseMs: 1, retryable: (e) => e.code === 'ECONNRESET' });
    expect(out).toBe('ok');
    expect(calls).toBe(3);
  });

  it('throws after max attempts', async () => {
    const fn = async () => { throw new Error('boom'); };
    await expect(retry(fn, { attempts: 3, baseMs: 1, retryable: () => true })).rejects.toThrow('boom');
  });

  it('does not retry non-retryable errors', async () => {
    let calls = 0;
    const fn = async () => {
      calls++;
      throw Object.assign(new Error('invalid'), { code: 'INVALID' });
    };
    await expect(
      retry(fn, { attempts: 5, baseMs: 1, retryable: (e) => e.code === 'ECONNRESET' })
    ).rejects.toThrow('invalid');
    expect(calls).toBe(1);
  });

  it('isGatewayRetryable: classifies common transient codes + 5xx', () => {
    expect(isGatewayRetryable({ code: 'ECONNRESET' })).toBe(true);
    expect(isGatewayRetryable({ code: 'ETIMEDOUT' })).toBe(true);
    expect(isGatewayRetryable({ status: 503 })).toBe(true);
    expect(isGatewayRetryable({ status: 400 })).toBe(false);
    expect(isGatewayRetryable({ code: 'INVALID_CARD' })).toBe(false);
  });
});
