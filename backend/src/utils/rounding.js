function round(value, decimals = 0) {
  if (value === null || value === undefined || Number.isNaN(value)) return 0;
  const m = Math.pow(10, decimals);
  const x = value * m;
  const floor = Math.floor(x);
  const diff = +(x - floor).toFixed(10);
  if (diff < 0.5) return floor / m;
  if (diff > 0.5) return (floor + 1) / m;
  return (floor % 2 === 0 ? floor : floor + 1) / m;
}

const money = (v) => round(v, 2);

module.exports = { round, money };
