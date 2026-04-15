import '../models/bilingual_text.dart';
import '../models/service_model.dart';

const ServiceFaq _faqVerified = ServiceFaq(
  question: BilingualText(
    en: 'Are technicians verified?',
    ar: 'هل الفنيون معتمدون؟',
  ),
  answer: BilingualText(
    en: 'All SERVIO technicians pass ID verification, trade certification checks, and a background screening before joining.',
    ar: 'جميع فنيو SERVIO يجتازون التحقق من الهوية وشهادة المهنة والفحص الأمني قبل الانضمام.',
  ),
);

const ServiceFaq _faqPayment = ServiceFaq(
  question: BilingualText(
    en: 'Can I pay in cash?',
    ar: 'هل يمكنني الدفع نقداً؟',
  ),
  answer: BilingualText(
    en: 'Yes — cash payment is supported. For full payment protection, online payment is also available.',
    ar: 'نعم — الدفع النقدي مدعوم. الدفع الإلكتروني متاح أيضاً لحماية كاملة.',
  ),
);

const ServiceFaq _faqGuarantee = ServiceFaq(
  question: BilingualText(
    en: 'What if I\'m not satisfied?',
    ar: 'ماذا لو لم أكن راضياً؟',
  ),
  answer: BilingualText(
    en: 'Payment is only finalized once you confirm the job is complete. Raise a dispute within 48 hours and our team resolves it.',
    ar: 'يتم تأكيد الدفع فقط بعد تأكيدك اكتمال العمل. قدّم نزاعاً خلال 48 ساعة وسيحل فريقنا المشكلة.',
  ),
);

