// ─── Purpose ──────────────────────────────────────────────────────────────────
// Canonical Egypt location taxonomy. Powers hierarchical coverage matching
// between technicians (selected coverage areas) and service requests
// (user-supplied location). Without this, "Cairo" and "Nasr City" are unrelated
// strings; with it, "Nasr City" resolves to a district under Cairo Governorate,
// so a technician whose coverage is "Cairo" matches a request in "Nasr City".
//
// Match rule (see `expandCoverage`): a technician's coverage slug covers a
// request slug iff the request slug is the coverage itself, an ancestor of it,
// or a descendant of it. Storing the full expansion on the user document means
// queries are an O(1) array-contains lookup against an indexed field.
// ─────────────────────────────────────────────────────────────────────────────

const TAXONOMY = {
  egypt: { name: 'Egypt', parent: null, level: 'country', aliases: ['eg', 'misr', 'مصر'] },

  // ── Cairo Governorate ──────────────────────────────────────────────────────
  'cairo-gov': {
    name:    'Cairo',
    parent:  'egypt',
    level:   'governorate',
    aliases: ['cairo', 'cairo governorate', 'al qahira', 'al qāhirah', 'qahira', 'القاهرة', 'محافظة القاهرة'],
  },
  'nasr-city':       { name: 'Nasr City',       parent: 'cairo-gov', level: 'district', aliases: ['nasr', 'nasr-city', 'مدينة نصر', 'madinet nasr'] },
  'maadi':           { name: 'Maadi',           parent: 'cairo-gov', level: 'district', aliases: ['el maadi', 'al maadi', 'المعادي'] },
  'heliopolis':      { name: 'Heliopolis',      parent: 'cairo-gov', level: 'district', aliases: ['masr el gedida', 'misr al jadidah', 'مصر الجديدة', 'هليوبوليس'] },
  'zamalek':         { name: 'Zamalek',         parent: 'cairo-gov', level: 'district', aliases: ['الزمالك'] },
  'new-cairo':       { name: 'New Cairo',       parent: 'cairo-gov', level: 'district', aliases: ['new-cairo', 'al qahira al jadida', 'القاهرة الجديدة'] },
  'fifth-settlement':{ name: 'Fifth Settlement',parent: 'new-cairo', level: 'district', aliases: ['tagamoa khames', 'tagamoa el khames', 'tagamoa', 'التجمع الخامس'] },
  'rehab':           { name: 'Rehab',           parent: 'new-cairo', level: 'district', aliases: ['al rehab', 'el rehab', 'الرحاب'] },
  'madinaty':        { name: 'Madinaty',        parent: 'new-cairo', level: 'district', aliases: ['مدينتي'] },
  'shubra':          { name: 'Shubra',          parent: 'cairo-gov', level: 'district', aliases: ['shobra', 'شبرا'] },
  'ain-shams':       { name: 'Ain Shams',       parent: 'cairo-gov', level: 'district', aliases: ['عين شمس'] },
  'mokattam':        { name: 'Mokattam',        parent: 'cairo-gov', level: 'district', aliases: ['moqattam', 'المقطم'] },
  'garden-city':     { name: 'Garden City',     parent: 'cairo-gov', level: 'district', aliases: ['جاردن سيتي'] },
  'downtown-cairo':  { name: 'Downtown Cairo',  parent: 'cairo-gov', level: 'district', aliases: ['downtown', 'wust el balad', 'وسط البلد'] },
  'abbasiya':        { name: 'Abbasiya',        parent: 'cairo-gov', level: 'district', aliases: ['abbassia', 'al abbasiyya', 'العباسية'] },
  'sayeda-zeinab':   { name: 'Sayeda Zeinab',   parent: 'cairo-gov', level: 'district', aliases: ['el sayeda zeinab', 'السيدة زينب'] },
  'helwan':          { name: 'Helwan',          parent: 'cairo-gov', level: 'district', aliases: ['حلوان'] },
  'shorouk':         { name: 'Shorouk',         parent: 'cairo-gov', level: 'district', aliases: ['al shorouk', 'el shorouk', 'الشروق'] },
  'badr-city':       { name: 'Badr City',       parent: 'cairo-gov', level: 'district', aliases: ['badr', 'مدينة بدر'] },
  'obour':           { name: 'Obour',           parent: 'cairo-gov', level: 'district', aliases: ['al obour', 'el obour', 'العبور'] },

  // ── Giza Governorate ───────────────────────────────────────────────────────
  'giza-gov': {
    name:    'Giza',
    parent:  'egypt',
    level:   'governorate',
    aliases: ['giza', 'giza governorate', 'الجيزة', 'محافظة الجيزة'],
  },
  'giza-city':       { name: 'Giza City',       parent: 'giza-gov', level: 'district', aliases: ['mohafzet el giza', 'مدينة الجيزة'] },
  'dokki':           { name: 'Dokki',           parent: 'giza-gov', level: 'district', aliases: ['ad duqqi', 'الدقي'] },
  'mohandessin':     { name: 'Mohandessin',     parent: 'giza-gov', level: 'district', aliases: ['al muhandisin', 'المهندسين'] },
  'agouza':          { name: 'Agouza',          parent: 'giza-gov', level: 'district', aliases: ['el agouza', 'العجوزة'] },
  'haram':           { name: 'Haram',           parent: 'giza-gov', level: 'district', aliases: ['al haram', 'الهرم'] },
  'faisal':          { name: 'Faisal',          parent: 'giza-gov', level: 'district', aliases: ['فيصل'] },
  '6th-of-october':  { name: '6th of October',  parent: 'giza-gov', level: 'district', aliases: ['6 october', 'sixth of october', '6 أكتوبر', 'مدينة السادس من أكتوبر'] },
  'sheikh-zayed':    { name: 'Sheikh Zayed',    parent: 'giza-gov', level: 'district', aliases: ['al sheikh zayed', 'الشيخ زايد'] },
  'imbaba':          { name: 'Imbaba',          parent: 'giza-gov', level: 'district', aliases: ['embaba', 'إمبابة'] },
  'boulaq-dakrour':  { name: 'Boulaq Dakrour',  parent: 'giza-gov', level: 'district', aliases: ['bolak dakrour', 'بولاق الدكرور'] },

  // ── Other governorates (lightweight) ───────────────────────────────────────
  'alexandria-gov':  { name: 'Alexandria',  parent: 'egypt', level: 'governorate', aliases: ['alex', 'alexandria', 'iskandariyya', 'الإسكندرية'] },
  'qalyubia-gov':    { name: 'Qalyubia',    parent: 'egypt', level: 'governorate', aliases: ['qalyub', 'qalyoubia', 'al qalyubiyya', 'القليوبية'] },
  'sharqia-gov':     { name: 'Sharqia',     parent: 'egypt', level: 'governorate', aliases: ['al sharqiyya', 'الشرقية'] },
  'gharbia-gov':     { name: 'Gharbia',     parent: 'egypt', level: 'governorate', aliases: ['al gharbiyya', 'الغربية'] },
  'monufia-gov':     { name: 'Monufia',     parent: 'egypt', level: 'governorate', aliases: ['menoufia', 'al minufiyya', 'المنوفية'] },
  'beheira-gov':     { name: 'Beheira',     parent: 'egypt', level: 'governorate', aliases: ['al buhayrah', 'البحيرة'] },
  'damietta-gov':    { name: 'Damietta',    parent: 'egypt', level: 'governorate', aliases: ['dumyat', 'دمياط'] },
  'port-said-gov':   { name: 'Port Said',   parent: 'egypt', level: 'governorate', aliases: ['bur sa\'id', 'بورسعيد'] },
  'ismailia-gov':    { name: 'Ismailia',    parent: 'egypt', level: 'governorate', aliases: ['al isma\'iliyya', 'الإسماعيلية'] },
  'suez-gov':        { name: 'Suez',        parent: 'egypt', level: 'governorate', aliases: ['as suways', 'السويس'] },
  'fayoum-gov':      { name: 'Fayoum',      parent: 'egypt', level: 'governorate', aliases: ['al fayyum', 'الفيوم'] },
  'beni-suef-gov':   { name: 'Beni Suef',   parent: 'egypt', level: 'governorate', aliases: ['bani suwayf', 'بني سويف'] },
  'minya-gov':       { name: 'Minya',       parent: 'egypt', level: 'governorate', aliases: ['al minya', 'المنيا'] },
  'asyut-gov':       { name: 'Asyut',       parent: 'egypt', level: 'governorate', aliases: ['assiut', 'أسيوط'] },
  'sohag-gov':       { name: 'Sohag',       parent: 'egypt', level: 'governorate', aliases: ['suhaj', 'سوهاج'] },
  'qena-gov':        { name: 'Qena',        parent: 'egypt', level: 'governorate', aliases: ['قنا'] },
  'luxor-gov':       { name: 'Luxor',       parent: 'egypt', level: 'governorate', aliases: ['al uqsur', 'الأقصر'] },
  'aswan-gov':       { name: 'Aswan',       parent: 'egypt', level: 'governorate', aliases: ['أسوان'] },
  'red-sea-gov':     { name: 'Red Sea',     parent: 'egypt', level: 'governorate', aliases: ['al bahr al ahmar', 'البحر الأحمر', 'hurghada', 'الغردقة'] },
  'new-valley-gov':  { name: 'New Valley',  parent: 'egypt', level: 'governorate', aliases: ['al wadi al jadid', 'الوادي الجديد'] },
  'matrouh-gov':     { name: 'Matrouh',     parent: 'egypt', level: 'governorate', aliases: ['marsa matrouh', 'مطروح'] },
  'north-sinai-gov': { name: 'North Sinai', parent: 'egypt', level: 'governorate', aliases: ['shamal sina', 'شمال سيناء'] },
  'south-sinai-gov': { name: 'South Sinai', parent: 'egypt', level: 'governorate', aliases: ['janub sina', 'sharm el sheikh', 'جنوب سيناء', 'شرم الشيخ'] },
  'kafr-el-sheikh-gov': { name: 'Kafr El Sheikh', parent: 'egypt', level: 'governorate', aliases: ['kafr al shaykh', 'كفر الشيخ'] },
  'dakahlia-gov':    { name: 'Dakahlia',    parent: 'egypt', level: 'governorate', aliases: ['al daqahliyya', 'mansoura', 'الدقهلية', 'المنصورة'] },
};

