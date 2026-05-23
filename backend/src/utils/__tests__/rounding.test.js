const { round, money } = require('../rounding');

describe("rounding (banker's)", () => {
  it('2.5 -> 2 (round half to even)', () => { expect(round(2.5)).toBe(2); });
  it('3.5 -> 4', () => { expect(round(3.5)).toBe(4); });
  it('4.5 -> 4', () => { expect(round(4.5)).toBe(4); });
  it('5.5 -> 6', () => { expect(round(5.5)).toBe(6); });
  it('2.45 to 1 decimal -> 2.4', () => { expect(round(2.45, 1)).toBe(2.4); });
  it('money formats to 2 decimals with rounding', () => {
    expect(money(1.005)).toBe(1.00);
    expect(money(1.015)).toBe(1.02);
  });
  it('handles negatives via floor (banker on positive half)', () => {
    expect(round(-1.5)).toBe(-2);
  });
  it('returns 0 for NaN/undefined/null', () => {
    expect(money(undefined)).toBe(0);
    expect(money(null)).toBe(0);
    expect(money(NaN)).toBe(0);
  });
});
