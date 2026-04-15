import 'bilingual_text.dart';

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.title,
    required this.lead,
    required this.priceBadge,
    required this.icon,
    required this.heroImageUrl,
    required this.included,
    required this.pricing,
    required this.faqs,
    required this.reviews,
    required this.ctaTitle,
    required this.ctaSub,
  });

  final String id;
  final BilingualText title;
  final BilingualText lead;
  final BilingualText priceBadge;
  final String icon; // icon name key
  final String heroImageUrl;
  final List<ServiceIncluded> included;
  final List<ServicePricingTier> pricing;
  final List<ServiceFaq> faqs;
  final List<ServiceReview> reviews;
  final BilingualText ctaTitle;
  final BilingualText ctaSub;
}

class ServiceIncluded {
  const ServiceIncluded({
    required this.title,
    required this.desc,
  });

  final BilingualText title;
  final BilingualText desc;
}

class ServicePricingTier {
  const ServicePricingTier({
    required this.tier,
    required this.price,
    required this.jobs,
    this.featured = false,
  });

  final BilingualText tier;
  final BilingualText price;
  final BilingualText jobs;
  final bool featured;
}

class ServiceFaq {
  const ServiceFaq({required this.question, required this.answer});

  final BilingualText question;
  final BilingualText answer;
}

class ServiceReview {
  const ServiceReview({
    required this.initials,
    required this.name,
    required this.quote,
    required this.stars,
  });

  final String initials;
  final BilingualText name;
  final BilingualText quote;
  final int stars;
}