const List<ServiceModel> kDemoServices = <ServiceModel>[
  ServiceModel(
    id: 'plumbing',
    icon: 'drop',
    title: BilingualText(en: 'Plumbing Services', ar: 'خدمات السباكة'),
    lead: BilingualText(
      en: 'Expert pipe repair, leak detection, and fixture installation by verified professionals.',
      ar: 'إصلاح الأنابيب والكشف عن التسربات وتركيب الأجهزة من قبل متخصصين معتمدين.',
    ),
    priceBadge: BilingualText(en: 'avg. 200 – 2,000 EGP', ar: 'متوسط 200 – 2,000 جنيه'),
    heroImageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(en: 'Ready to book a plumber?', ar: 'جاهز لحجز سباك؟'),
    ctaSub: BilingualText(
      en: 'Browse our network of verified plumbing specialists.',
      ar: 'تصفح شبكتنا من متخصصي السباكة المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Pipe Repair', ar: 'إصلاح الأنابيب'),
        desc: BilingualText(
          en: 'Fix leaks, bursts, and corrosion in supply and drain lines.',
          ar: 'إصلاح التسربات والانفجارات والتآكل في خطوط التوريد.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Leak Detection', ar: 'كشف التسربات'),
        desc: BilingualText(
          en: 'Non-invasive diagnosis of hidden leaks behind walls and under floors.',
          ar: 'تشخيص غير تدخلي للتسربات المخفية خلف الجدران.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Fixture Installation', ar: 'تركيب التجهيزات'),
        desc: BilingualText(
          en: 'Professional fitting of taps, showers, toilets, and sinks.',
          ar: 'تركيب احترافي للحنفيات والأحواض والمراحيض.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Drain Cleaning', ar: 'تنظيف المصارف'),
        desc: BilingualText(
          en: 'Clear blockages and restore full flow with professional-grade equipment.',
          ar: 'إزالة الانسدادات واستعادة التدفق الكامل.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '200 – 500 EGP', ar: '200 – 500 جنيه'),
        jobs: BilingualText(
          en: 'Washer replacements, minor leaks, and simple drain unblocking.',
          ar: 'استبدال الحلقات المطاطية والتسربات البسيطة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '500 – 1,000 EGP', ar: '500 – 1,000 جنيه'),
        jobs: BilingualText(
          en: 'Pipe replacements, full fixture installations, and drain clearing.',
          ar: 'استبدال الأنابيب وتركيب التجهيزات الكاملة.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Complex', ar: 'متقدم'),
        price: BilingualText(en: '1,000 – 2,000 EGP', ar: '1,000 – 2,000 جنيه'),
        jobs: BilingualText(
          en: 'Major re-piping, water heater replacement, and emergency callouts.',
          ar: 'إعادة التمديد الكاملة واستبدال سخانات المياه.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      ServiceFaq(
        question: BilingualText(en: 'How long does a plumbing job take?', ar: 'كم يستغرق عمل السباكة؟'),
        answer: BilingualText(
          en: 'Most standard jobs take 1–3 hours. Complex work like re-piping may take a full day.',
          ar: 'معظم الأعمال تستغرق 1–3 ساعات. الأعمال المعقدة قد تستغرق يوماً كاملاً.',
        ),
      ),
      _faqVerified,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Fixed a burst pipe within 2 hours of booking. Professional, clean, and honest about pricing."',
          ar: '"إصلاح أنبوب متفجر خلال ساعتين. محترف ونظيف وصادق في التسعير."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Great service. The technician was knowledgeable and resolved our leak quickly."',
          ar: '"خدمة رائعة. الفني كان على دراية وحل تسربنا بسرعة."',
        ),
      ),
    ],
  ),

  ServiceModel(
    id: 'electrical',
    icon: 'bolt',
    title: BilingualText(en: 'Electrical Services', ar: 'خدمات الكهرباء'),
    lead: BilingualText(
      en: 'Safe, licensed wiring, lighting installation, and precision electrical repairs by certified electricians.',
      ar: 'توصيلات كهربائية آمنة ومرخصة وتركيب الإضاءة وإصلاحات دقيقة من كهربائيين معتمدين.',
    ),
    priceBadge: BilingualText(en: 'avg. 300 – 3,000 EGP', ar: 'متوسط 300 – 3,000 جنيه'),
    heroImageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(en: 'Ready to book an electrician?', ar: 'جاهز لحجز كهربائي؟'),
    ctaSub: BilingualText(
      en: 'Browse our network of licensed electrical specialists.',
      ar: 'تصفح شبكتنا من الكهربائيين المرخصين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Wiring & Rewiring', ar: 'التوصيلات الكهربائية'),
        desc: BilingualText(
          en: 'Safe installation and replacement of household electrical circuits.',
          ar: 'تركيب وإعادة توصيل دوائر المنزل الكهربائية بأمان.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Lighting Installation', ar: 'تركيب الإضاءة'),
        desc: BilingualText(
          en: 'Ceiling lights, spotlights, chandeliers, and smart lighting setups.',
          ar: 'إضاءة السقف والبقع الضوئية والثريات وأنظمة الإضاءة الذكية.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Safety Inspection', ar: 'فحص السلامة'),
        desc: BilingualText(
          en: 'Full circuit inspection, breaker checks, and compliance reporting.',
          ar: 'فحص كامل للدوائر الكهربائية وتقرير المطابقة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Panel Upgrades', ar: 'ترقية لوحات التوزيع'),
        desc: BilingualText(
          en: 'Main distribution board upgrades and load balancing for modern homes.',
          ar: 'ترقية لوحات التوزيع الرئيسية وموازنة الأحمال.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '300 – 700 EGP', ar: '300 – 700 جنيه'),
        jobs: BilingualText(
          en: 'Outlet repairs, light fixture swaps, and simple switch replacements.',
          ar: 'إصلاح المقابس واستبدال تركيبات الإضاءة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '700 – 1,500 EGP', ar: '700 – 1,500 جنيه'),
        jobs: BilingualText(
          en: 'Lighting installation, circuit additions, and panel work.',
          ar: 'تركيب الإضاءة وإضافة الدوائر وأعمال اللوحة.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Complex', ar: 'متقدم'),
        price: BilingualText(en: '1,500 – 3,000 EGP', ar: '1,500 – 3,000 جنيه'),
        jobs: BilingualText(
          en: 'Full rewiring, panel upgrades, and smart home integration.',
          ar: 'إعادة التوصيل الكاملة وترقية اللوحات وتكامل المنزل الذكي.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      ServiceFaq(
        question: BilingualText(en: 'Are electricians licensed?', ar: 'هل الكهربائيون مرخصون؟'),
        answer: BilingualText(
          en: 'All our electricians hold valid trade licenses and complete safety training before joining the platform.',
          ar: 'جميع كهربائيونا يحملون رخص مهنية سارية ويجتازون تدريب السلامة.',
        ),
      ),
      _faqVerified,
      _faqPayment,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Rewired our entire apartment professionally. Neat work and on budget."',
          ar: '"إعادة توصيل شقتنا بالكامل باحترافية. عمل أنيق وفي حدود الميزانية."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Installed all our lighting fixtures in one visit. Highly recommend."',
          ar: '"تركيب جميع تركيبات الإضاءة في زيارة واحدة. أنصح به بشدة."',
        ),
      ),
    ],
  ),

  ServiceModel(
    id: 'ac-maintenance',
    icon: 'temp',
    title: BilingualText(en: 'A/C Maintenance & HVAC', ar: 'صيانة التكييف والتبريد'),
    lead: BilingualText(
      en: 'Professional air conditioning installation, servicing, and repair by certified HVAC technicians.',
      ar: 'تركيب وصيانة وإصلاح أجهزة التكييف من قبل فنيين مخصصين معتمدين.',
    ),
    priceBadge: BilingualText(en: 'avg. 400 – 2,500 EGP', ar: 'متوسط 400 – 2,500 جنيه'),
    heroImageUrl: 'https://images.unsplash.com/photo-1631545806609-5a1e3d9d5ff4?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(en: 'Ready to book AC service?', ar: 'جاهز لحجز صيانة تكييف؟'),
    ctaSub: BilingualText(
      en: 'Browse our certified HVAC specialists available today.',
      ar: 'تصفح متخصصي التكييف المعتمدين المتاحين اليوم.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'AC Installation', ar: 'تركيب التكييف'),
        desc: BilingualText(
          en: 'Full installation of split, window, and cassette AC units.',
          ar: 'تركيب كامل لوحدات التكييف المنشق والنافذة والكاسيت.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Annual Servicing', ar: 'الصيانة السنوية'),
        desc: BilingualText(
          en: 'Cleaning, gas refill checks, and performance optimization.',
          ar: 'تنظيف وفحص شحن الغاز وتحسين الأداء.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Fault Diagnosis & Repair', ar: 'تشخيص الأعطال وإصلاحها'),
        desc: BilingualText(
          en: 'Identifying and fixing cooling failures, leaks, and compressor issues.',
          ar: 'تحديد وإصلاح أعطال التبريد والتسربات ومشاكل الضاغط.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Duct Cleaning', ar: 'تنظيف المجاري الهوائية'),
        desc: BilingualText(
          en: 'Professional duct and filter cleaning for healthier air quality.',
          ar: 'تنظيف احترافي للمجاري والفلاتر لجودة هواء أفضل.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '400 – 800 EGP', ar: '400 – 800 جنيه'),
        jobs: BilingualText(
          en: 'Filter cleaning, gas top-up checks, and minor fault fixes.',
          ar: 'تنظيف الفلاتر وفحص شحن الغاز وإصلاح الأعطال البسيطة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '800 – 1,500 EGP', ar: '800 – 1,500 جنيه'),
        jobs: BilingualText(
          en: 'Full service, duct cleaning, and component replacement.',
          ar: 'صيانة كاملة وتنظيف المجاري واستبدال المكونات.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Complex', ar: 'متقدم'),
        price: BilingualText(en: '1,500 – 2,500 EGP', ar: '1,500 – 2,500 جنيه'),
        jobs: BilingualText(
          en: 'New AC installation, compressor replacement, and multi-unit setups.',
          ar: 'تركيب تكييف جديد واستبدال الضاغط وإعداد وحدات متعددة.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      ServiceFaq(
        question: BilingualText(en: 'How often should I service my AC?', ar: 'كم مرة يجب صيانة التكييف؟'),
        answer: BilingualText(
          en: 'We recommend servicing once a year before summer, with filter cleaning every 3 months.',
          ar: 'نوصي بالصيانة مرة سنوياً قبل الصيف مع تنظيف الفلاتر كل 3 أشهر.',
        ),
      ),
      _faqVerified,
      _faqPayment,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"AC was making noise and not cooling. Fixed same day. Excellent service."',
          ar: '"التكييف كان يصدر ضوضاء ولا يبرد. تم الإصلاح في نفس اليوم."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Full annual service done thoroughly. The technician explained everything."',
          ar: '"صيانة سنوية كاملة تمت بدقة. شرح الفني كل شيء."',
        ),
      ),
    ],
  ),

  ServiceModel(
    id: 'carpentry',
    icon: 'wrench',
    title: BilingualText(en: 'Carpentry Services', ar: 'خدمات النجارة'),
    lead: BilingualText(
      en: 'Skilled woodwork, furniture repair, and structural carpentry by experienced craftsmen.',
      ar: 'أعمال خشبية ماهرة وإصلاح الأثاث ونجارة هيكلية من قبل حرفيين ذوي خبرة.',
    ),
    priceBadge: BilingualText(en: 'avg. 200 – 2,000 EGP', ar: 'متوسط 200 – 2,000 جنيه'),
    heroImageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(en: 'Ready to book a carpenter?', ar: 'جاهز لحجز نجار؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified carpentry specialists.',
      ar: 'تصفح متخصصي النجارة المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Furniture Repair', ar: 'إصلاح الأثاث'),
        desc: BilingualText(
          en: 'Fix broken chairs, tables, cabinets, and wardrobe joints.',
          ar: 'إصلاح الكراسي والطاولات والخزائن والمفاصل المكسورة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Door & Window Work', ar: 'أعمال الأبواب والنوافذ'),
        desc: BilingualText(
          en: 'Fitting, adjustment, and repair of wooden doors and frames.',
          ar: 'تركيب وتعديل وإصلاح الأبواب الخشبية والإطارات.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Custom Woodwork', ar: 'الأعمال الخشبية المخصصة'),
        desc: BilingualText(
          en: 'Bespoke shelves, cabinets, and built-in storage solutions.',
          ar: 'رفوف وخزائن وحلول تخزين مدمجة مخصصة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Structural Fixes', ar: 'الإصلاحات الهيكلية'),
        desc: BilingualText(
          en: 'Load-bearing repairs and reinforcement of wooden structures.',
          ar: 'إصلاح وتعزيز الهياكل الخشبية الحاملة.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '200 – 500 EGP', ar: '200 – 500 جنيه'),
        jobs: BilingualText(
          en: 'Small furniture repairs, hinge replacements, and minor adjustments.',
          ar: 'إصلاح الأثاث الصغير واستبدال المفصلات.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '500 – 1,200 EGP', ar: '500 – 1,200 جنيه'),
        jobs: BilingualText(
          en: 'Door fitting, custom shelving, and medium furniture repairs.',
          ar: 'تركيب الأبواب والرفوف المخصصة وإصلاح الأثاث المتوسط.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Complex', ar: 'متقدم'),
        price: BilingualText(en: '1,200 – 2,000 EGP', ar: '1,200 – 2,000 جنيه'),
        jobs: BilingualText(
          en: 'Built-in wardrobes, kitchen cabinets, and structural woodwork.',
          ar: 'خزائن ملابس مدمجة وخزائن مطبخ وأعمال خشبية هيكلية.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      ServiceFaq(
        question: BilingualText(en: 'Do you supply the wood and materials?', ar: 'هل يوفرون الخشب والمواد؟'),
        answer: BilingualText(
          en: 'Technicians can source materials for you at cost, or work with materials you provide.',
          ar: 'يمكن للفنيين توفير المواد بالتكلفة أو العمل بمواد توفرها أنت.',
        ),
      ),
      _faqVerified,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Built custom wardrobes for two rooms. Excellent finish and on time."',
          ar: '"بنى خزائن ملابس مخصصة لغرفتين. تشطيب ممتاز وفي الوقت المحدد."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Fixed all our doors that were sticking in summer. Quick and clean."',
          ar: '"أصلح جميع أبوابنا التي كانت عالقة. سريع ونظيف."',
        ),
      ),
    ],
  ),

  ServiceModel(
    id: 'painting',
    icon: 'paint',
    title: BilingualText(en: 'Painting Services', ar: 'خدمات الدهانات'),
    lead: BilingualText(
      en: 'Interior and exterior painting, Venetian plaster, and decorative finishes by skilled painters.',
      ar: 'دهانات داخلية وخارجية وجص فينيسي وتشطيبات زخرفية من قبل دهانين ماهرين.',
    ),
    priceBadge: BilingualText(en: 'avg. 300 – 6,000 EGP', ar: 'متوسط 300 – 6,000 جنيه'),
    heroImageUrl: 'https://images.unsplash.com/photo-1562259929-b4e1fd3aef09?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(en: 'Ready to book a painter?', ar: 'جاهز لحجز دهان؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified painting specialists.',
      ar: 'تصفح متخصصي الدهانات المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Interior Painting', ar: 'دهان داخلي'),
        desc: BilingualText(
          en: 'Full room and apartment interior painting with premium finishes.',
          ar: 'دهان داخلي كامل للغرف والشقق بتشطيبات متميزة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Exterior Painting', ar: 'دهان خارجي'),
        desc: BilingualText(
          en: 'Weather-resistant exterior painting for villas and buildings.',
          ar: 'دهان خارجي مقاوم للطقس للفلل والمباني.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Venetian Plaster', ar: 'جص فينيسي'),
        desc: BilingualText(
          en: 'Luxury decorative plaster finishes for walls and ceilings.',
          ar: 'تشطيبات جص زخرفية فاخرة للجدران والأسقف.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Surface Preparation', ar: 'تحضير الأسطح'),
        desc: BilingualText(
          en: 'Professional sanding, filling, and priming before painting.',
          ar: 'صنفرة واملاء وتأسيس احترافي قبل الدهان.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '300 – 800 EGP', ar: '300 – 800 جنيه'),
        jobs: BilingualText(
          en: 'Single room painting with standard emulsion.',
          ar: 'دهان غرفة واحدة بطلاء قياسي.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '2,000 – 6,000 EGP', ar: '2,000 – 6,000 جنيه'),
        jobs: BilingualText(
          en: 'Full apartment painting with premium paint and surface prep.',
          ar: 'دهان شقة كاملة بطلاء متميز وتحضير أسطح.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Decorative', ar: 'زخرفي'),
        price: BilingualText(en: '500 – 2,000 EGP', ar: '500 – 2,000 جنيه'),
        jobs: BilingualText(
          en: 'Venetian plaster, textured finishes, and specialty coatings.',
          ar: 'جص فينيسي وتشطيبات مزخرفة وطلاءات متخصصة.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      ServiceFaq(
        question: BilingualText(en: 'Do you provide the paint?', ar: 'هل يوفرون الطلاء؟'),
        answer: BilingualText(
          en: 'Yes, painters can supply premium paint brands at cost, or use paint you provide.',
          ar: 'نعم، يمكن للدهانين توفير ماركات طلاء متميزة بالتكلفة أو استخدام طلاء تقدمه أنت.',
        ),
      ),
      _faqVerified,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Painted our 3-bedroom apartment in 3 days. Clean, precise, and professional."',
          ar: '"دهان شقتنا ذات 3 غرف في 3 أيام. نظيف ودقيق واحترافي."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 5,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Amazing Venetian plaster finish on our living room wall. Highly recommend."',
          ar: '"تشطيب جص فينيسي رائع على جدار غرفة المعيشة. أنصح به بشدة."',
        ),
      ),
    ],
  ),
];
