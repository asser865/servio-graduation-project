/**
 * services-data.js
 * Bilingual service definitions + service-to-technician mapping.
 * All content here is temporary dummy data — will be replaced by backend/DB.
 */

const I = {
  wrench: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>',
  drop:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>',
  bolt:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
  pulse:  '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
  temp:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z"/></svg>',
  gear:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14M4.93 4.93a10 10 0 0 0 0 14.14"/></svg>',
  shield: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
  home:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
  paint:  '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m15 12-8.37 8.37c-1.17 1.17-3.08 1.17-4.24 0-1.18-1.17-1.18-3.08 0-4.24L10.76 7.76"/><path d="M17.63 7H21l-3-3V1l-4.63 4.63a4.24 4.24 0 0 0-1.24 3A4.24 4.24 0 0 0 13.37 10Z"/></svg>',
  leaf:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/></svg>',
  tv:     '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"/><polyline points="17 2 12 7 7 2"/></svg>',
  bug:    '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="6" width="8" height="14" rx="4"/><path d="m19 7-3 2"/><path d="m5 7 3 2"/><path d="m19 19-3-2"/><path d="m5 19 3-2"/><path d="M20 13h-4"/><path d="M4 13h4"/></svg>',
};

/* ─── Generic FAQ entries shared across most services ─────────────── */
const FAQ_VERIFIED = {
  en: { q: 'Are technicians verified?', a: 'All SERVIO technicians pass ID verification, trade certification checks, and a background screening before joining.' },
  ar: { q: 'هل الفنيون معتمدون؟', a: 'جميع فنيو SERVIO يجتازون التحقق من الهوية وشهادة المهنة والفحص الأمني قبل الانضمام.' },
};
const FAQ_PAYMENT = {
  en: { q: 'Can I pay in cash?', a: 'Yes — cash payment is supported. For full payment protection, online payment is also available.' },
  ar: { q: 'هل يمكنني الدفع نقداً؟', a: 'نعم — الدفع النقدي مدعوم. الدفع الإلكتروني متاح أيضاً لحماية كاملة.' },
};
const FAQ_GUARANTEE = {
  en: { q: 'What if I\'m not satisfied?', a: 'Payment is only finalized once you confirm the job is complete. Raise a dispute within 48 hours and our team resolves it.' },
  ar: { q: 'ماذا لو لم أكن راضياً؟', a: 'يتم تأكيد الدفع فقط بعد تأكيدك اكتمال العمل. قدّم نزاعاً خلال 48 ساعة وسيحل فريقنا المشكلة.' },
};

/* ─── Shared review names ──────────────────────────────────────────── */
const REV_AY = { initials: 'AY', stars: 5, en: { name: 'Ahmed Yasser' }, ar: { name: 'أحمد ياسر' } };
const REV_SM = { initials: 'SM', stars: 4, en: { name: 'Sara Mohamed' }, ar: { name: 'سارة محمد' } };

