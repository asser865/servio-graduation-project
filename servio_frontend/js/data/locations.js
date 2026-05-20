// ─── Purpose ──────────────────────────────────────────────────────────────────
// Frontend mirror of the backend Egypt location taxonomy. Kept in lockstep with
// backend/src/utils/locationsTaxonomy.js so the technician coverage picker, the
// smart-match location selector, and the booking flow all resolve the same
// slugs the backend uses for hierarchical matching.
//
// If you add or rename a slug here, mirror the change in the backend file (and
// re-run `node scripts/backfill-coverage-slugs.js`).
// ─────────────────────────────────────────────────────────────────────────────

export const TAXONOMY = {
  egypt: { name: 'Egypt', parent: null, level: 'country', aliases: ['eg', 'misr', 'مصر'] },

  'cairo-gov': { name: 'Cairo', parent: 'egypt', level: 'governorate', aliases: ['cairo', 'cairo governorate', 'al qahira', 'qahira', 'القاهرة', 'محافظة القاهرة'] },
  'nasr-city':        { name: 'Nasr City',        parent: 'cairo-gov', level: 'district', aliases: ['nasr', 'مدينة نصر', 'madinet nasr'] },
  'maadi':            { name: 'Maadi',            parent: 'cairo-gov', level: 'district', aliases: ['el maadi', 'al maadi', 'المعادي'] },
  'heliopolis':       { name: 'Heliopolis',       parent: 'cairo-gov', level: 'district', aliases: ['masr el gedida', 'مصر الجديدة', 'هليوبوليس'] },
  'zamalek':          { name: 'Zamalek',          parent: 'cairo-gov', level: 'district', aliases: ['الزمالك'] },
  'new-cairo':        { name: 'New Cairo',        parent: 'cairo-gov', level: 'district', aliases: ['القاهرة الجديدة'] },
  'fifth-settlement': { name: 'Fifth Settlement', parent: 'new-cairo', level: 'district', aliases: ['tagamoa khames', 'tagamoa el khames', 'التجمع الخامس'] },
  'rehab':            { name: 'Rehab',            parent: 'new-cairo', level: 'district', aliases: ['al rehab', 'الرحاب'] },
  'madinaty':         { name: 'Madinaty',         parent: 'new-cairo', level: 'district', aliases: ['مدينتي'] },
  'shubra':           { name: 'Shubra',           parent: 'cairo-gov', level: 'district', aliases: ['shobra', 'شبرا'] },
  'ain-shams':        { name: 'Ain Shams',        parent: 'cairo-gov', level: 'district', aliases: ['عين شمس'] },
  'mokattam':         { name: 'Mokattam',         parent: 'cairo-gov', level: 'district', aliases: ['moqattam', 'المقطم'] },
  'garden-city':      { name: 'Garden City',      parent: 'cairo-gov', level: 'district', aliases: ['جاردن سيتي'] },
  'downtown-cairo':   { name: 'Downtown Cairo',   parent: 'cairo-gov', level: 'district', aliases: ['downtown', 'wust el balad', 'وسط البلد'] },
  'abbasiya':         { name: 'Abbasiya',         parent: 'cairo-gov', level: 'district', aliases: ['abbassia', 'العباسية'] },
  'sayeda-zeinab':    { name: 'Sayeda Zeinab',    parent: 'cairo-gov', level: 'district', aliases: ['السيدة زينب'] },
  'helwan':           { name: 'Helwan',           parent: 'cairo-gov', level: 'district', aliases: ['حلوان'] },
  'shorouk':          { name: 'Shorouk',          parent: 'cairo-gov', level: 'district', aliases: ['al shorouk', 'الشروق'] },
  'badr-city':        { name: 'Badr City',        parent: 'cairo-gov', level: 'district', aliases: ['badr', 'مدينة بدر'] },
  'obour':            { name: 'Obour',            parent: 'cairo-gov', level: 'district', aliases: ['al obour', 'العبور'] },

  'giza-gov':        { name: 'Giza', parent: 'egypt', level: 'governorate', aliases: ['giza', 'giza governorate', 'الجيزة', 'محافظة الجيزة'] },
  'giza-city':       { name: 'Giza City',      parent: 'giza-gov', level: 'district', aliases: ['مدينة الجيزة'] },
  'dokki':           { name: 'Dokki',          parent: 'giza-gov', level: 'district', aliases: ['الدقي'] },
  'mohandessin':     { name: 'Mohandessin',    parent: 'giza-gov', level: 'district', aliases: ['المهندسين'] },
  'agouza':          { name: 'Agouza',         parent: 'giza-gov', level: 'district', aliases: ['el agouza', 'العجوزة'] },
  'haram':           { name: 'Haram',          parent: 'giza-gov', level: 'district', aliases: ['al haram', 'الهرم'] },
  'faisal':          { name: 'Faisal',         parent: 'giza-gov', level: 'district', aliases: ['فيصل'] },
  '6th-of-october':  { name: '6th of October', parent: 'giza-gov', level: 'district', aliases: ['6 october', '6 أكتوبر', 'مدينة السادس من أكتوبر'] },
  'sheikh-zayed':    { name: 'Sheikh Zayed',   parent: 'giza-gov', level: 'district', aliases: ['الشيخ زايد'] },
  'imbaba':          { name: 'Imbaba',         parent: 'giza-gov', level: 'district', aliases: ['embaba', 'إمبابة'] },
  'boulaq-dakrour':  { name: 'Boulaq Dakrour', parent: 'giza-gov', level: 'district', aliases: ['bolak dakrour', 'بولاق الدكرور'] },

  'alexandria-gov':     { name: 'Alexandria',     parent: 'egypt', level: 'governorate', aliases: ['alex', 'alexandria', 'الإسكندرية'] },
  'qalyubia-gov':       { name: 'Qalyubia',       parent: 'egypt', level: 'governorate', aliases: ['qalyub', 'القليوبية'] },
  'sharqia-gov':        { name: 'Sharqia',        parent: 'egypt', level: 'governorate', aliases: ['الشرقية'] },
  'gharbia-gov':        { name: 'Gharbia',        parent: 'egypt', level: 'governorate', aliases: ['الغربية'] },
  'monufia-gov':        { name: 'Monufia',        parent: 'egypt', level: 'governorate', aliases: ['menoufia', 'المنوفية'] },
  'beheira-gov':        { name: 'Beheira',        parent: 'egypt', level: 'governorate', aliases: ['البحيرة'] },
  'damietta-gov':       { name: 'Damietta',       parent: 'egypt', level: 'governorate', aliases: ['دمياط'] },
  'port-said-gov':      { name: 'Port Said',      parent: 'egypt', level: 'governorate', aliases: ['بورسعيد'] },
  'ismailia-gov':       { name: 'Ismailia',       parent: 'egypt', level: 'governorate', aliases: ['الإسماعيلية'] },
  'suez-gov':           { name: 'Suez',           parent: 'egypt', level: 'governorate', aliases: ['السويس'] },
  'fayoum-gov':         { name: 'Fayoum',         parent: 'egypt', level: 'governorate', aliases: ['الفيوم'] },
  'beni-suef-gov':      { name: 'Beni Suef',      parent: 'egypt', level: 'governorate', aliases: ['بني سويف'] },
  'minya-gov':          { name: 'Minya',          parent: 'egypt', level: 'governorate', aliases: ['المنيا'] },
  'asyut-gov':          { name: 'Asyut',          parent: 'egypt', level: 'governorate', aliases: ['أسيوط'] },
  'sohag-gov':          { name: 'Sohag',          parent: 'egypt', level: 'governorate', aliases: ['سوهاج'] },
  'qena-gov':           { name: 'Qena',           parent: 'egypt', level: 'governorate', aliases: ['قنا'] },
  'luxor-gov':          { name: 'Luxor',          parent: 'egypt', level: 'governorate', aliases: ['الأقصر'] },
  'aswan-gov':          { name: 'Aswan',          parent: 'egypt', level: 'governorate', aliases: ['أسوان'] },
  'red-sea-gov':        { name: 'Red Sea',        parent: 'egypt', level: 'governorate', aliases: ['hurghada', 'البحر الأحمر', 'الغردقة'] },
  'new-valley-gov':     { name: 'New Valley',     parent: 'egypt', level: 'governorate', aliases: ['الوادي الجديد'] },
  'matrouh-gov':        { name: 'Matrouh',        parent: 'egypt', level: 'governorate', aliases: ['marsa matrouh', 'مطروح'] },
  'north-sinai-gov':    { name: 'North Sinai',    parent: 'egypt', level: 'governorate', aliases: ['شمال سيناء'] },
  'south-sinai-gov':    { name: 'South Sinai',    parent: 'egypt', level: 'governorate', aliases: ['sharm el sheikh', 'جنوب سيناء', 'شرم الشيخ'] },
  'kafr-el-sheikh-gov': { name: 'Kafr El Sheikh', parent: 'egypt', level: 'governorate', aliases: ['كفر الشيخ'] },
  'dakahlia-gov':       { name: 'Dakahlia',       parent: 'egypt', level: 'governorate', aliases: ['mansoura', 'الدقهلية', 'المنصورة'] },
};

