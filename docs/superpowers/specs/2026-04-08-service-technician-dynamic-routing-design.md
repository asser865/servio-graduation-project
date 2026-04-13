# Design: Dynamic Service & Technician Routing
**Date:** 2026-04-08
**Status:** Approved

---

## Problem

Two broken flows in the customer-facing site:

1. **Services marketplace → Service detail page**: `services-marketplace.html` has 15 service cards. Only Plumbing links anywhere (`<a href="./service-details.html">`). The other 14 services use `<span>` with no href. `service-details.html` is 100% hardcoded for Plumbing — title, included items, pricing, FAQs, reviews are all static text.

2. **Technician listing → Technician profile**: All 6 "View Profile" links in `technician-listing.html` point to `./technician-profile.html` with no identifier. `technician-profile.html` is hardcoded to "Omar Tarek - Master Plumber." Every technician click lands on Omar Tarek.

Additionally, `technician-listing.html` is itself hardcoded to Plumbing — breadcrumb, title, lead text, and background image all say "Plumbing Services."

---

## Approach: Single Template + URL Query Params

No new HTML files. The three existing template pages (`service-details.html`, `technician-listing.html`, `technician-profile.html`) each read a URL query param on load and populate their content from a JS data object.

**This is backend-ready by design.** When the backend arrives, the JS data objects are replaced with API calls — the HTML and routing logic stay identical.

---

## URL Scheme

```
services-marketplace.html
  └── "View Technicians →"
      └── service-details.html?service=electrical
            └── "Find an Electrician →"
                └── technician-listing.html?service=electrical
                      └── "View Profile"
                          └── technician-profile.html?id=2&service=electrical
```

- `?service=` key matches the service keys defined in the data object (e.g. `plumbing`, `electrical`, `ac-maintenance`)
- `?id=` key matches technician IDs 1–5
- `&service=` on the profile URL is used for breadcrumb back-links only

**Fallback:** unrecognized or missing `?service=` → redirect to `services-marketplace.html`. Unrecognized or missing `?id=` → redirect to `technician-listing.html`.

---

## Service Keys (15 total)

| Key | Display Name (EN) | Display Name (AR) |
|---|---|---|
| `plumbing` | Plumbing | السباكة |
| `electrical` | Electrical | الكهرباء |
| `ac-maintenance` | A/C Maintenance & HVAC | صيانة التكييف |
| `carpentry` | Carpentry | النجارة |
| `appliance` | Appliance Services | صيانة الأجهزة |
| `handyman` | Handyman Tasks | أعمال الصيانة العامة |
| `renovation` | Home Finishing & Renovation | التشطيب والتجديد |
| `painting` | Painting | الدهانات |
| `flooring` | Flooring | الأرضيات |
| `drywall` | Drywall | الجبس والجدران الجافة |
| `roofing` | Roofing | أعمال الأسقف |
| `pest-control` | Pest Control | مكافحة الحشرات |
| `cleaning` | Professional Cleaning | التنظيف الاحترافي |
| `landscaping` | Landscaping | تنسيق الحدائق |
| `installation` | Installation Services | خدمات التركيب |

---

## Canonical Technicians (IDs 1–5)

These 5 technicians are the site-wide canonical dummy profiles. They appear in the admin dashboard, customer dashboard booking cards, disputes tab, and all other pages. No other names should be used.

```js
const TECHNICIANS = {
  1: {
    name: 'Khaled Mohamed',   nameAr: 'خالد محمد',
    specialty: 'plumbing',    rating: 4.9,
    price: 145,               reviews: 128,
    areas: ['Maadi', 'Heliopolis'],
    areasAr: ['المعادي', 'مصر الجديدة'],
  },
  2: {
    name: 'Mahmoud Ibrahim',  nameAr: 'محمود إبراهيم',
    specialty: 'electrical',  rating: 4.7,
    price: 160,               reviews: 95,
    areas: ['Nasr City', 'Heliopolis'],
    areasAr: ['مدينة نصر', 'مصر الجديدة'],
  },
  3: {
    name: 'Hassan Ali',       nameAr: 'حسن علي',
    specialty: 'ac-maintenance', rating: 4.8,
    price: 180,               reviews: 210,
    areas: ['Zamalek', 'Dokki'],
    areasAr: ['الزمالك', 'الدقي'],
  },
  4: {
    name: 'Youssef Samir',    nameAr: 'يوسف سمير',
    specialty: 'painting',    rating: 4.6,
    price: 120,               reviews: 74,
    areas: ['New Cairo', '6th Oct'],
    areasAr: ['القاهرة الجديدة', 'السادس من أكتوبر'],
  },
  5: {
    name: 'Amr Gamal',        nameAr: 'عمرو جمال',
    specialty: 'carpentry',   rating: 4.5,
    price: 130,               reviews: 58,
    areas: ['Maadi', 'Dokki'],
    areasAr: ['المعادي', 'الدقي'],
  },
}
```

---

## Service-to-Technician Mapping

```js
const SERVICE_TECHNICIANS = {
  plumbing:         [1],
  electrical:       [2],
  'ac-maintenance': [3],
  cleaning:         [3],
  painting:         [4],
  carpentry:        [5],
  handyman:         [1, 5],
  // renovation, flooring, drywall, roofing, pest-control, landscaping, installation → all 5
}
```

Services without an explicit mapping fall back to showing all 5 technicians.

---

## Service Data Object Structure

Each service entry in `SERVICES` (stored in `service-details.js`) contains:

