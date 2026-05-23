function paginated(res, { items, page, limit, total }) {
  return res.json({
    data: items,
    meta: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.max(1, Math.ceil(total / limit)),
    },
  });
}

function single(res, data) {
  return res.json({ data });
}

module.exports = { paginated, single };
