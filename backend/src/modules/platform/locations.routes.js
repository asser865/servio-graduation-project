// ─── Purpose ──────────────────────────────────────────────────────────────────
// Public endpoints that expose the location taxonomy to the frontend so the
// technician coverage picker, smart-match location selector, and booking flow
// all share the same canonical hierarchy and resolver as the backend.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }          = require('express');
const { StatusCodes }     = require('http-status-codes');
const ApiResponse         = require('../../utils/ApiResponse');
const {
  getHierarchy,
  resolveSlug,
  getAncestors,
  getDescendants,
  getNode,
} = require('../../utils/locationsTaxonomy');

const router = Router();

router.get('/', (req, res) => {
  return ApiResponse.success(res, StatusCodes.OK, 'Locations retrieved.', {
    hierarchy: getHierarchy(),
  });
});

router.get('/resolve', (req, res) => {
  const input = String(req.query.q || '').trim();
  const slug  = resolveSlug(input);
  const node  = slug ? getNode(slug) : null;
  return ApiResponse.success(res, StatusCodes.OK, 'Location resolved.', {
    input,
    slug,
    name:      node?.name || '',
    level:     node?.level || '',
    ancestors: slug ? getAncestors(slug) : [],
    descendants: slug ? getDescendants(slug) : [],
  });
});

module.exports = router;
