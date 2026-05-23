const { permission, hasPermission } = require('../permission.middleware');

function runMw(mw, user) {
  return new Promise((resolve) => {
    mw({ user }, {}, (err) => resolve(err));
  });
}

describe('permission middleware', () => {
  const PERM = 'payments:release';

  it('allows superadmin regardless of adminPermissions', async () => {
    const err = await runMw(permission(PERM), { role: 'superadmin', adminPermissions: [] });
    expect(err).toBeUndefined();
  });

  it('allows admin with empty adminPermissions (legacy)', async () => {
    const err = await runMw(permission(PERM), { role: 'admin' });
    expect(err).toBeUndefined();
  });

  it('allows admin with matching permission', async () => {
    const err = await runMw(permission(PERM), { role: 'admin', adminPermissions: [PERM] });
    expect(err).toBeUndefined();
  });

  it('rejects admin without matching permission', async () => {
    const err = await runMw(permission(PERM), { role: 'admin', adminPermissions: ['payouts:approve'] });
    expect(err).toBeDefined();
    expect(err.statusCode || err.status).toBe(403);
    expect(err.message).toMatch(/payments:release/);
  });

  it('rejects non-admin user role', async () => {
    const err = await runMw(permission(PERM), { role: 'user' });
    expect(err).toBeDefined();
    expect(err.statusCode || err.status).toBe(403);
  });

  it('rejects unauthenticated request', async () => {
    const err = await runMw(permission(PERM), undefined);
    expect(err).toBeDefined();
    expect(err.statusCode || err.status).toBe(401);
  });

  it('hasPermission helper matches middleware behavior', () => {
    expect(hasPermission({ role: 'superadmin' }, PERM)).toBe(true);
    expect(hasPermission({ role: 'admin' }, PERM)).toBe(true);
    expect(hasPermission({ role: 'admin', adminPermissions: [PERM] }, PERM)).toBe(true);
    expect(hasPermission({ role: 'admin', adminPermissions: ['x'] }, PERM)).toBe(false);
    expect(hasPermission(null, PERM)).toBe(false);
  });
});