```js
{
  en: {
    title:      'Plumbing Services',
    lead:       'Expert pipe repair, leak detection, and fixture installation.',
    priceBadge: 'avg. 200 – 2,000 EGP',
    findBtn:    'Find a Plumber →',
    ctaTitle:   'Ready to book a plumber?',
    ctaSub:     'Browse our network of verified plumbing specialists.',
    ctaBtn:     'Browse Available Plumbers →',
  },
  ar: {
    title:      'خدمات السباكة',
    lead:       'إصلاح الأنابيب واكتشاف التسربات وتركيب التجهيزات.',
    priceBadge: 'متوسط 200 – 2,000 جنيه',
    findBtn:    'ابحث عن سباك →',
    ctaTitle:   'هل أنت مستعد لحجز سباك؟',
    ctaSub:     'تصفح شبكتنا من متخصصي السباكة المعتمدين.',
    ctaBtn:     'تصفح السباكين المتاحين →',
  },
  heroImage: 'https://images.unsplash.com/...',
  included: [
    { titleEn: 'Pipe Repair', titleAr: 'إصلاح الأنابيب', descEn: '...', descAr: '...', icon: '<svg>...</svg>' },
    // 3–5 more items
  ],
  pricing: [
    { tierEn: 'Basic',    tierAr: 'أساسي',   priceEn: '200–500 EGP',    priceAr: '200–500 جنيه',    jobsEn: '...', jobsAr: '...' },
    { tierEn: 'Standard', tierAr: 'قياسي',   priceEn: '500–1,000 EGP',  priceAr: '500–1,000 جنيه',  jobsEn: '...', jobsAr: '...', featured: true },
    { tierEn: 'Complex',  tierAr: 'متقدم',   priceEn: '1,000–2,000 EGP',priceAr: '1,000–2,000 جنيه',jobsEn: '...', jobsAr: '...' },
  ],
  faqs: [
    { qEn: '...', qAr: '...', aEn: '...', aAr: '...' },
    // 2–3 more
  ],
  reviews: [
    { initials: 'AY', nameEn: 'Ahmed Yasser', nameAr: 'أحمد ياسر', stars: 5, quoteEn: '...', quoteAr: '...' },
    // 1–2 more
  ],
}
```

Minimal data per service — 4–5 included items, 3 pricing tiers, 3 FAQs, 2 reviews. All content will be deleted when backend replaces it.

---

## Files Changed

### HTML (3 files — structure change only, no content added)

**`html/services-marketplace.html`**
- 14 service cards: change `<span class="product-card__action">` → `<a class="product-card__action" href="./service-details.html?service=KEY">`
- The 1 existing Plumbing link already has `href` — update it to `./service-details.html?service=plumbing`

**`html/service-details.html`**
- Add `data-svc-*` target attributes to all dynamic elements (title, lead, price badge, hero image, included grid, pricing grid, FAQ list, reviews grid, CTA section, find button)
- Remove all hardcoded text from those elements — JS will fill them
- Keep all structural HTML (sections, CSS classes, icon slots) intact

**`html/technician-listing.html`**
- Add `data-listing-*` target attributes to breadcrumb current item, page title, lead text, hero image
- Add `data-tech-id="N"` to each of the 5 technician cards
- Update each "View Profile" link to `./technician-profile.html?id=N&service=SERVICE` — JS fills `SERVICE` from current URL param

**`html/technician-profile.html`**
- Add `data-profile-*` target attributes to all dynamic elements (name, title, rating, areas, price, bio, etc.)
- Add breadcrumb back-link target for service name
- Remove hardcoded Omar Tarek content from those elements

### JS (3 files — logic added)

**`js/html/service-details.js`**
- Read `?service=` from `URLSearchParams`
- Look up service in `SERVICES` object
- If not found → redirect to `services-marketplace.html`
- Detect current language from `document.documentElement.lang` (already set by `lang-init.js`)
- Populate all `data-svc-*` elements
- Wire "Find a Technician" button href to `technician-listing.html?service=KEY`
- Keep existing FAQ accordion logic

**`js/html/technician-listing.js`**
- Read `?service=` from `URLSearchParams`
- Update breadcrumb, title, lead, hero image from service data
- Look up `SERVICE_TECHNICIANS[service]` to get IDs to show; hide cards whose `data-tech-id` is not in the list
- Update each visible card's "View Profile" href to include `?id=N&service=KEY`
- Existing search/filter/sort logic applies only to visible cards

**`js/html/technician-profile.js`**
- Read `?id=` and `?service=` from `URLSearchParams`
- Look up technician in `TECHNICIANS` object
- If not found → redirect to `technician-listing.html`
- Populate all `data-profile-*` elements
- Update breadcrumb service back-link using `?service=` param
- Keep existing animation logic

### Translation (`js/lang.js`)

Add Arabic keys for:
- All 15 service names (for breadcrumbs and listing page titles)
- Generic listing page labels that reference the service name (e.g. `listing_breadcrumb_current`)
- Static labels already present stay unchanged

---

## What Is NOT Changed

- CSS — no new styles needed; existing `service-details.css`, `technicians.css`, `profile.css` stay as-is
- Page structure and layout — sections, grids, cards stay identical; only text nodes and `src`/`href` attributes change
- Existing filtering, sorting, search logic in `technician-listing.js`
- Animation and scroll-reveal logic
- All other pages in the site

---

## Translation Strategy

| Content type | How translated |
|---|---|
| Section headings ("What's Included", "How It Works") | Already in `lang.js` via `data-i18n` — no change |
| Service title, lead, price badge, CTA text | Stored bilingual in `SERVICES[key].en` / `.ar` — JS reads current lang |
| Technician name, area names | Stored bilingual in `TECHNICIANS[id].name` / `.nameAr` — JS reads current lang |
| FAQ questions & answers | Stored bilingual in service data object |
| Included items, pricing tiers | Stored bilingual in service data object |

Current language is detected from `document.documentElement.lang` which `lang-init.js` sets before page render.