// ── Build reverse indexes ─────────────────────────────────────────────────────
const CHILDREN = Object.create(null);   // parentSlug -> [childSlug]
const ALIAS_TO_SLUG = Object.create(null); // normalized name/alias -> slug

function normalizeKey(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '') // strip combining diacritics
    .replace(/[\u064B-\u065F\u0670]/g, '') // strip Arabic tashkeel
    // Fold common Arabic letter variants so user typos don't break matching.
    .replace(/[\u0622\u0623\u0625]/g, '\u0627') // أ إ آ → ا
    .replace(/\u0649/g, '\u064A')               // ى → ي
    .replace(/\u0629/g, '\u0647')               // ة → ه (ta-marbuta → ha)
    .replace(/\u0624/g, '\u0648')               // ؤ → و
    .replace(/\u0626/g, '\u064A')               // ئ → ي
    .replace(/[\u200B-\u200D\uFEFF]/g, '')      // strip zero-width chars
    .replace(/[^a-z0-9\u0600-\u06ff]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function indexAlias(key, slug) {
  const norm = normalizeKey(key);
  if (!norm) return;
  // First registration wins so canonical names beat aliases on collision.
  if (!ALIAS_TO_SLUG[norm]) ALIAS_TO_SLUG[norm] = slug;
}

Object.entries(TAXONOMY).forEach(([slug, node]) => {
  if (node.parent) {
    (CHILDREN[node.parent] = CHILDREN[node.parent] || []).push(slug);
  }
  indexAlias(slug, slug);
  indexAlias(node.name, slug);
  (node.aliases || []).forEach((a) => indexAlias(a, slug));
});

// ── Public API ────────────────────────────────────────────────────────────────

// Resolve a free-text label or slug to a canonical slug. Returns '' on no match.
// Strategy:
//   1. Exact normalized lookup against the alias index.
//   2. If input is a comma/slash compound ("Nasr City, Cairo"), try each token
//      from MOST specific to LEAST specific — the first hit wins.
//   3. Last resort: any indexed name that appears as a whole word inside the
//      remaining text.
function resolveSlug(input) {
  if (!input) return '';
  const norm = normalizeKey(input);
  if (!norm) return '';

  if (ALIAS_TO_SLUG[norm]) return ALIAS_TO_SLUG[norm];

  const tokens = String(input)
    .split(/[,/\n]+/)
    .map((s) => normalizeKey(s))
    .filter(Boolean);

  for (const tok of tokens) {
    if (ALIAS_TO_SLUG[tok]) return ALIAS_TO_SLUG[tok];
  }

  // Substring scan — ordered by alias length DESC so "nasr city" wins over "city".
  const aliasesByLen = Object.keys(ALIAS_TO_SLUG).sort((a, b) => b.length - a.length);
  for (const alias of aliasesByLen) {
    if (alias.length < 3) continue;
    const re = new RegExp(`(^|\\s)${alias.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\s|$)`);
    if (re.test(norm)) return ALIAS_TO_SLUG[alias];
  }
  return '';
}

function getNode(slug) {
  return TAXONOMY[slug] || null;
}

function getAncestors(slug) {
  const result = [];
  let node = TAXONOMY[slug];
  while (node && node.parent) {
    result.push(node.parent);
    node = TAXONOMY[node.parent];
  }
  return result;
}

function getDescendants(slug) {
  const out = [];
  const stack = [...(CHILDREN[slug] || [])];
  while (stack.length) {
    const cur = stack.pop();
    out.push(cur);
    if (CHILDREN[cur]) stack.push(...CHILDREN[cur]);
  }
  return out;
}

// Expand a set of coverage inputs (free text or slugs) into the canonical match
// set used at query time: union of (slug ∪ ancestors ∪ descendants) per entry.
// Free-text inputs that don't resolve are silently dropped — callers should
// keep the original strings around for legacy regex fallback if needed.
function expandCoverage(inputs) {
  const matchSet = new Set();
  const slugs = new Set();
  (Array.isArray(inputs) ? inputs : []).forEach((raw) => {
    const slug = resolveSlug(raw);
    if (!slug) return;
    slugs.add(slug);
    matchSet.add(slug);
    getAncestors(slug).forEach((a) => matchSet.add(a));
    getDescendants(slug).forEach((d) => matchSet.add(d));
  });
  return { slugs: [...slugs], matchSlugs: [...matchSet] };
}

// Build a UI-ready hierarchy: governorate → districts.
function getHierarchy() {
  const govs = Object.entries(TAXONOMY)
    .filter(([, n]) => n.level === 'governorate')
    .map(([slug, n]) => ({
      slug,
      name:      n.name,
      districts: getDescendants(slug).map((d) => ({ slug: d, name: TAXONOMY[d].name })),
    }));
  return govs;
}

module.exports = {
  TAXONOMY,
  resolveSlug,
  expandCoverage,
  getAncestors,
  getDescendants,
  getNode,
  getHierarchy,
  normalizeKey,
};
