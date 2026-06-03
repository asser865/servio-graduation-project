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
    priceBadge:
        BilingualText(en: 'avg. 200 – 2,000 EGP', ar: 'متوسط 200 – 2,000 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=800&q=80',
    ctaTitle:
        BilingualText(en: 'Ready to book a plumber?', ar: 'جاهز لحجز سباك؟'),
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
        question: BilingualText(
            en: 'How long does a plumbing job take?',
            ar: 'كم يستغرق عمل السباكة؟'),
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
    priceBadge:
        BilingualText(en: 'avg. 300 – 3,000 EGP', ar: 'متوسط 300 – 3,000 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book an electrician?', ar: 'جاهز لحجز كهربائي؟'),
    ctaSub: BilingualText(
      en: 'Browse our network of licensed electrical specialists.',
      ar: 'تصفح شبكتنا من الكهربائيين المرخصين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title:
            BilingualText(en: 'Wiring & Rewiring', ar: 'التوصيلات الكهربائية'),
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
        question: BilingualText(
            en: 'Are electricians licensed?', ar: 'هل الكهربائيون مرخصون؟'),
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
    title: BilingualText(
        en: 'A/C Maintenance & HVAC', ar: 'صيانة التكييف والتبريد'),
    lead: BilingualText(
      en: 'Professional air conditioning installation, servicing, and repair by certified HVAC technicians.',
      ar: 'تركيب وصيانة وإصلاح أجهزة التكييف من قبل فنيين مخصصين معتمدين.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 400 – 2,500 EGP', ar: 'متوسط 400 – 2,500 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1621905252507-b354bc25edac?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book AC service?', ar: 'جاهز لحجز صيانة تكييف؟'),
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
        title: BilingualText(
            en: 'Fault Diagnosis & Repair', ar: 'تشخيص الأعطال وإصلاحها'),
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
        question: BilingualText(
            en: 'How often should I service my AC?',
            ar: 'كم مرة يجب صيانة التكييف؟'),
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
    priceBadge:
        BilingualText(en: 'avg. 200 – 2,000 EGP', ar: 'متوسط 200 – 2,000 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=800&q=80',
    ctaTitle:
        BilingualText(en: 'Ready to book a carpenter?', ar: 'جاهز لحجز نجار؟'),
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
        title: BilingualText(
            en: 'Door & Window Work', ar: 'أعمال الأبواب والنوافذ'),
        desc: BilingualText(
          en: 'Fitting, adjustment, and repair of wooden doors and frames.',
          ar: 'تركيب وتعديل وإصلاح الأبواب الخشبية والإطارات.',
        ),
      ),
      ServiceIncluded(
        title:
            BilingualText(en: 'Custom Woodwork', ar: 'الأعمال الخشبية المخصصة'),
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
        question: BilingualText(
            en: 'Do you supply the wood and materials?',
            ar: 'هل يوفرون الخشب والمواد؟'),
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
    priceBadge:
        BilingualText(en: 'avg. 300 – 6,000 EGP', ar: 'متوسط 300 – 6,000 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1562259929-b4e1fd3aef09?auto=format&fit=crop&w=800&q=80',
    ctaTitle:
        BilingualText(en: 'Ready to book a painter?', ar: 'جاهز لحجز دهان؟'),
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
        question: BilingualText(
            en: 'Do you provide the paint?', ar: 'هل يوفرون الطلاء؟'),
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
  ServiceModel(
    id: 'appliance',
    icon: 'appliance',
    title: BilingualText(en: 'Appliance Repair', ar: 'إصلاح الأجهزة المنزلية'),
    lead: BilingualText(
      en: 'Fast, reliable repair of washing machines, fridges, dishwashers, and ovens by certified technicians.',
      ar: 'إصلاح سريع وموثوق للغسالات والثلاجات وغسالات الأطباق والأفران من قبل فنيين معتمدين.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 130 – 900 EGP', ar: 'متوسط 130 – 900 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1581092335397-9583eb92d232?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a technician?', ar: 'جاهز لحجز فني؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified appliance repair specialists.',
      ar: 'تصفح متخصصي إصلاح الأجهزة المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Washing Machine Repair', ar: 'إصلاح الغسالات'),
        desc: BilingualText(
          en: 'Diagnose and fix faults, drainage issues, and spin failures.',
          ar: 'تشخيص وإصلاح الأعطال ومشاكل التصريف وأعطال العصر.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Refrigerator Repair', ar: 'إصلاح الثلاجات'),
        desc: BilingualText(
          en: 'Repair cooling problems, gas leaks, and compressor faults.',
          ar: 'إصلاح مشاكل التبريد وتسربات الغاز وأعطال الضاغط.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Dishwasher Repair', ar: 'إصلاح غسالات الأطباق'),
        desc: BilingualText(
          en: 'Fix leaks, draining issues, and electrical faults.',
          ar: 'إصلاح التسربات ومشاكل التصريف والأعطال الكهربائية.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Oven & Stove Repair', ar: 'إصلاح الأفران والمواقد'),
        desc: BilingualText(
          en: 'Service gas and electric ovens, hobs, and cooking ranges.',
          ar: 'صيانة الأفران الغازية والكهربائية والمواقد.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '130 – 250 EGP', ar: '130 – 250 جنيه'),
        jobs: BilingualText(
          en: 'Diagnosis, minor part swaps, and simple fault fixes.',
          ar: 'التشخيص واستبدال القطع البسيطة وإصلاح الأعطال السهلة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '250 – 500 EGP', ar: '250 – 500 جنيه'),
        jobs: BilingualText(
          en: 'Component replacement, motor, and control board repairs.',
          ar: 'استبدال المكونات وإصلاح المحركات ولوحات التحكم.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Complex', ar: 'متقدم'),
        price: BilingualText(en: '500 – 900 EGP', ar: '500 – 900 جنيه'),
        jobs: BilingualText(
          en: 'Compressor replacement and major appliance overhauls.',
          ar: 'استبدال الضاغط والإصلاح الشامل للأجهزة الكبيرة.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Fixed our washing machine drainage same day. Honest pricing."',
          ar: '"أصلح تصريف غسالتنا في نفس اليوم. تسعير صادق."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Refrigerator cooling restored quickly. Very professional."',
          ar: '"استعادة تبريد الثلاجة بسرعة. محترف جداً."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'handyman',
    icon: 'install',
    title: BilingualText(en: 'Handyman Services', ar: 'خدمات الصيانة العامة'),
    lead: BilingualText(
      en: 'Reliable help for mounting, installation, lock repair, and everyday home fixes.',
      ar: 'مساعدة موثوقة للتركيب والتعليق وإصلاح الأقفال والإصلاحات المنزلية اليومية.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 70 – 600 EGP', ar: 'متوسط 70 – 600 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a handyman?', ar: 'جاهز لحجز فني صيانة؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified handyman specialists.',
      ar: 'تصفح متخصصي الصيانة المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'TV & Picture Mounting', ar: 'تعليق التلفاز والصور'),
        desc: BilingualText(
          en: 'Wall-mount TVs, mirrors, and picture frames with precision.',
          ar: 'تعليق التلفاز والمرايا والصور على الحائط بدقة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Shelf & Storage Installation', ar: 'تركيب الرفوف والتخزين'),
        desc: BilingualText(
          en: 'Install floating shelves, racks, and storage units.',
          ar: 'تركيب الرفوف المعلقة والأرفف ووحدات التخزين.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Door Lock & Key Repair', ar: 'إصلاح الأقفال والمفاتيح'),
        desc: BilingualText(
          en: 'Replace door locks, deadbolts, and repair jammed mechanisms.',
          ar: 'استبدال أقفال الأبواب والمزاليج وإصلاح الآليات العالقة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'General Repairs', ar: 'إصلاحات عامة'),
        desc: BilingualText(
          en: 'Caulking, patching, tightening, and small fix-it jobs.',
          ar: 'الحشو والترقيع والإحكام والإصلاحات الصغيرة.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '70 – 150 EGP', ar: '70 – 150 جنيه'),
        jobs: BilingualText(
          en: 'Single mounting, lock swap, or minor fix.',
          ar: 'تعليق واحد أو استبدال قفل أو إصلاح بسيط.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '150 – 300 EGP', ar: '150 – 300 جنيه'),
        jobs: BilingualText(
          en: 'Multiple installations and combined small jobs.',
          ar: 'تركيبات متعددة وأعمال صغيرة مجمعة.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Half-day', ar: 'نصف يوم'),
        price: BilingualText(en: '300 – 600 EGP', ar: '300 – 600 جنيه'),
        jobs: BilingualText(
          en: 'A full punch-list of repairs around the home.',
          ar: 'قائمة كاملة من الإصلاحات في جميع أنحاء المنزل.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Mounted three TVs and fixed two locks in one visit. Great value."',
          ar: '"علّق ثلاثة تلفزيونات وأصلح قفلين في زيارة واحدة. قيمة رائعة."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Sorted out a long list of small repairs. Punctual and tidy."',
          ar: '"أنجز قائمة طويلة من الإصلاحات الصغيرة. ملتزم بالمواعيد ومرتب."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'flooring',
    icon: 'floor',
    title: BilingualText(en: 'Flooring Services', ar: 'خدمات الأرضيات'),
    lead: BilingualText(
      en: 'Professional tiling, hardwood, and vinyl flooring installation with precise, durable finishes.',
      ar: 'تركيب احترافي للبلاط والخشب والأرضيات الفينيل بتشطيبات دقيقة ومتينة.',
    ),
    priceBadge: BilingualText(
        en: 'avg. 80 – 300 EGP/m²', ar: 'متوسط 80 – 300 جنيه/م²'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1581858726788-75bc0f6a952d?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a flooring pro?', ar: 'جاهز لحجز فني أرضيات؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified flooring specialists.',
      ar: 'تصفح متخصصي الأرضيات المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Ceramic & Tile Installation', ar: 'تركيب السيراميك والبلاط'),
        desc: BilingualText(
          en: 'Lay ceramic, porcelain, and mosaic floor and wall tiles.',
          ar: 'تركيب بلاط السيراميك والبورسلين والموزاييك للأرضيات والجدران.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Hardwood & Parquet', ar: 'الخشب والباركيه'),
        desc: BilingualText(
          en: 'Install and refinish solid and engineered hardwood floors.',
          ar: 'تركيب وتجديد الأرضيات الخشبية الصلبة والمهندسة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Vinyl & Laminate', ar: 'الفينيل واللامينيت'),
        desc: BilingualText(
          en: 'Install click-lock vinyl plank and laminate flooring.',
          ar: 'تركيب ألواح الفينيل واللامينيت ذات التعشيق.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Surface Preparation', ar: 'تجهيز الأسطح'),
        desc: BilingualText(
          en: 'Level and prep the subfloor before laying for a lasting finish.',
          ar: 'تسوية وتجهيز الأرضية التحتية قبل التركيب لتشطيب دائم.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Vinyl / Laminate', ar: 'فينيل / لامينيت'),
        price: BilingualText(en: '80 – 120 EGP/m²', ar: '80 – 120 جنيه/م²'),
        jobs: BilingualText(
          en: 'Click-lock planks over a prepared subfloor.',
          ar: 'ألواح تعشيق فوق أرضية مجهزة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Ceramic / Tile', ar: 'سيراميك / بلاط'),
        price: BilingualText(en: '120 – 180 EGP/m²', ar: '120 – 180 جنيه/م²'),
        jobs: BilingualText(
          en: 'Full tiling with grouting and edge finishing.',
          ar: 'تبليط كامل مع الجير وتشطيب الحواف.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Hardwood', ar: 'خشب صلب'),
        price: BilingualText(en: '180 – 300 EGP/m²', ar: '180 – 300 جنيه/م²'),
        jobs: BilingualText(
          en: 'Solid and engineered hardwood with refinishing.',
          ar: 'خشب صلب ومهندس مع إعادة التشطيب.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Tiled our whole kitchen floor flawlessly. Perfectly level."',
          ar: '"بلّط أرضية مطبخنا بالكامل بإتقان. مستوية تماماً."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 5,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Beautiful parquet installation. Clean and on schedule."',
          ar: '"تركيب باركيه جميل. نظيف وفي الموعد."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'cleaning',
    icon: 'clean',
    title: BilingualText(en: 'Cleaning Services', ar: 'خدمات التنظيف'),
    lead: BilingualText(
      en: 'Thorough home cleaning — deep cleans, regular upkeep, and post-construction clean-ups.',
      ar: 'تنظيف منزلي شامل — تنظيف عميق وصيانة دورية وتنظيف ما بعد البناء.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 150 – 900 EGP', ar: 'متوسط 150 – 900 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a cleaner?', ar: 'جاهز لحجز عامل تنظيف؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified cleaning specialists.',
      ar: 'تصفح متخصصي التنظيف المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Home Deep Cleaning', ar: 'تنظيف منزلي عميق'),
        desc: BilingualText(
          en: 'Full-home sanitization including appliances and cabinets.',
          ar: 'تعقيم كامل للمنزل بما في ذلك الأجهزة والخزائن.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Regular Home Cleaning', ar: 'تنظيف منزلي دوري'),
        desc: BilingualText(
          en: 'Recurring dusting, mopping, and vacuuming service.',
          ar: 'خدمة دورية لإزالة الغبار والمسح والكنس.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Post-Construction Cleaning', ar: 'تنظيف ما بعد البناء'),
        desc: BilingualText(
          en: 'Remove construction dust and debris after renovation work.',
          ar: 'إزالة غبار البناء والمخلفات بعد أعمال التجديد.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Move-In / Move-Out Cleaning', ar: 'تنظيف الانتقال'),
        desc: BilingualText(
          en: 'Complete clean for vacant properties before or after moving.',
          ar: 'تنظيف كامل للعقارات الفارغة قبل أو بعد الانتقال.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Regular', ar: 'دوري'),
        price: BilingualText(en: '150 – 300 EGP', ar: '150 – 300 جنيه'),
        jobs: BilingualText(
          en: 'Standard dusting, mopping, and vacuuming visit.',
          ar: 'زيارة قياسية لإزالة الغبار والمسح والكنس.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Deep Clean', ar: 'تنظيف عميق'),
        price: BilingualText(en: '350 – 500 EGP', ar: '350 – 500 جنيه'),
        jobs: BilingualText(
          en: 'Full sanitization including appliances and cabinets.',
          ar: 'تعقيم كامل بما في ذلك الأجهزة والخزائن.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Move / Post-Build', ar: 'انتقال / ما بعد البناء'),
        price: BilingualText(en: '400 – 900 EGP', ar: '400 – 900 جنيه'),
        jobs: BilingualText(
          en: 'Vacant property and post-construction deep cleans.',
          ar: 'تنظيف عميق للعقارات الفارغة وما بعد البناء.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Deep cleaned our apartment before moving in. Spotless result."',
          ar: '"تنظيف عميق لشقتنا قبل الانتقال. نتيجة لا تشوبها شائبة."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 5,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Reliable weekly cleaning. Always thorough and on time."',
          ar: '"تنظيف أسبوعي موثوق. دائماً شامل وفي الموعد."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'pest-control',
    icon: 'pest',
    title: BilingualText(en: 'Pest Control', ar: 'مكافحة الآفات'),
    lead: BilingualText(
      en: 'Safe, effective treatment for insects, termites, and rodents with lasting prevention.',
      ar: 'معالجة آمنة وفعّالة للحشرات والنمل الأبيض والقوارض مع وقاية دائمة.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 200 – 900 EGP', ar: 'متوسط 200 – 900 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1632935190508-b2dc3b9c2e8a?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book pest control?', ar: 'جاهز لحجز مكافحة آفات؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified pest control specialists.',
      ar: 'تصفح متخصصي مكافحة الآفات المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Ant & Cockroach Treatment', ar: 'مكافحة النمل والصراصير'),
        desc: BilingualText(
          en: 'Targeted treatment to eliminate common household insects.',
          ar: 'معالجة موجهة للقضاء على الحشرات المنزلية الشائعة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Termite Treatment', ar: 'مكافحة النمل الأبيض'),
        desc: BilingualText(
          en: 'Chemical barrier or baiting system for termite elimination.',
          ar: 'حاجز كيميائي أو نظام طُعم للقضاء على النمل الأبيض.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Rodent Control', ar: 'مكافحة القوارض'),
        desc: BilingualText(
          en: 'Set traps and seal entry points to eliminate mice and rats.',
          ar: 'نصب المصائد وسد نقاط الدخول للقضاء على الفئران.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Inspection & Prevention', ar: 'الفحص والوقاية'),
        desc: BilingualText(
          en: 'Identify risks and apply measures to prevent re-infestation.',
          ar: 'تحديد المخاطر وتطبيق إجراءات لمنع عودة الإصابة.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Insects', ar: 'حشرات'),
        price: BilingualText(en: '200 – 350 EGP', ar: '200 – 350 جنيه'),
        jobs: BilingualText(
          en: 'Ant, cockroach, and common insect treatment.',
          ar: 'معالجة النمل والصراصير والحشرات الشائعة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Rodents', ar: 'قوارض'),
        price: BilingualText(en: '250 – 500 EGP', ar: '250 – 500 جنيه'),
        jobs: BilingualText(
          en: 'Trapping, baiting, and entry-point sealing.',
          ar: 'نصب المصائد والطُعم وسد نقاط الدخول.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Termite', ar: 'نمل أبيض'),
        price: BilingualText(en: '450 – 900 EGP', ar: '450 – 900 جنيه'),
        jobs: BilingualText(
          en: 'Chemical barrier and baiting system installation.',
          ar: 'تركيب الحاجز الكيميائي ونظام الطُعم.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Cleared a stubborn cockroach problem in one visit. No smell, safe for kids."',
          ar: '"قضى على مشكلة صراصير عنيدة في زيارة واحدة. بلا رائحة وآمن للأطفال."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Termite treatment with a clear prevention plan. Reassuring service."',
          ar: '"معالجة النمل الأبيض مع خطة وقاية واضحة. خدمة مطمئنة."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'roofing',
    icon: 'roof',
    title: BilingualText(en: 'Roofing Services', ar: 'خدمات الأسطح'),
    lead: BilingualText(
      en: 'Leak repair, tile and shingle replacement, and waterproofing by experienced roofers.',
      ar: 'إصلاح التسربات واستبدال البلاط والقرميد والعزل المائي من قبل فنيين ذوي خبرة.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 300 – 1,500 EGP', ar: 'متوسط 300 – 1,500 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1632759145351-1d592919f522?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a roofer?', ar: 'جاهز لحجز فني أسطح؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified roofing specialists.',
      ar: 'تصفح متخصصي الأسطح المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Roof Leak Repair', ar: 'إصلاح تسرب الأسطح'),
        desc: BilingualText(
          en: 'Locate and seal roof leaks with waterproofing compounds.',
          ar: 'تحديد وإغلاق تسربات الأسطح بمواد العزل المائي.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Tile & Shingle Replacement', ar: 'استبدال البلاط والقرميد'),
        desc: BilingualText(
          en: 'Replace cracked or missing roof tiles and shingles.',
          ar: 'استبدال بلاط وقرميد الأسطح المكسور أو المفقود.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Waterproofing', ar: 'العزل المائي'),
        desc: BilingualText(
          en: 'Apply protective membranes and coatings against water damage.',
          ar: 'تطبيق أغشية وطبقات واقية ضد أضرار المياه.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Roof Inspection', ar: 'فحص الأسطح'),
        desc: BilingualText(
          en: 'Assess condition and flag issues before they worsen.',
          ar: 'تقييم الحالة ورصد المشاكل قبل تفاقمها.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Leak Repair', ar: 'إصلاح تسرب'),
        price: BilingualText(en: '300 – 600 EGP', ar: '300 – 600 جنيه'),
        jobs: BilingualText(
          en: 'Locate and seal individual roof leaks.',
          ar: 'تحديد وإغلاق تسربات الأسطح الفردية.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Tile Replacement', ar: 'استبدال البلاط'),
        price: BilingualText(en: '25 – 40 EGP/m²', ar: '25 – 40 جنيه/م²'),
        jobs: BilingualText(
          en: 'Replace cracked or missing tiles and shingles.',
          ar: 'استبدال البلاط والقرميد المكسور أو المفقود.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Waterproofing', ar: 'عزل مائي'),
        price: BilingualText(en: '600 – 1,500 EGP', ar: '600 – 1,500 جنيه'),
        jobs: BilingualText(
          en: 'Full membrane and protective coating application.',
          ar: 'تطبيق كامل للأغشية والطبقات الواقية.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Found and sealed a leak that two others missed. No more damp ceiling."',
          ar: '"وجد وأغلق تسرباً فشل آخران في إيجاده. لا مزيد من السقف الرطب."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Replaced broken tiles and waterproofed the roof. Solid work."',
          ar: '"استبدل البلاط المكسور وعزل السطح. عمل متين."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'drywall',
    icon: 'wrench',
    title: BilingualText(en: 'Drywall Services', ar: 'خدمات الجبس'),
    lead: BilingualText(
      en: 'Partition installation, patching, and seamless finishing with gypsum board.',
      ar: 'تركيب القواطع والترقيع والتشطيب السلس بألواح الجبس.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 60 – 800 EGP', ar: 'متوسط 60 – 800 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1607400201889-565b1ee75f8e?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a drywall pro?', ar: 'جاهز لحجز فني جبس؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified drywall specialists.',
      ar: 'تصفح متخصصي الجبس المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Drywall Installation', ar: 'تركيب الجبس'),
        desc: BilingualText(
          en: 'Install gypsum board partitions, ceilings, and wall panels.',
          ar: 'تركيب قواطع وأسقف وألواح جدران من الجبس.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Patching & Repair', ar: 'الترقيع والإصلاح'),
        desc: BilingualText(
          en: 'Fill holes and cracks, then sand smooth for a seamless finish.',
          ar: 'ملء الثقوب والشقوق ثم الصنفرة للحصول على تشطيب سلس.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Taping & Finishing', ar: 'التلصيق والتشطيب'),
        desc: BilingualText(
          en: 'Seamless joint taping, corner beads, and smooth coats.',
          ar: 'تلصيق المفاصل بسلاسة وزوايا وطبقات ناعمة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Priming Prep', ar: 'تجهيز التأسيس'),
        desc: BilingualText(
          en: 'Prepare and prime surfaces ready for paint.',
          ar: 'تجهيز وتأسيس الأسطح جاهزة للدهان.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Patch Repair', ar: 'إصلاح ترقيع'),
        price: BilingualText(en: '60 – 200 EGP', ar: '60 – 200 جنيه'),
        jobs: BilingualText(
          en: 'Fill holes and cracks with a smooth finish.',
          ar: 'ملء الثقوب والشقوق بتشطيب ناعم.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Installation', ar: 'تركيب'),
        price: BilingualText(en: '80 – 120 EGP/m²', ar: '80 – 120 جنيه/م²'),
        jobs: BilingualText(
          en: 'Partition and ceiling board installation.',
          ar: 'تركيب قواطع وألواح أسقف.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Full Room', ar: 'غرفة كاملة'),
        price: BilingualText(en: '300 – 800 EGP', ar: '300 – 800 جنيه'),
        jobs: BilingualText(
          en: 'Complete room partitioning, taping, and finishing.',
          ar: 'تقسيم وتلصيق وتشطيب غرفة كاملة.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Built a clean partition wall and finished it ready for paint. Great work."',
          ar: '"بنى جدار قاطع نظيف وشطّبه جاهزاً للدهان. عمل رائع."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Patched several cracks invisibly. You can\'t tell where they were."',
          ar: '"رقّع عدة شقوق بشكل غير مرئي. لا يمكنك معرفة مكانها."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'renovation',
    icon: 'reno',
    title: BilingualText(en: 'Renovation Services', ar: 'خدمات التجديد'),
    lead: BilingualText(
      en: 'Complete room, kitchen, and bathroom remodels — flooring, walls, fixtures, and finishing.',
      ar: 'تجديد كامل للغرف والمطابخ والحمامات — أرضيات وجدران وتجهيزات وتشطيبات.',
    ),
    priceBadge: BilingualText(
        en: 'avg. 500 – 600 EGP/m²', ar: 'متوسط 500 – 600 جنيه/م²'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1581094794329-c8112a89af12?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to start renovating?', ar: 'جاهز لبدء التجديد؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified renovation specialists.',
      ar: 'تصفح متخصصي التجديد المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Room Renovation', ar: 'تجديد الغرف'),
        desc: BilingualText(
          en: 'Complete room renovation — flooring, walls, and finishing.',
          ar: 'تجديد كامل للغرفة — أرضيات وجدران وتشطيب.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Kitchen Renovation', ar: 'تجديد المطابخ'),
        desc: BilingualText(
          en: 'Full kitchen remodel including cabinets, countertops, and tiling.',
          ar: 'تجديد كامل للمطبخ يشمل الخزائن والأسطح والتبليط.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Bathroom Renovation', ar: 'تجديد الحمامات'),
        desc: BilingualText(
          en: 'Renovate bathrooms with new tiles, fixtures, and waterproofing.',
          ar: 'تجديد الحمامات ببلاط وتجهيزات جديدة وعزل مائي.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Finishing Work', ar: 'أعمال التشطيب'),
        desc: BilingualText(
          en: 'Final detailing, trim, and touch-ups for a polished result.',
          ar: 'التفاصيل النهائية والحواف واللمسات لنتيجة متقنة.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Room', ar: 'غرفة'),
        price: BilingualText(en: '500 EGP/m²', ar: '500 جنيه/م²'),
        jobs: BilingualText(
          en: 'Flooring, walls, and finishing for a single room.',
          ar: 'أرضيات وجدران وتشطيب لغرفة واحدة.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Bathroom', ar: 'حمام'),
        price: BilingualText(en: '550 EGP/m²', ar: '550 جنيه/م²'),
        jobs: BilingualText(
          en: 'New tiles, fixtures, and full waterproofing.',
          ar: 'بلاط وتجهيزات جديدة وعزل مائي كامل.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Kitchen', ar: 'مطبخ'),
        price: BilingualText(en: '600 EGP/m²', ar: '600 جنيه/م²'),
        jobs: BilingualText(
          en: 'Cabinets, countertops, tiling, and finishing.',
          ar: 'خزائن وأسطح وتبليط وتشطيب.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Remodeled our kitchen end to end. Stunning result, on budget."',
          ar: '"جدد مطبخنا من البداية للنهاية. نتيجة مذهلة وفي حدود الميزانية."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 5,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Full bathroom renovation done in a week. Excellent waterproofing."',
          ar: '"تجديد كامل للحمام في أسبوع. عزل مائي ممتاز."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'landscaping',
    icon: 'garden',
    title: BilingualText(en: 'Landscaping Services', ar: 'خدمات تنسيق الحدائق'),
    lead: BilingualText(
      en: 'Garden maintenance, lawn care, planting, and irrigation by green-thumbed pros.',
      ar: 'صيانة الحدائق والعناية بالعشب والزراعة والري من قبل محترفين.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 100 – 1,200 EGP', ar: 'متوسط 100 – 1,200 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1558904541-efa843a96f01?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book a gardener?', ar: 'جاهز لحجز بستاني؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified landscaping specialists.',
      ar: 'تصفح متخصصي تنسيق الحدائق المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Garden Maintenance', ar: 'صيانة الحدائق'),
        desc: BilingualText(
          en: 'Trim hedges, weed flower beds, and maintain garden health.',
          ar: 'تقليم الأسيجة وإزالة الأعشاب والحفاظ على صحة الحديقة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Lawn Care & Mowing', ar: 'العناية بالعشب والجز'),
        desc: BilingualText(
          en: 'Mow, edge, and fertilize lawns for healthy growth.',
          ar: 'جز وتشذيب وتسميد العشب لنمو صحي.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Planting & Design', ar: 'الزراعة والتصميم'),
        desc: BilingualText(
          en: 'Plant selection and flower-bed layout for your space.',
          ar: 'اختيار النباتات وتخطيط أحواض الزهور لمساحتك.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Irrigation Setup', ar: 'تركيب الري'),
        desc: BilingualText(
          en: 'Install and adjust watering and sprinkler systems.',
          ar: 'تركيب وضبط أنظمة الري والرشاشات.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Lawn Care', ar: 'عناية بالعشب'),
        price: BilingualText(en: '100 – 250 EGP', ar: '100 – 250 جنيه'),
        jobs: BilingualText(
          en: 'Mowing, edging, and basic upkeep visit.',
          ar: 'جز وتشذيب وزيارة صيانة أساسية.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Maintenance', ar: 'صيانة'),
        price: BilingualText(en: '250 – 500 EGP', ar: '250 – 500 جنيه'),
        jobs: BilingualText(
          en: 'Full garden maintenance and planting.',
          ar: 'صيانة كاملة للحديقة وزراعة.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Design & Irrigation', ar: 'تصميم وري'),
        price: BilingualText(en: '500 – 1,200 EGP', ar: '500 – 1,200 جنيه'),
        jobs: BilingualText(
          en: 'Garden redesign and irrigation system setup.',
          ar: 'إعادة تصميم الحديقة وتركيب نظام الري.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Transformed our neglected garden into a green retreat. Wonderful work."',
          ar: '"حوّل حديقتنا المهملة إلى ملاذ أخضر. عمل رائع."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Set up irrigation and the lawn has never looked better."',
          ar: '"ركّب نظام الري ولم يبدُ العشب أفضل من ذلك قط."',
        ),
      ),
    ],
  ),
  ServiceModel(
    id: 'installation',
    icon: 'install',
    title: BilingualText(en: 'Installation Services', ar: 'خدمات التركيب'),
    lead: BilingualText(
      en: 'Precise fitting of curtains, blinds, water filters, and home fixtures.',
      ar: 'تركيب دقيق للستائر والمظلات وفلاتر المياه وتجهيزات المنزل.',
    ),
    priceBadge:
        BilingualText(en: 'avg. 80 – 600 EGP', ar: 'متوسط 80 – 600 جنيه'),
    heroImageUrl:
        'https://images.unsplash.com/photo-1556909212-d5b604d0c90d?auto=format&fit=crop&w=800&q=80',
    ctaTitle: BilingualText(
        en: 'Ready to book an installer?', ar: 'جاهز لحجز فني تركيب؟'),
    ctaSub: BilingualText(
      en: 'Browse our verified installation specialists.',
      ar: 'تصفح متخصصي التركيب المعتمدين.',
    ),
    included: <ServiceIncluded>[
      ServiceIncluded(
        title: BilingualText(en: 'Curtain & Blind Installation', ar: 'تركيب الستائر والمظلات'),
        desc: BilingualText(
          en: 'Fit curtain rods, tracks, and blinds with precision.',
          ar: 'تركيب قضبان ومسارات الستائر والمظلات بدقة.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Water Filter Installation', ar: 'تركيب فلاتر المياه'),
        desc: BilingualText(
          en: 'Install under-sink or whole-house water filtration systems.',
          ar: 'تركيب أنظمة ترشيح المياه تحت الحوض أو للمنزل بالكامل.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Appliance Fitting', ar: 'تركيب الأجهزة'),
        desc: BilingualText(
          en: 'Connect and secure new appliances safely.',
          ar: 'توصيل وتثبيت الأجهزة الجديدة بأمان.',
        ),
      ),
      ServiceIncluded(
        title: BilingualText(en: 'Fixture Mounting', ar: 'تثبيت التجهيزات'),
        desc: BilingualText(
          en: 'Mount fittings precisely, level, and secure.',
          ar: 'تثبيت التجهيزات بدقة واستواء وإحكام.',
        ),
      ),
    ],
    pricing: <ServicePricingTier>[
      ServicePricingTier(
        tier: BilingualText(en: 'Basic', ar: 'أساسي'),
        price: BilingualText(en: '80 – 150 EGP', ar: '80 – 150 جنيه'),
        jobs: BilingualText(
          en: 'Single curtain, blind, or fixture fitting.',
          ar: 'تركيب ستارة أو مظلة أو تجهيز واحد.',
        ),
      ),
      ServicePricingTier(
        featured: true,
        tier: BilingualText(en: 'Standard', ar: 'معياري'),
        price: BilingualText(en: '150 – 300 EGP', ar: '150 – 300 جنيه'),
        jobs: BilingualText(
          en: 'Water filter and multiple fixture installations.',
          ar: 'تركيب فلتر مياه وتجهيزات متعددة.',
        ),
      ),
      ServicePricingTier(
        tier: BilingualText(en: 'Multi-room', ar: 'متعدد الغرف'),
        price: BilingualText(en: '300 – 600 EGP', ar: '300 – 600 جنيه'),
        jobs: BilingualText(
          en: 'Whole-home curtains, blinds, and fittings.',
          ar: 'ستائر ومظلات وتجهيزات للمنزل بالكامل.',
        ),
      ),
    ],
    faqs: <ServiceFaq>[
      _faqVerified,
      _faqPayment,
      _faqGuarantee,
    ],
    reviews: <ServiceReview>[
      ServiceReview(
        initials: 'AY',
        stars: 5,
        name: BilingualText(en: 'Ahmed Yasser', ar: 'أحمد ياسر'),
        quote: BilingualText(
          en: '"Installed curtains across the whole apartment in one visit. Neat and fast."',
          ar: '"ركّب الستائر في الشقة بالكامل في زيارة واحدة. أنيق وسريع."',
        ),
      ),
      ServiceReview(
        initials: 'SM',
        stars: 4,
        name: BilingualText(en: 'Sara Mohamed', ar: 'سارة محمد'),
        quote: BilingualText(
          en: '"Fitted an under-sink water filter cleanly. Works perfectly."',
          ar: '"ركّب فلتر مياه تحت الحوض بنظافة. يعمل بشكل مثالي."',
        ),
      ),
    ],
  ),
];
