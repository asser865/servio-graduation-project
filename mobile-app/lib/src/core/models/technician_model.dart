import 'bilingual_text.dart';

class TechnicianModel {
  const TechnicianModel({
    required this.id,
    required this.name,
    required this.title,
    required this.bio,
    required this.specialty,
    required this.rating,
    required this.reviewCount,
    required this.pricePerHour,
    required this.yearsExp,
    required this.responseTime,
    required this.jobSuccess,
    required this.area,
    required this.verified,
    required this.distance,
    required this.availability,
    required this.services,
    this.avatarInitials = '',
  });

  final String id;
  final BilingualText name;
  final BilingualText title;
  final BilingualText bio;
  final String specialty; // matches service id
  final double rating;
  final int reviewCount;
  final int pricePerHour; // EGP
  final int yearsExp;
  final String responseTime;
  final int jobSuccess; // percentage
  final BilingualText area;
  final bool verified;
  final String distance;
  final BilingualText availability;
  final List<TechnicianService> services;
  final String avatarInitials;
}

class TechnicianService {
  const TechnicianService({
    required this.name,
    required this.price,
    required this.duration,
  });

  final BilingualText name;
  final BilingualText price;
  final BilingualText duration;
}