const CHILDREN     = Object.create(null);
const ALIAS_TO_SLUG = Object.create(null);

export function normalizeKey(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[\u064B-\u065F\u0670]/g, '')
    .replace(/[^a-z0-9\u0600-\u06ff]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function indexAlias(key, slug) {
  const norm = normalizeKey(key);
  if (norm && !ALIAS_TO_SLUG[norm]) ALIAS_TO_SLUG[norm] = slug;
}

Object.entries(TAXONOMY).forEach(([slug, node]) => {
  if (node.parent) (CHILDREN[node.parent] = CHILDREN[node.parent] || []).push(slug);
  indexAlias(slug, slug);
  indexAlias(node.name, slug);
  (node.aliases || []).forEach((a) => indexAlias(a, slug));
});

export function resolveSlug(input) {
  if (!input) return '';
  const norm = normalizeKey(input);
  if (!norm) return '';
  if (ALIAS_TO_SLUG[norm]) return ALIAS_TO_SLUG[norm];

  const tokens = String(input).split(/[,/\n]+/).map(normalizeKey).filter(Boolean);
  for (const tok of tokens) if (ALIAS_TO_SLUG[tok]) return ALIAS_TO_SLUG[tok];

  const aliasesByLen = Object.keys(ALIAS_TO_SLUG).sort((a, b) => b.length - a.length);
  for (const alias of aliasesByLen) {
    if (alias.length < 3) continue;
    const re = new RegExp(`(^|\\s)${alias.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\s|$)`);
    if (re.test(norm)) return ALIAS_TO_SLUG[alias];
  }
  return '';
}

export function getNode(slug) {
  return TAXONOMY[slug] || null;
}

export function getAncestors(slug) {
  const out = [];
  let node = TAXONOMY[slug];
  while (node && node.parent) {
    out.push(node.parent);
    node = TAXONOMY[node.parent];
  }
  return out;
}

export function getDescendants(slug) {
  const out = [];
  const stack = [...(CHILDREN[slug] || [])];
  while (stack.length) {
    const cur = stack.pop();
    out.push(cur);
    if (CHILDREN[cur]) stack.push(...CHILDREN[cur]);
  }
  return out;
}

// Governorate-grouped hierarchy for picker UI.
export function getHierarchy() {
  return Object.entries(TAXONOMY)
    .filter(([, n]) => n.level === 'governorate')
    .map(([slug, n]) => ({
      slug,
      name:      n.name,
      districts: getDescendants(slug).map((d) => ({ slug: d, name: TAXONOMY[d].name })),
    }));
}

// Display label for a slug (name + parent gov if district) — e.g. "Maadi, Cairo".
export function labelForSlug(slug) {
  const node = TAXONOMY[slug];
  if (!node) return '';
  if (node.level === 'district') {
    const gov = TAXONOMY[node.parent];
    return gov ? `${node.name}, ${gov.name}` : node.name;
  }
  return node.name;
}