/* ─── Service definitions ──────────────────────────────────────────── */
export const SERVICES = {

  plumbing: {
    en: { title: 'Plumbing Services', lead: 'Expert pipe repair, leak detection, and fixture installation by verified professionals.', priceBadge: 'avg. 200 – 2,000 EGP', findBtn: 'Find a Plumber →', ctaTitle: 'Ready to book a plumber?', ctaSub: 'Browse our network of verified plumbing specialists.', ctaBtn: 'Browse Available Plumbers →' },
    ar: { title: 'خدمات السباكة', lead: 'إصلاح الأنابيب والكشف عن التسربات وتركيب الأجهزة من قبل متخصصين معتمدين.', priceBadge: 'متوسط 200 – 2,000 جنيه', findBtn: 'ابحث عن سباك →', ctaTitle: 'جاهز لحجز سباك؟', ctaSub: 'تصفح شبكتنا من متخصصي السباكة المعتمدين.', ctaBtn: 'تصفح السباكين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.wrench, en: { title: 'Pipe Repair', desc: 'Fix leaks, bursts, and corrosion in supply and drain lines.' }, ar: { title: 'إصلاح الأنابيب', desc: 'إصلاح التسربات والانفجارات والتآكل في خطوط التوريد.' } },
      { icon: I.drop,   en: { title: 'Leak Detection', desc: 'Non-invasive diagnosis of hidden leaks behind walls and under floors.' }, ar: { title: 'كشف التسربات', desc: 'تشخيص غير تدخلي للتسربات المخفية خلف الجدران.' } },
      { icon: I.gear,   en: { title: 'Fixture Installation', desc: 'Professional fitting of taps, showers, toilets, and sinks.' }, ar: { title: 'تركيب التجهيزات', desc: 'تركيب احترافي للحنفيات والأحواض والمراحيض.' } },
      { icon: I.pulse,  en: { title: 'Drain Cleaning', desc: 'Clear blockages and restore full flow with professional-grade equipment.' }, ar: { title: 'تنظيف المصارف', desc: 'إزالة الانسدادات واستعادة التدفق الكامل.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '200 – 500 EGP', jobs: 'Washer replacements, minor leaks, and simple drain unblocking.' }, ar: { tier: 'أساسي', price: '200 – 500 جنيه', jobs: 'استبدال الحلقات المطاطية والتسربات البسيطة.' } },
      { featured: true, en: { tier: 'Standard', price: '500 – 1,000 EGP', jobs: 'Pipe replacements, full fixture installations, and drain clearing.' }, ar: { tier: 'معياري', price: '500 – 1,000 جنيه', jobs: 'استبدال الأنابيب وتركيب التجهيزات الكاملة.' } },
      { en: { tier: 'Complex', price: '1,000 – 2,000 EGP', jobs: 'Major re-piping, water heater replacement, and emergency callouts.' }, ar: { tier: 'متقدم', price: '1,000 – 2,000 جنيه', jobs: 'إعادة التمديد الكاملة واستبدال سخانات المياه.' } },
    ],
    faqs: [
      { en: { q: 'How long does a plumbing job take?', a: 'Most standard jobs take 1–3 hours. Complex work like re-piping may take a full day.' }, ar: { q: 'كم يستغرق عمل السباكة؟', a: 'معظم الأعمال تستغرق 1–3 ساعات. الأعمال المعقدة قد تستغرق يوماً كاملاً.' } },
      FAQ_VERIFIED, FAQ_GUARANTEE,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Fixed a burst pipe within 2 hours of booking. Professional, clean, and honest about pricing."' }, ar: { ...REV_AY.ar, quote: '"إصلاح أنبوب متفجر خلال ساعتين. محترف ونظيف وصادق في التسعير."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Great service. The technician was knowledgeable and resolved our leak quickly."' }, ar: { ...REV_SM.ar, quote: '"خدمة رائعة. الفني كان على دراية وحل تسربنا بسرعة."' } },
    ],
  },

  electrical: {
    en: { title: 'Electrical Services', lead: 'Safe, licensed wiring, lighting installation, and precision electrical repairs by certified electricians.', priceBadge: 'avg. 300 – 3,000 EGP', findBtn: 'Find an Electrician →', ctaTitle: 'Ready to book an electrician?', ctaSub: 'Browse our network of licensed electrical specialists.', ctaBtn: 'Browse Available Electricians →' },
    ar: { title: 'خدمات الكهرباء', lead: 'توصيلات كهربائية آمنة ومرخصة وتركيب الإضاءة وإصلاحات دقيقة من كهربائيين معتمدين.', priceBadge: 'متوسط 300 – 3,000 جنيه', findBtn: 'ابحث عن كهربائي →', ctaTitle: 'جاهز لحجز كهربائي؟', ctaSub: 'تصفح شبكتنا من الكهربائيين المرخصين.', ctaBtn: 'تصفح الكهربائيين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.bolt,   en: { title: 'Wiring & Rewiring', desc: 'Safe installation and replacement of household electrical circuits.' }, ar: { title: 'التوصيلات الكهربائية', desc: 'تركيب وإعادة توصيل دوائر المنزل الكهربائية بأمان.' } },
      { icon: I.pulse,  en: { title: 'Lighting Installation', desc: 'Ceiling lights, spotlights, chandeliers, and smart lighting setups.' }, ar: { title: 'تركيب الإضاءة', desc: 'إضاءة السقف والبقع الضوئية والثريات وأنظمة الإضاءة الذكية.' } },
      { icon: I.shield, en: { title: 'Safety Inspection', desc: 'Full circuit inspection, breaker checks, and compliance reporting.' }, ar: { title: 'فحص السلامة', desc: 'فحص كامل للدوائر الكهربائية وتقرير المطابقة.' } },
      { icon: I.gear,   en: { title: 'Panel Upgrades', desc: 'Main distribution board upgrades and load balancing for modern homes.' }, ar: { title: 'ترقية لوحات التوزيع', desc: 'ترقية لوحات التوزيع الرئيسية وموازنة الأحمال.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '300 – 700 EGP', jobs: 'Outlet repairs, light fixture swaps, and simple switch replacements.' }, ar: { tier: 'أساسي', price: '300 – 700 جنيه', jobs: 'إصلاح المقابس واستبدال تركيبات الإضاءة.' } },
      { featured: true, en: { tier: 'Standard', price: '700 – 1,500 EGP', jobs: 'Lighting installation, circuit additions, and panel work.' }, ar: { tier: 'معياري', price: '700 – 1,500 جنيه', jobs: 'تركيب الإضاءة وإضافة الدوائر وأعمال اللوحة.' } },
      { en: { tier: 'Complex', price: '1,500 – 3,000 EGP', jobs: 'Full rewiring, panel upgrades, and smart home integration.' }, ar: { tier: 'متقدم', price: '1,500 – 3,000 جنيه', jobs: 'إعادة التوصيل الكاملة وترقية اللوحات وتكامل المنزل الذكي.' } },
    ],
    faqs: [
      { en: { q: 'Are electricians licensed?', a: 'All our electricians hold valid trade licenses and complete safety training before joining the platform.' }, ar: { q: 'هل الكهربائيون مرخصون؟', a: 'جميع كهربائيونا يحملون رخص مهنية سارية ويجتازون تدريب السلامة.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Rewired our entire apartment professionally. Neat work and on budget."' }, ar: { ...REV_AY.ar, quote: '"إعادة توصيل شقتنا بالكامل باحترافية. عمل أنيق وفي حدود الميزانية."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Installed all our lighting fixtures in one visit. Highly recommend."' }, ar: { ...REV_SM.ar, quote: '"تركيب جميع تركيبات الإضاءة في زيارة واحدة. أنصح به بشدة."' } },
    ],
  },

  'ac-maintenance': {
    en: { title: 'A/C Maintenance & HVAC', lead: 'Professional air conditioning installation, servicing, and repair by certified HVAC technicians.', priceBadge: 'avg. 400 – 2,500 EGP', findBtn: 'Find an HVAC Technician →', ctaTitle: 'Ready to book AC service?', ctaSub: 'Browse our certified HVAC specialists available today.', ctaBtn: 'Browse Available Technicians →' },
    ar: { title: 'صيانة التكييف والتبريد', lead: 'تركيب وصيانة وإصلاح أجهزة التكييف من قبل فنيين مخصصين معتمدين.', priceBadge: 'متوسط 400 – 2,500 جنيه', findBtn: 'ابحث عن فني تكييف →', ctaTitle: 'جاهز لحجز صيانة تكييف؟', ctaSub: 'تصفح متخصصي التكييف المعتمدين المتاحين اليوم.', ctaBtn: 'تصفح الفنيين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1631545806609-5a1e3d9d5ff4?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.temp,   en: { title: 'AC Installation', desc: 'Full installation of split, window, and cassette AC units.' }, ar: { title: 'تركيب التكييف', desc: 'تركيب كامل لوحدات التكييف المنشق والنافذة والكاسيت.' } },
      { icon: I.gear,   en: { title: 'Annual Servicing', desc: 'Cleaning, gas refill checks, and performance optimization.' }, ar: { title: 'الصيانة السنوية', desc: 'تنظيف وفحص شحن الغاز وتحسين الأداء.' } },
      { icon: I.wrench, en: { title: 'Fault Diagnosis & Repair', desc: 'Identifying and fixing cooling failures, leaks, and compressor issues.' }, ar: { title: 'تشخيص الأعطال وإصلاحها', desc: 'تحديد وإصلاح أعطال التبريد والتسربات ومشاكل الضاغط.' } },
      { icon: I.shield, en: { title: 'Duct Cleaning', desc: 'Professional duct and filter cleaning for healthier air quality.' }, ar: { title: 'تنظيف المجاري الهوائية', desc: 'تنظيف احترافي للمجاري والفلاتر لجودة هواء أفضل.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '400 – 800 EGP', jobs: 'Filter cleaning, gas top-up checks, and minor fault fixes.' }, ar: { tier: 'أساسي', price: '400 – 800 جنيه', jobs: 'تنظيف الفلاتر وفحص شحن الغاز وإصلاح الأعطال البسيطة.' } },
      { featured: true, en: { tier: 'Standard', price: '800 – 1,500 EGP', jobs: 'Full service, duct cleaning, and component replacement.' }, ar: { tier: 'معياري', price: '800 – 1,500 جنيه', jobs: 'صيانة كاملة وتنظيف المجاري واستبدال المكونات.' } },
      { en: { tier: 'Complex', price: '1,500 – 2,500 EGP', jobs: 'New AC installation, compressor replacement, and multi-unit setups.' }, ar: { tier: 'متقدم', price: '1,500 – 2,500 جنيه', jobs: 'تركيب تكييف جديد واستبدال الضاغط وإعداد وحدات متعددة.' } },
    ],
    faqs: [
      { en: { q: 'How often should I service my AC?', a: 'We recommend servicing once a year before summer, with filter cleaning every 3 months.' }, ar: { q: 'كم مرة يجب صيانة التكييف؟', a: 'نوصي بالصيانة مرة سنوياً قبل الصيف مع تنظيف الفلاتر كل 3 أشهر.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"AC was making noise and not cooling. Fixed same day. Excellent service."' }, ar: { ...REV_AY.ar, quote: '"التكييف كان يصدر ضوضاء ولا يبرد. تم الإصلاح في نفس اليوم."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Full annual service done thoroughly. The technician explained everything."' }, ar: { ...REV_SM.ar, quote: '"صيانة سنوية كاملة تمت بدقة. شرح الفني كل شيء."' } },
    ],
  },

  carpentry: {
    en: { title: 'Carpentry Services', lead: 'Skilled woodwork, furniture repair, and structural carpentry by experienced craftsmen.', priceBadge: 'avg. 200 – 2,000 EGP', findBtn: 'Find a Carpenter →', ctaTitle: 'Ready to book a carpenter?', ctaSub: 'Browse our verified carpentry specialists.', ctaBtn: 'Browse Available Carpenters →' },
    ar: { title: 'خدمات النجارة', lead: 'أعمال خشبية ماهرة وإصلاح الأثاث ونجارة هيكلية من قبل حرفيين ذوي خبرة.', priceBadge: 'متوسط 200 – 2,000 جنيه', findBtn: 'ابحث عن نجار →', ctaTitle: 'جاهز لحجز نجار؟', ctaSub: 'تصفح متخصصي النجارة المعتمدين.', ctaBtn: 'تصفح النجارين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.wrench, en: { title: 'Furniture Repair', desc: 'Fix broken chairs, tables, cabinets, and wardrobe joints.' }, ar: { title: 'إصلاح الأثاث', desc: 'إصلاح الكراسي والطاولات والخزائن والمفاصل المكسورة.' } },
      { icon: I.home,   en: { title: 'Door & Window Work', desc: 'Fitting, adjustment, and repair of wooden doors and frames.' }, ar: { title: 'أعمال الأبواب والنوافذ', desc: 'تركيب وتعديل وإصلاح الأبواب الخشبية والإطارات.' } },
      { icon: I.gear,   en: { title: 'Custom Woodwork', desc: 'Bespoke shelves, cabinets, and built-in storage solutions.' }, ar: { title: 'الأعمال الخشبية المخصصة', desc: 'رفوف وخزائن وحلول تخزين مدمجة مخصصة.' } },
      { icon: I.shield, en: { title: 'Structural Fixes', desc: 'Load-bearing repairs and reinforcement of wooden structures.' }, ar: { title: 'الإصلاحات الهيكلية', desc: 'إصلاح وتعزيز الهياكل الخشبية الحاملة.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '200 – 500 EGP', jobs: 'Small furniture repairs, hinge replacements, and minor adjustments.' }, ar: { tier: 'أساسي', price: '200 – 500 جنيه', jobs: 'إصلاح الأثاث الصغير واستبدال المفصلات.' } },
      { featured: true, en: { tier: 'Standard', price: '500 – 1,200 EGP', jobs: 'Door fitting, custom shelving, and medium furniture repairs.' }, ar: { tier: 'معياري', price: '500 – 1,200 جنيه', jobs: 'تركيب الأبواب والرفوف المخصصة وإصلاح الأثاث المتوسط.' } },
      { en: { tier: 'Complex', price: '1,200 – 2,000 EGP', jobs: 'Built-in wardrobes, kitchen cabinets, and structural woodwork.' }, ar: { tier: 'متقدم', price: '1,200 – 2,000 جنيه', jobs: 'خزائن ملابس مدمجة وخزائن مطبخ وأعمال خشبية هيكلية.' } },
    ],
    faqs: [
      { en: { q: 'Do you supply the wood and materials?', a: 'Technicians can source materials for you at cost, or work with materials you provide.' }, ar: { q: 'هل يوفرون الخشب والمواد؟', a: 'يمكن للفنيين توفير المواد بالتكلفة أو العمل بمواد توفرها أنت.' } },
      FAQ_VERIFIED, FAQ_GUARANTEE,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Built custom wardrobes for two rooms. Excellent finish and on time."' }, ar: { ...REV_AY.ar, quote: '"بنى خزائن ملابس مخصصة لغرفتين. تشطيب ممتاز وفي الوقت المحدد."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Fixed all our doors that were sticking in summer. Quick and clean."' }, ar: { ...REV_SM.ar, quote: '"أصلح جميع أبوابنا التي كانت عالقة. سريع ونظيف."' } },
    ],
  },

  appliance: {
    en: { title: 'Appliance Services', lead: 'Installation, maintenance, and repair of household appliances by trained specialists.', priceBadge: 'avg. 150 – 1,500 EGP', findBtn: 'Find an Appliance Technician →', ctaTitle: 'Ready to book appliance service?', ctaSub: 'Browse our certified appliance repair specialists.', ctaBtn: 'Browse Available Technicians →' },
    ar: { title: 'صيانة الأجهزة المنزلية', lead: 'تركيب وصيانة وإصلاح الأجهزة المنزلية من قبل متخصصين مدربين.', priceBadge: 'متوسط 150 – 1,500 جنيه', findBtn: 'ابحث عن فني أجهزة →', ctaTitle: 'جاهز لحجز صيانة أجهزة؟', ctaSub: 'تصفح متخصصي إصلاح الأجهزة المعتمدين.', ctaBtn: 'تصفح الفنيين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.gear,   en: { title: 'Appliance Installation', desc: 'Professional setup of washing machines, ovens, dishwashers, and more.' }, ar: { title: 'تركيب الأجهزة', desc: 'إعداد احترافي للغسالات والأفران وغسالات الأطباق وغيرها.' } },
      { icon: I.wrench, en: { title: 'Fault Diagnosis & Repair', desc: 'Identifying and fixing electrical and mechanical appliance faults.' }, ar: { title: 'تشخيص وإصلاح الأعطال', desc: 'تحديد وإصلاح أعطال الأجهزة الكهربائية والميكانيكية.' } },
      { icon: I.shield, en: { title: 'Warranty Servicing', desc: 'Routine maintenance to keep appliances running at peak efficiency.' }, ar: { title: 'صيانة الضمان', desc: 'صيانة دورية للحفاظ على أداء الأجهزة بكفاءة قصوى.' } },
      { icon: I.pulse,  en: { title: 'Emergency Repair', desc: '24/7 rapid response for critical appliance failures.' }, ar: { title: 'الإصلاح الطارئ', desc: 'استجابة سريعة 24/7 لأعطال الأجهزة الحرجة.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '150 – 400 EGP', jobs: 'Diagnosis, minor faults, and simple part replacements.' }, ar: { tier: 'أساسي', price: '150 – 400 جنيه', jobs: 'التشخيص والأعطال البسيطة واستبدال الأجزاء الصغيرة.' } },
      { featured: true, en: { tier: 'Standard', price: '400 – 900 EGP', jobs: 'Installation setup, major fault repair, and servicing.' }, ar: { tier: 'معياري', price: '400 – 900 جنيه', jobs: 'إعداد التركيب وإصلاح الأعطال الكبيرة والصيانة.' } },
      { en: { tier: 'Complex', price: '900 – 1,500 EGP', jobs: 'Multi-appliance installation, compressor repair, and PCB replacement.' }, ar: { tier: 'متقدم', price: '900 – 1,500 جنيه', jobs: 'تركيب أجهزة متعددة وإصلاح الضاغط واستبدال اللوحة الإلكترونية.' } },
    ],
    faqs: [
      { en: { q: 'Do you carry spare parts?', a: 'Technicians bring common parts. Rare parts are ordered and installed in a follow-up visit, usually within 48 hours.' }, ar: { q: 'هل تحملون قطع الغيار؟', a: 'يحمل الفنيون الأجزاء الشائعة. الأجزاء النادرة تُطلب وتُركب في زيارة متابعة خلال 48 ساعة.' } },
      FAQ_VERIFIED, FAQ_GUARANTEE,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Washing machine fixed in one visit. Cheaper than I expected."' }, ar: { ...REV_AY.ar, quote: '"إصلاح الغسالة في زيارة واحدة. أرخص مما توقعت."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Installed new oven and dishwasher perfectly. Very professional."' }, ar: { ...REV_SM.ar, quote: '"تركيب فرن وغسالة أطباق جديدة بشكل مثالي. محترف جداً."' } },
    ],
  },

  handyman: {
    en: { title: 'Handyman Services', lead: 'General repairs, assembly, and small fix-it jobs handled quickly by experienced handymen.', priceBadge: 'avg. 100 – 800 EGP', findBtn: 'Find a Handyman →', ctaTitle: 'Need something fixed?', ctaSub: 'Browse our verified handyman specialists available today.', ctaBtn: 'Browse Available Handymen →' },
    ar: { title: 'خدمات الصيانة العامة', lead: 'إصلاحات عامة وتجميع وأعمال صغيرة يتم إنجازها بسرعة من قبل صيانة منزلية ذوي خبرة.', priceBadge: 'متوسط 100 – 800 جنيه', findBtn: 'ابحث عن فني صيانة →', ctaTitle: 'تحتاج إصلاح شيء؟', ctaSub: 'تصفح متخصصي الصيانة العامة المعتمدين المتاحين اليوم.', ctaBtn: 'تصفح المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.wrench, en: { title: 'General Repairs', desc: 'Wall patching, minor fixes, and household maintenance tasks.' }, ar: { title: 'الإصلاحات العامة', desc: 'ترقيع الجدران والإصلاحات البسيطة ومهام الصيانة المنزلية.' } },
      { icon: I.home,   en: { title: 'Furniture Assembly', desc: 'Flat-pack assembly for beds, wardrobes, and shelving units.' }, ar: { title: 'تجميع الأثاث', desc: 'تجميع الأثاث الجاهز للأسرة والخزائن والرفوف.' } },
      { icon: I.tv,     en: { title: 'Mounting & Hanging', desc: 'TV mounts, picture frames, curtain rails, and wall shelves.' }, ar: { title: 'التعليق والتثبيت', desc: 'حوامل التلفزيون والصور وقضبان الستائر والرفوف الجدارية.' } },
      { icon: I.gear,   en: { title: 'Door & Lock Fixes', desc: 'Sticking doors, broken handles, and lock replacement.' }, ar: { title: 'إصلاح الأبواب والأقفال', desc: 'الأبواب العالقة والمقابض المكسورة واستبدال الأقفال.' } },
    ],
    pricing: [
      { en: { tier: 'Quick Fix', price: '100 – 250 EGP', jobs: 'Single task — wall mount, assembly, or minor repair.' }, ar: { tier: 'إصلاح سريع', price: '100 – 250 جنيه', jobs: 'مهمة واحدة — تثبيت جداري أو تجميع أو إصلاح بسيط.' } },
      { featured: true, en: { tier: 'Half Day', price: '250 – 500 EGP', jobs: 'Multiple tasks completed in a 3–4 hour session.' }, ar: { tier: 'نصف يوم', price: '250 – 500 جنيه', jobs: 'مهام متعددة تُنجز في جلسة 3–4 ساعات.' } },
      { en: { tier: 'Full Day', price: '500 – 800 EGP', jobs: 'Full-day engagement for comprehensive household fixes.' }, ar: { tier: 'يوم كامل', price: '500 – 800 جنيه', jobs: 'تعامل ليوم كامل لإصلاحات منزلية شاملة.' } },
    ],
    faqs: [
      { en: { q: 'Can I book multiple tasks in one visit?', a: 'Yes — just list your tasks when booking. The handyman will work through them in order of priority.' }, ar: { q: 'هل يمكنني حجز مهام متعددة في زيارة واحدة؟', a: 'نعم — فقط اذكر مهامك عند الحجز وسيعمل الفني عليها بالترتيب.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Mounted TV, fixed two doors, and assembled a wardrobe in one visit. Brilliant."' }, ar: { ...REV_AY.ar, quote: '"تثبيت تلفزيون وإصلاح بابين وتجميع خزانة في زيارة واحدة. رائع."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Fast, friendly, and got everything done on my list. Will rebook."' }, ar: { ...REV_SM.ar, quote: '"سريع وودود وأنجز كل شيء في قائمتي. سأحجز مرة أخرى."' } },
    ],
  },

  renovation: {
    en: { title: 'Home Finishing & Renovation', lead: 'Complete renovation projects, interior finishing, and home transformation by master craftsmen.', priceBadge: 'avg. 5,000 – 50,000 EGP', findBtn: 'Find a Renovation Specialist →', ctaTitle: 'Ready to renovate?', ctaSub: 'Browse our verified renovation and finishing specialists.', ctaBtn: 'Browse Available Specialists →' },
    ar: { title: 'التشطيب والتجديد المنزلي', lead: 'مشاريع تجديد كاملة وتشطيب داخلي وتحويل المنزل من قبل حرفيين متمرسين.', priceBadge: 'متوسط 5,000 – 50,000 جنيه', findBtn: 'ابحث عن متخصص تجديد →', ctaTitle: 'جاهز للتجديد؟', ctaSub: 'تصفح متخصصي التجديد والتشطيب المعتمدين.', ctaBtn: 'تصفح المتخصصين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1523413651479-597eb2da0ad6?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.home,   en: { title: 'Full Room Renovation', desc: 'Complete overhaul of kitchens, bathrooms, and living spaces.' }, ar: { title: 'تجديد غرفة كاملة', desc: 'تجديد شامل للمطابخ والحمامات والمساحات المعيشية.' } },
      { icon: I.gear,   en: { title: 'Interior Finishing', desc: 'Plastering, painting, flooring, and finishing to a high standard.' }, ar: { title: 'التشطيب الداخلي', desc: 'الجص والدهان والأرضيات والتشطيب بمعايير عالية.' } },
      { icon: I.wrench, en: { title: 'Material Estimation', desc: 'Accurate costing and material planning before any work begins.' }, ar: { title: 'تقدير المواد', desc: 'حساب التكاليف والتخطيط للمواد بدقة قبل البدء بالعمل.' } },
      { icon: I.shield, en: { title: 'Project Management', desc: 'End-to-end oversight to keep projects on time and on budget.' }, ar: { title: 'إدارة المشاريع', desc: 'إشراف شامل للحفاظ على المشاريع في الوقت والميزانية المحددين.' } },
    ],
    pricing: [
      { en: { tier: 'Single Room', price: '5,000 – 15,000 EGP', jobs: 'One room renovation — bathroom, bedroom, or kitchen.' }, ar: { tier: 'غرفة واحدة', price: '5,000 – 15,000 جنيه', jobs: 'تجديد غرفة واحدة — حمام أو غرفة نوم أو مطبخ.' } },
      { featured: true, en: { tier: 'Apartment', price: '15,000 – 35,000 EGP', jobs: 'Multi-room renovation with full finishing and coordination.' }, ar: { tier: 'شقة', price: '15,000 – 35,000 جنيه', jobs: 'تجديد متعدد الغرف مع تشطيب كامل وتنسيق.' } },
      { en: { tier: 'Full Property', price: '35,000 – 50,000+ EGP', jobs: 'Complete property overhaul, structural changes, and premium finish.' }, ar: { tier: 'عقار كامل', price: '35,000 – 50,000+ جنيه', jobs: 'تجديد شامل للعقار وتغييرات هيكلية وتشطيب فاخر.' } },
    ],
    faqs: [
      { en: { q: 'How long does a renovation take?', a: 'A single room typically takes 1–2 weeks. Full apartment renovations take 4–8 weeks depending on scope.' }, ar: { q: 'كم يستغرق التجديد؟', a: 'غرفة واحدة تستغرق عادةً 1–2 أسبوع. تجديد شقة كاملة يستغرق 4–8 أسابيع حسب النطاق.' } },
      FAQ_VERIFIED, FAQ_GUARANTEE,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Transformed our bathroom completely. Stunning result within budget."' }, ar: { ...REV_AY.ar, quote: '"تحويل حمامنا بالكامل. نتيجة مذهلة في حدود الميزانية."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Kitchen renovation done on time with zero surprises on pricing."' }, ar: { ...REV_SM.ar, quote: '"تجديد المطبخ في الوقت المحدد بدون مفاجآت في التسعير."' } },
    ],
  },

  painting: {
    en: { title: 'Painting Services', lead: 'Professional interior and exterior painting, wallpapering, and surface finishing by expert painters.', priceBadge: 'avg. 1,000 – 8,000 EGP', findBtn: 'Find a Painter →', ctaTitle: 'Ready to book a painter?', ctaSub: 'Browse our professional painting specialists.', ctaBtn: 'Browse Available Painters →' },
    ar: { title: 'خدمات الدهانات', lead: 'دهانات داخلية وخارجية احترافية وتركيب ورق الجدران وتشطيب الأسطح من قبل دهانين خبراء.', priceBadge: 'متوسط 1,000 – 8,000 جنيه', findBtn: 'ابحث عن دهان →', ctaTitle: 'جاهز لحجز دهان؟', ctaSub: 'تصفح متخصصي الدهانات الاحترافية.', ctaBtn: 'تصفح الدهانين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.paint, en: { title: 'Interior Painting', desc: 'Walls, ceilings, and trims painted to a smooth, even finish.' }, ar: { title: 'الدهان الداخلي', desc: 'طلاء الجدران والأسقف والحواف بتشطيب ناعم ومتساوٍ.' } },
      { icon: I.home,  en: { title: 'Exterior Painting', desc: 'Weather-resistant exterior painting for facades and balconies.' }, ar: { title: 'الدهان الخارجي', desc: 'طلاء خارجي مقاوم للعوامل الجوية للواجهات والبلكونات.' } },
      { icon: I.gear,  en: { title: 'Surface Preparation', desc: 'Filling, sanding, and priming for a flawless final coat.' }, ar: { title: 'تحضير الأسطح', desc: 'حشو وصنفرة وتأسيس لطبقة نهائية مثالية.' } },
      { icon: I.shield, en: { title: 'Wallpaper Installation', desc: 'Precision wallpaper hanging and removal services.' }, ar: { title: 'تركيب ورق الجدران', desc: 'تركيب وإزالة ورق الجدران بدقة.' } },
    ],
    pricing: [
      { en: { tier: 'Single Room', price: '1,000 – 2,500 EGP', jobs: 'One room — walls and ceiling, standard paint supplied.' }, ar: { tier: 'غرفة واحدة', price: '1,000 – 2,500 جنيه', jobs: 'غرفة واحدة — الجدران والسقف، دهان قياسي مُتضمَّن.' } },
      { featured: true, en: { tier: 'Apartment', price: '2,500 – 5,500 EGP', jobs: 'All rooms including living room, bedrooms, and kitchen.' }, ar: { tier: 'شقة', price: '2,500 – 5,500 جنيه', jobs: 'جميع الغرف بما فيها الصالة وغرف النوم والمطبخ.' } },
      { en: { tier: 'Full Property', price: '5,500 – 8,000 EGP', jobs: 'Full interior + exterior, premium paints, and trims.' }, ar: { tier: 'عقار كامل', price: '5,500 – 8,000 جنيه', jobs: 'داخلي كامل + خارجي، دهانات فاخرة وحواف.' } },
    ],
    faqs: [
      { en: { q: 'Do you supply the paint?', a: 'Painters can supply quality paints at cost, or work with paints you choose and provide.' }, ar: { q: 'هل توفرون الدهان؟', a: 'يمكن للدهانين توفير دهانات عالية الجودة بالتكلفة أو العمل بدهانات تختارها أنت.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Entire apartment painted in 2 days. Clean, fast, and great finish."' }, ar: { ...REV_AY.ar, quote: '"طلاء الشقة كاملة في يومين. نظيف وسريع وتشطيب رائع."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Wallpaper installed perfectly. Not a single bubble or crease."' }, ar: { ...REV_SM.ar, quote: '"تركيب ورق الجدران بشكل مثالي. لا فقاعة ولا تجعد."' } },
    ],
  },

  flooring: {
    en: { title: 'Flooring Services', lead: 'Installation and repair of hardwood, tile, marble, and vinyl flooring by specialist craftsmen.', priceBadge: 'avg. 500 – 5,000 EGP', findBtn: 'Find a Flooring Specialist →', ctaTitle: 'Ready to book flooring service?', ctaSub: 'Browse our certified flooring installation specialists.', ctaBtn: 'Browse Available Specialists →' },
    ar: { title: 'خدمات الأرضيات', lead: 'تركيب وإصلاح أرضيات الخشب والبلاط والرخام والفينيل من قبل حرفيين متخصصين.', priceBadge: 'متوسط 500 – 5,000 جنيه', findBtn: 'ابحث عن متخصص أرضيات →', ctaTitle: 'جاهز لحجز خدمة أرضيات؟', ctaSub: 'تصفح متخصصي تركيب الأرضيات المعتمدين.', ctaBtn: 'تصفح المتخصصين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1581783898377-1c624d3c9620?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.home,   en: { title: 'Tile & Marble Installation', desc: 'Precision laying of ceramic, porcelain, and marble tiles.' }, ar: { title: 'تركيب البلاط والرخام', desc: 'تركيب دقيق للبلاط الخزفي والبورسلان والرخام.' } },
      { icon: I.wrench, en: { title: 'Hardwood & Parquet', desc: 'Installation and refinishing of solid and engineered wood floors.' }, ar: { title: 'الباركيه والخشب الصلب', desc: 'تركيب وإعادة تشطيب أرضيات الخشب الصلب والمهندس.' } },
      { icon: I.gear,   en: { title: 'Vinyl & Laminate', desc: 'Waterproof vinyl and laminate flooring installation.' }, ar: { title: 'الفينيل واللاميناك', desc: 'تركيب أرضيات الفينيل واللاميناك المقاومة للماء.' } },
      { icon: I.shield, en: { title: 'Repair & Polishing', desc: 'Crack repair, grout resealing, and surface polishing.' }, ar: { title: 'الإصلاح والتلميع', desc: 'إصلاح الشقوق وإعادة ختم الفواصل وتلميع الأسطح.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '500 – 1,500 EGP', jobs: 'Single room tile installation or vinyl laying.' }, ar: { tier: 'أساسي', price: '500 – 1,500 جنيه', jobs: 'تركيب بلاط غرفة واحدة أو فينيل.' } },
      { featured: true, en: { tier: 'Standard', price: '1,500 – 3,000 EGP', jobs: 'Multi-room flooring with full surface preparation.' }, ar: { tier: 'معياري', price: '1,500 – 3,000 جنيه', jobs: 'أرضيات متعددة الغرف مع تحضير كامل للسطح.' } },
      { en: { tier: 'Premium', price: '3,000 – 5,000 EGP', jobs: 'Marble, hardwood, or full-property flooring installation.' }, ar: { tier: 'فاخر', price: '3,000 – 5,000 جنيه', jobs: 'تركيب رخام أو باركيه أو أرضيات عقار كامل.' } },
    ],
    faqs: [
      { en: { q: 'How long does flooring installation take?', a: 'A single room takes 1 day. A full apartment typically takes 3–5 days depending on material and size.' }, ar: { q: 'كم يستغرق تركيب الأرضيات؟', a: 'غرفة واحدة تستغرق يوماً. شقة كاملة عادةً 3–5 أيام حسب المادة والحجم.' } },
      FAQ_VERIFIED, FAQ_GUARANTEE,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Marble flooring installed beautifully. Very neat and no mess left behind."' }, ar: { ...REV_AY.ar, quote: '"تركيب أرضيات الرخام بشكل جميل. أنيق جداً ولا فوضى."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Vinyl flooring done for the whole apartment. Fast and affordable."' }, ar: { ...REV_SM.ar, quote: '"فينيل للشقة كاملة. سريع وبأسعار معقولة."' } },
    ],
  },

  drywall: {
    en: { title: 'Drywall & Plastering', lead: 'Professional drywall installation, seamless patching, and plastering by skilled specialists.', priceBadge: 'avg. 300 – 3,000 EGP', findBtn: 'Find a Drywall Specialist →', ctaTitle: 'Ready to book drywall service?', ctaSub: 'Browse our certified drywall and plastering specialists.', ctaBtn: 'Browse Available Specialists →' },
    ar: { title: 'الجبس والجدران الجافة', lead: 'تركيب ألواح الجبسبورد وترقيع سلس وأعمال الجص من قبل متخصصين مهرة.', priceBadge: 'متوسط 300 – 3,000 جنيه', findBtn: 'ابحث عن متخصص جبس →', ctaTitle: 'جاهز لحجز خدمة جبس؟', ctaSub: 'تصفح متخصصي الجبسبورد والجص المعتمدين.', ctaBtn: 'تصفح المتخصصين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.home,   en: { title: 'Drywall Installation', desc: 'New partition walls and ceilings using gypsum board systems.' }, ar: { title: 'تركيب الجبسبورد', desc: 'جدران وأسقف تقسيم جديدة باستخدام أنظمة الجبسبورد.' } },
      { icon: I.wrench, en: { title: 'Crack & Hole Patching', desc: 'Seamless repair of cracks, holes, and surface damage.' }, ar: { title: 'ترقيع الشقوق والفجوات', desc: 'إصلاح سلس للشقوق والفجوات وأضرار الأسطح.' } },
      { icon: I.gear,   en: { title: 'Skim Coating', desc: 'Smooth finish plaster coat applied over existing walls.' }, ar: { title: 'طبقة التسوية', desc: 'طبقة جص ناعمة تُطبَّق على الجدران الموجودة.' } },
      { icon: I.shield, en: { title: 'Insulation Boarding', desc: 'Thermal and acoustic insulation board installation.' }, ar: { title: 'ألواح العزل', desc: 'تركيب ألواح العزل الحراري والصوتي.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '300 – 800 EGP', jobs: 'Crack repairs, small patches, and skim coat on one wall.' }, ar: { tier: 'أساسي', price: '300 – 800 جنيه', jobs: 'إصلاح الشقوق والترقيعات الصغيرة وطبقة تسوية على جدار واحد.' } },
      { featured: true, en: { tier: 'Standard', price: '800 – 2,000 EGP', jobs: 'Room partition, ceiling work, or full skim coat.' }, ar: { tier: 'معياري', price: '800 – 2,000 جنيه', jobs: 'تقسيم غرفة أو أعمال سقف أو طبقة تسوية كاملة.' } },
      { en: { tier: 'Complex', price: '2,000 – 3,000 EGP', jobs: 'Multi-room drywall, insulation, and complete finishing.' }, ar: { tier: 'متقدم', price: '2,000 – 3,000 جنيه', jobs: 'جبسبورد متعدد الغرف وعزل وتشطيب كامل.' } },
    ],
    faqs: [
      { en: { q: 'How long does drywall work take to dry?', a: 'Compound typically dries in 24 hours. Full plastering needs 48–72 hours before painting.' }, ar: { q: 'كم يستغرق جفاف الجبس؟', a: 'يجف المعجون عادةً خلال 24 ساعة. الجص الكامل يحتاج 48–72 ساعة قبل الطلاء.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Partition wall built cleanly in one day. Couldn\'t tell it was new."' }, ar: { ...REV_AY.ar, quote: '"جدار تقسيم بُني بشكل نظيف في يوم واحد. لم تكن تشعر أنه جديد."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Ceiling cracks patched perfectly. Ready to paint the next day."' }, ar: { ...REV_SM.ar, quote: '"شقوق السقف رُقِّعت بشكل مثالي. جاهز للطلاء في اليوم التالي."' } },
    ],
  },

  roofing: {
    en: { title: 'Roofing Services', lead: 'Professional roof leak repair, tile replacement, and waterproofing by experienced roofing specialists.', priceBadge: 'avg. 500 – 5,000 EGP', findBtn: 'Find a Roofing Specialist →', ctaTitle: 'Ready to book roofing service?', ctaSub: 'Browse our certified roofing specialists.', ctaBtn: 'Browse Available Specialists →' },
    ar: { title: 'أعمال الأسقف', lead: 'إصلاح تسربات الأسقف واستبدال البلاط والعزل المائي من قبل متخصصين ذوي خبرة.', priceBadge: 'متوسط 500 – 5,000 جنيه', findBtn: 'ابحث عن متخصص أسقف →', ctaTitle: 'جاهز لحجز خدمة أسقف؟', ctaSub: 'تصفح متخصصي الأسقف المعتمدين.', ctaBtn: 'تصفح المتخصصين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1591854272024-0e12e4c07a7c?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.shield, en: { title: 'Leak Detection & Repair', desc: 'Finding and sealing all roof leak sources permanently.' }, ar: { title: 'كشف وإصلاح التسربات', desc: 'إيجاد وإغلاق جميع مصادر تسربات الأسقف بشكل دائم.' } },
      { icon: I.wrench, en: { title: 'Tile Replacement', desc: 'Broken and missing roof tile replacement.' }, ar: { title: 'استبدال القرميد', desc: 'استبدال القرميد المكسور والمفقود.' } },
      { icon: I.drop,   en: { title: 'Waterproofing', desc: 'Application of waterproof membranes and sealants.' }, ar: { title: 'العزل المائي', desc: 'تطبيق أغشية وإغلاق مقاوم للماء.' } },
      { icon: I.gear,   en: { title: 'Roof Inspection', desc: 'Comprehensive assessment and condition report.' }, ar: { title: 'فحص السطح', desc: 'تقييم شامل وتقرير حالة.' } },
    ],
    pricing: [
      { en: { tier: 'Basic', price: '500 – 1,200 EGP', jobs: 'Single leak repair or small section patching.' }, ar: { tier: 'أساسي', price: '500 – 1,200 جنيه', jobs: 'إصلاح تسرب واحد أو ترقيع قسم صغير.' } },
      { featured: true, en: { tier: 'Standard', price: '1,200 – 3,000 EGP', jobs: 'Full waterproofing treatment or major tile replacement.' }, ar: { tier: 'معياري', price: '1,200 – 3,000 جنيه', jobs: 'معالجة عزل مائي كاملة أو استبدال قرميد كبير.' } },
      { en: { tier: 'Complex', price: '3,000 – 5,000 EGP', jobs: 'Full roof restoration, structural repairs, and membrane installation.' }, ar: { tier: 'متقدم', price: '3,000 – 5,000 جنيه', jobs: 'ترميم سطح كامل وإصلاحات هيكلية وتركيب غشاء.' } },
    ],
    faqs: [
      { en: { q: 'How do I know if my roof needs repair?', a: 'Signs include water stains on ceilings, visible cracks in tiles, or damp walls after rain. Book an inspection to confirm.' }, ar: { q: 'كيف أعرف إذا كان السطح يحتاج إصلاح؟', a: 'علامات تشمل بقع الماء على الأسقف والشقوق الظاهرة والجدران الرطبة بعد المطر.' } },
      FAQ_VERIFIED, FAQ_GUARANTEE,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Roof leak fixed before the next rain. Excellent waterproofing job."' }, ar: { ...REV_AY.ar, quote: '"تسرب السطح أُصلح قبل المطر التالي. عمل عزل مائي ممتاز."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Full roof inspection and repair completed in one day. Very thorough."' }, ar: { ...REV_SM.ar, quote: '"فحص وإصلاح كامل للسطح في يوم واحد. شامل جداً."' } },
    ],
  },

  'pest-control': {
    en: { title: 'Pest Control', lead: 'Safe, eco-conscious elimination of household pests by certified pest control specialists.', priceBadge: 'avg. 200 – 1,500 EGP', findBtn: 'Find a Pest Control Specialist →', ctaTitle: 'Ready to eliminate pests?', ctaSub: 'Browse our certified pest control specialists.', ctaBtn: 'Browse Available Specialists →' },
    ar: { title: 'مكافحة الحشرات', lead: 'إبادة آمنة وصديقة للبيئة للحشرات المنزلية من قبل متخصصين معتمدين.', priceBadge: 'متوسط 200 – 1,500 جنيه', findBtn: 'ابحث عن متخصص مكافحة →', ctaTitle: 'جاهز للتخلص من الحشرات؟', ctaSub: 'تصفح متخصصي مكافحة الحشرات المعتمدين.', ctaBtn: 'تصفح المتخصصين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1600948836101-f9ffda59d250?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.bug,    en: { title: 'Pest Inspection', desc: 'Full property assessment to identify pest types and entry points.' }, ar: { title: 'فحص الحشرات', desc: 'تقييم كامل للعقار لتحديد أنواع الحشرات ونقاط الدخول.' } },
      { icon: I.shield, en: { title: 'Chemical Treatment', desc: 'Safe, targeted pesticide application for effective elimination.' }, ar: { title: 'المعالجة الكيميائية', desc: 'تطبيق مبيدات حشرية آمن ومستهدف للإبادة الفعالة.' } },
      { icon: I.gear,   en: { title: 'Prevention Sealing', desc: 'Sealing entry points to prevent future infestations.' }, ar: { title: 'إغلاق نقاط الدخول', desc: 'إغلاق نقاط الدخول لمنع التكرار مستقبلاً.' } },
      { icon: I.pulse,  en: { title: 'Follow-up Treatment', desc: 'Return visit to confirm full elimination and apply if needed.' }, ar: { title: 'المتابعة والعلاج اللاحق', desc: 'زيارة عودة للتأكد من الإبادة الكاملة.' } },
    ],
    pricing: [
      { en: { tier: 'Single Room', price: '200 – 400 EGP', jobs: 'Targeted treatment for one room or specific pest type.' }, ar: { tier: 'غرفة واحدة', price: '200 – 400 جنيه', jobs: 'معالجة مستهدفة لغرفة واحدة أو نوع محدد من الحشرات.' } },
      { featured: true, en: { tier: 'Apartment', price: '400 – 900 EGP', jobs: 'Full apartment treatment with follow-up visit included.' }, ar: { tier: 'شقة', price: '400 – 900 جنيه', jobs: 'معالجة شقة كاملة مع زيارة متابعة مشمولة.' } },
      { en: { tier: 'Property', price: '900 – 1,500 EGP', jobs: 'Full property treatment, sealing, and prevention plan.' }, ar: { tier: 'عقار', price: '900 – 1,500 جنيه', jobs: 'معالجة كاملة للعقار وإغلاق وخطة وقاية.' } },
    ],
    faqs: [
      { en: { q: 'Are the chemicals safe for children and pets?', a: 'We use certified, regulated products. Technicians advise on ventilation time (usually 2–4 hours) before re-entry.' }, ar: { q: 'هل المواد الكيميائية آمنة للأطفال والحيوانات؟', a: 'نستخدم منتجات معتمدة ومُنظَّمة. يُرشد الفنيون حول وقت التهوية (عادةً 2–4 ساعات) قبل العودة.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Cockroach problem gone after one treatment. Haven\'t seen one since."' }, ar: { ...REV_AY.ar, quote: '"مشكلة الصراصير اختفت بعد علاج واحد. لم أرَ واحداً منذ ذلك."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Professional, fast, and effective. The follow-up visit was a nice touch."' }, ar: { ...REV_SM.ar, quote: '"محترف وسريع وفعال. زيارة المتابعة كانت لمسة جيدة."' } },
    ],
  },

  cleaning: {
    en: { title: 'Professional Cleaning', lead: 'Regular, deep-clean, and post-construction cleaning by trained professional cleaners.', priceBadge: 'avg. 200 – 1,500 EGP', findBtn: 'Find a Cleaning Specialist →', ctaTitle: 'Ready to book cleaning?', ctaSub: 'Browse our professional cleaning specialists.', ctaBtn: 'Browse Available Cleaners →' },
    ar: { title: 'التنظيف الاحترافي', lead: 'تنظيف دوري وعميق وما بعد البناء من قبل عمال تنظيف مدربين محترفين.', priceBadge: 'متوسط 200 – 1,500 جنيه', findBtn: 'ابحث عن متخصص تنظيف →', ctaTitle: 'جاهز لحجز تنظيف؟', ctaSub: 'تصفح متخصصي التنظيف الاحترافي.', ctaBtn: 'تصفح المنظفين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1527515545081-5db817172677?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.shield, en: { title: 'Regular Cleaning', desc: 'Scheduled weekly or bi-weekly cleaning for home maintenance.' }, ar: { title: 'التنظيف الدوري', desc: 'تنظيف مجدول أسبوعياً أو كل أسبوعين لصيانة المنزل.' } },
      { icon: I.gear,   en: { title: 'Deep Cleaning', desc: 'Thorough top-to-bottom cleaning including appliances and fixtures.' }, ar: { title: 'التنظيف العميق', desc: 'تنظيف شامل من الأعلى للأسفل بما فيه الأجهزة والتجهيزات.' } },
      { icon: I.home,   en: { title: 'Move-in / Move-out', desc: 'Complete property cleaning before or after tenancy.' }, ar: { title: 'نقل الملكية', desc: 'تنظيف كامل للعقار قبل أو بعد الإقامة.' } },
      { icon: I.wrench, en: { title: 'Post-Construction', desc: 'Dust, debris, and material removal after renovation work.' }, ar: { title: 'ما بعد البناء', desc: 'إزالة الغبار والحطام والمواد بعد أعمال التجديد.' } },
    ],
    pricing: [
      { en: { tier: 'Regular', price: '200 – 400 EGP', jobs: 'Standard cleaning of a 2–3 bedroom apartment.' }, ar: { tier: 'عادي', price: '200 – 400 جنيه', jobs: 'تنظيف قياسي لشقة من 2–3 غرف نوم.' } },
      { featured: true, en: { tier: 'Deep Clean', price: '400 – 900 EGP', jobs: 'Full deep clean including oven, fridge, and bathroom tiles.' }, ar: { tier: 'تنظيف عميق', price: '400 – 900 جنيه', jobs: 'تنظيف عميق كامل شاملاً الفرن والثلاجة وبلاط الحمام.' } },
      { en: { tier: 'Post-Renovation', price: '900 – 1,500 EGP', jobs: 'Construction debris removal and full sanitization.' }, ar: { tier: 'ما بعد التجديد', price: '900 – 1,500 جنيه', jobs: 'إزالة نفايات البناء والتعقيم الكامل.' } },
    ],
    faqs: [
      { en: { q: 'Do cleaners bring their own supplies?', a: 'Yes — all equipment and cleaning products are provided. Just let us know if you have preference for eco-friendly products.' }, ar: { q: 'هل يحضر المنظفون معداتهم؟', a: 'نعم — يتم توفير جميع المعدات والمنظفات. فقط أخبرنا إذا كنت تفضل المنتجات الصديقة للبيئة.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Deep clean before moving in was outstanding. The place was spotless."' }, ar: { ...REV_AY.ar, quote: '"تنظيف عميق قبل الانتقال كان رائعاً. المكان كان نظيفاً تماماً."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Weekly cleaner is fantastic. Consistently thorough every time."' }, ar: { ...REV_SM.ar, quote: '"المنظف الأسبوعي رائع. شامل باستمرار في كل مرة."' } },
    ],
  },

  landscaping: {
    en: { title: 'Landscaping Services', lead: 'Garden design, lawn care, planting, and irrigation setup by professional landscapers.', priceBadge: 'avg. 300 – 3,000 EGP', findBtn: 'Find a Landscaper →', ctaTitle: 'Ready to transform your garden?', ctaSub: 'Browse our certified landscaping specialists.', ctaBtn: 'Browse Available Landscapers →' },
    ar: { title: 'تنسيق الحدائق', lead: 'تصميم الحدائق والعناية بالعشب والزراعة وإعداد الري من قبل منسقي حدائق محترفين.', priceBadge: 'متوسط 300 – 3,000 جنيه', findBtn: 'ابحث عن منسق حدائق →', ctaTitle: 'جاهز لتحويل حديقتك؟', ctaSub: 'تصفح متخصصي تنسيق الحدائق المعتمدين.', ctaBtn: 'تصفح المنسقين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1558904541-efa843a96f01?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.leaf,   en: { title: 'Garden Design', desc: 'Layout planning, plant selection, and aesthetic garden design.' }, ar: { title: 'تصميم الحديقة', desc: 'تخطيط التصميم واختيار النباتات وتصميم الحديقة الجمالي.' } },
      { icon: I.gear,   en: { title: 'Lawn Care', desc: 'Mowing, edging, fertilizing, and lawn health maintenance.' }, ar: { title: 'العناية بالعشب', desc: 'القص والتشذيب والتسميد والحفاظ على صحة العشب.' } },
      { icon: I.drop,   en: { title: 'Irrigation Setup', desc: 'Drip and sprinkler system installation and programming.' }, ar: { title: 'إعداد الري', desc: 'تركيب وبرمجة أنظمة الري بالتنقيط والرشاشات.' } },
      { icon: I.shield, en: { title: 'Planting & Transplanting', desc: 'Trees, shrubs, and seasonal plant installation.' }, ar: { title: 'الزراعة وإعادة الزراعة', desc: 'زراعة الأشجار والشجيرات والنباتات الموسمية.' } },
    ],
    pricing: [
      { en: { tier: 'Maintenance', price: '300 – 700 EGP', jobs: 'Regular lawn mowing, watering, and light trimming.' }, ar: { tier: 'صيانة', price: '300 – 700 جنيه', jobs: 'قص العشب الدوري والري والتقليم الخفيف.' } },
      { featured: true, en: { tier: 'Design & Plant', price: '700 – 2,000 EGP', jobs: 'Full planting plan, new plantings, and irrigation setup.' }, ar: { tier: 'تصميم وزراعة', price: '700 – 2,000 جنيه', jobs: 'خطة زراعة كاملة وزراعات جديدة وإعداد ري.' } },
      { en: { tier: 'Full Landscape', price: '2,000 – 3,000 EGP', jobs: 'Complete garden redesign, hardscaping, and irrigation.' }, ar: { tier: 'منظر طبيعي كامل', price: '2,000 – 3,000 جنيه', jobs: 'إعادة تصميم حديقة كاملة وأعمال صلبة وري.' } },
    ],
    faqs: [
      { en: { q: 'Do you supply plants and materials?', a: 'Landscapers can source plants and materials at cost, or work with what you already have.' }, ar: { q: 'هل توفرون النباتات والمواد؟', a: 'يمكن للمنسقين توفير النباتات والمواد بالتكلفة أو العمل بما لديك.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"Garden completely transformed. The design exceeded our expectations."' }, ar: { ...REV_AY.ar, quote: '"تحويل الحديقة بالكامل. التصميم تجاوز توقعاتنا."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"Irrigation system installed perfectly. Saved us so much time watering."' }, ar: { ...REV_SM.ar, quote: '"نظام الري مُركَّب بشكل مثالي. وفّر لنا وقتاً كبيراً في الري."' } },
    ],
  },

  installation: {
    en: { title: 'Installation Services', lead: 'Professional mounting and installation of TVs, shelving, curtain rails, and home accessories.', priceBadge: 'avg. 100 – 800 EGP', findBtn: 'Find an Installation Specialist →', ctaTitle: 'Need something installed?', ctaSub: 'Browse our installation specialists available today.', ctaBtn: 'Browse Available Specialists →' },
    ar: { title: 'خدمات التركيب', lead: 'تركيب احترافي لأجهزة التلفزيون والرفوف وقضبان الستائر والإكسسوارات المنزلية.', priceBadge: 'متوسط 100 – 800 جنيه', findBtn: 'ابحث عن متخصص تركيب →', ctaTitle: 'تحتاج تركيب شيء؟', ctaSub: 'تصفح متخصصي التركيب المتاحين اليوم.', ctaBtn: 'تصفح المتخصصين المتاحين →' },
    heroImage: 'https://images.unsplash.com/photo-1598300042247-d088f8ab3a91?auto=format&fit=crop&w=1600&q=80',
    included: [
      { icon: I.tv,     en: { title: 'TV Wall Mounting', desc: 'Secure TV bracket installation on any wall type.' }, ar: { title: 'تركيب حامل التلفزيون', desc: 'تركيب حامل تلفزيون آمن على أي نوع جدار.' } },
      { icon: I.home,   en: { title: 'Shelving & Storage', desc: 'Wall shelves, floating units, and storage rack installation.' }, ar: { title: 'الرفوف والتخزين', desc: 'رفوف جدارية ووحدات عائمة وتركيب رفوف التخزين.' } },
      { icon: I.gear,   en: { title: 'Curtain & Blind Rails', desc: 'Fitting curtain poles, tracks, and roller blind systems.' }, ar: { title: 'قضبان الستائر والشادر', desc: 'تركيب قضبان الستائر والمسارات وأنظمة الشادر.' } },
      { icon: I.wrench, en: { title: 'Door Accessories', desc: 'Handles, locks, closers, and door stop installation.' }, ar: { title: 'إكسسوارات الأبواب', desc: 'تركيب المقابض والأقفال وأجهزة الإغلاق ومانع الأبواب.' } },
    ],
    pricing: [
      { en: { tier: 'Single Item', price: '100 – 200 EGP', jobs: 'One item — TV mount, shelf, or curtain rail.' }, ar: { tier: 'عنصر واحد', price: '100 – 200 جنيه', jobs: 'عنصر واحد — حامل تلفزيون أو رف أو قضيب ستارة.' } },
      { featured: true, en: { tier: 'Multi-Item', price: '200 – 500 EGP', jobs: '3–6 items installed in one visit.' }, ar: { tier: 'عدة عناصر', price: '200 – 500 جنيه', jobs: '3–6 عناصر مُركَّبة في زيارة واحدة.' } },
      { en: { tier: 'Full Setup', price: '500 – 800 EGP', jobs: 'Full room setup — TV, shelves, curtains, and accessories.' }, ar: { tier: 'إعداد كامل', price: '500 – 800 جنيه', jobs: 'إعداد غرفة كاملة — تلفزيون ورفوف وستائر وإكسسوارات.' } },
    ],
    faqs: [
      { en: { q: 'Can you mount on any wall type?', a: 'Yes — concrete, brick, plasterboard, and tiled walls. The technician will use the right fixings for each surface.' }, ar: { q: 'هل يمكنكم التركيب على أي نوع جدار؟', a: 'نعم — خرسانة وطوب وجبسبورد وجدران مبلطة. سيستخدم الفني التثبيتات المناسبة لكل سطح.' } },
      FAQ_VERIFIED, FAQ_PAYMENT,
    ],
    reviews: [
      { ...REV_AY, en: { ...REV_AY.en, quote: '"TV mounted perfectly and cables hidden in the wall. Looks great."' }, ar: { ...REV_AY.ar, quote: '"تثبيت التلفزيون بشكل مثالي والكابلات مخفية في الجدار."' } },
      { ...REV_SM, en: { ...REV_SM.en, quote: '"All shelves and curtain rails done in under 2 hours. Excellent."' }, ar: { ...REV_SM.ar, quote: '"جميع الرفوف وقضبان الستائر مُنجزة في أقل من ساعتين."' } },
    ],
  },

};

/* ─── Service → Technician ID mapping ─────────────────────────────── */
export const SERVICE_TECHNICIANS = {
  plumbing:         [1],
  electrical:       [2],
  'ac-maintenance': [3],
  cleaning:         [3],
  painting:         [4],
  carpentry:        [5],
  handyman:         [1, 5],
  // renovation, flooring, drywall, roofing, pest-control, landscaping, installation → all 5
};

/** Returns the technician IDs to show for a given service key. */
export function getTechsForService(serviceKey) {
  return SERVICE_TECHNICIANS[serviceKey] || [1, 2, 3, 4, 5];
}
