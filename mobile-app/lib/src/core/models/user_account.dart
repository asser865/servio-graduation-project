enum UserRole { customer, technician }

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.day,
    required this.from,
    required this.to,
  });

  final String day;
  final String from;
  final String to;

  Map<String, dynamic> toJson() => {
        'day': day,
        'from': from,
        'to': to,
      };

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlot(
        day: (json['day'] as String?) ?? '',
        from: (json['from'] as String?) ?? '',
        to: (json['to'] as String?) ?? '',
      );
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.city = 'Cairo',
    this.avatarInitials = '',
    this.status = 'active',
    this.bio = '',
    this.hourlyRate = 0.0,
    this.skills = const [],
    this.locationLabel = '',
    this.yearsExperience = 0,
    this.availabilityType = '',
    this.isAvailable = false,
    this.availability = const <AvailabilitySlot>[],
    this.blockedDates = const <String>[],
    this.categories = const [],
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.completedJobs = 0,
    this.createdAt,
    this.idFrontUrl = '',
    this.idFrontName = '',
    this.idBackUrl = '',
    this.idBackName = '',
    this.idSelfieUrl = '',
    this.idSelfieName = '',
    this.cvUrl = '',
    this.cvName = '',
    this.portfolioFiles = const <Map<String, String>>[],
    this.verificationRejectionReason = '',
    this.verificationSubmittedAt,
    this.verificationReviewedAt,
    this.serviceIds = const <String>[],
    this.pendingCategories = const <String>[],
    this.minFee = 0.0,
    this.travelFee = 0.0,
    this.emergencyMultiplier = 1.0,
    this.acceptCash = false,
    this.acceptCard = false,
    this.acceptInstapay = false,
    this.acceptWallet = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String city;
  final String avatarInitials;
  final String status;
  final String bio;
  final double hourlyRate;
  final List<String> skills;
  final String locationLabel;
  final int yearsExperience;
  final String availabilityType;
  final bool isAvailable;
  final List<AvailabilitySlot> availability;
  final List<String> blockedDates;
  final List<String> categories;
  final double averageRating;
  final int reviewCount;
  final bool isVerified;
  final int completedJobs;
  final DateTime? createdAt;
  final String idFrontUrl;
  final String idFrontName;
  final String idBackUrl;
  final String idBackName;
  final String idSelfieUrl;
  final String idSelfieName;
  final String cvUrl;
  final String cvName;
  final List<Map<String, String>> portfolioFiles;
  final String verificationRejectionReason;
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationReviewedAt;
  final List<String> serviceIds;
  final List<String> pendingCategories;
  final double minFee;
  final double travelFee;
  final double emergencyMultiplier;
  final bool acceptCash;
  final bool acceptCard;
  final bool acceptInstapay;
  final bool acceptWallet;

  String get initials {
    if (avatarInitials.isNotEmpty) return avatarInitials;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String get verificationUiStatus {
    if (status == 'approved') return 'approved';
    if (status == 'rejected') {
      if (verificationRejectionReason.toLowerCase().contains('additional')) {
        return 'additional_docs_required';
      }
      return 'rejected';
    }
    final hasAny = idFrontUrl.isNotEmpty ||
        idBackUrl.isNotEmpty ||
        idSelfieUrl.isNotEmpty ||
        cvUrl.isNotEmpty ||
        portfolioFiles.isNotEmpty;
    if (!hasAny) return 'not_submitted';
    final hasAllRequired = idFrontUrl.isNotEmpty &&
        idBackUrl.isNotEmpty &&
        idSelfieUrl.isNotEmpty;
    return hasAllRequired ? 'under_review' : 'pending_review';
  }

  UserAccount copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? city,
    String? avatarInitials,
    String? status,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
    String? locationLabel,
    int? yearsExperience,
    String? availabilityType,
    bool? isAvailable,
    List<AvailabilitySlot>? availability,
    List<String>? blockedDates,
    List<String>? categories,
    double? averageRating,
    int? reviewCount,
    bool? isVerified,
    int? completedJobs,
    DateTime? createdAt,
    String? idFrontUrl,
    String? idFrontName,
    String? idBackUrl,
    String? idBackName,
    String? idSelfieUrl,
    String? idSelfieName,
    String? cvUrl,
    String? cvName,
    List<Map<String, String>>? portfolioFiles,
    String? verificationRejectionReason,
    DateTime? verificationSubmittedAt,
    DateTime? verificationReviewedAt,
    List<String>? serviceIds,
    List<String>? pendingCategories,
    double? minFee,
    double? travelFee,
    double? emergencyMultiplier,
    bool? acceptCash,
    bool? acceptCard,
    bool? acceptInstapay,
    bool? acceptWallet,
  }) =>
      UserAccount(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        city: city ?? this.city,
        avatarInitials: avatarInitials ?? this.avatarInitials,
        status: status ?? this.status,
        bio: bio ?? this.bio,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        skills: skills ?? this.skills,
        locationLabel: locationLabel ?? this.locationLabel,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        availabilityType: availabilityType ?? this.availabilityType,
        isAvailable: isAvailable ?? this.isAvailable,
        availability: availability ?? this.availability,
        blockedDates: blockedDates ?? this.blockedDates,
        categories: categories ?? this.categories,
        averageRating: averageRating ?? this.averageRating,
        reviewCount: reviewCount ?? this.reviewCount,
        isVerified: isVerified ?? this.isVerified,
        completedJobs: completedJobs ?? this.completedJobs,
        createdAt: createdAt ?? this.createdAt,
        idFrontUrl: idFrontUrl ?? this.idFrontUrl,
        idFrontName: idFrontName ?? this.idFrontName,
        idBackUrl: idBackUrl ?? this.idBackUrl,
        idBackName: idBackName ?? this.idBackName,
        idSelfieUrl: idSelfieUrl ?? this.idSelfieUrl,
        idSelfieName: idSelfieName ?? this.idSelfieName,
        cvUrl: cvUrl ?? this.cvUrl,
        cvName: cvName ?? this.cvName,
        portfolioFiles: portfolioFiles ?? this.portfolioFiles,
        verificationRejectionReason: verificationRejectionReason ?? this.verificationRejectionReason,
        verificationSubmittedAt: verificationSubmittedAt ?? this.verificationSubmittedAt,
        verificationReviewedAt: verificationReviewedAt ?? this.verificationReviewedAt,
        serviceIds: serviceIds ?? this.serviceIds,
        pendingCategories: pendingCategories ?? this.pendingCategories,
        minFee: minFee ?? this.minFee,
        travelFee: travelFee ?? this.travelFee,
        emergencyMultiplier: emergencyMultiplier ?? this.emergencyMultiplier,
        acceptCash: acceptCash ?? this.acceptCash,
        acceptCard: acceptCard ?? this.acceptCard,
        acceptInstapay: acceptInstapay ?? this.acceptInstapay,
        acceptWallet: acceptWallet ?? this.acceptWallet,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'city': city,
        'avatarInitials': avatarInitials,
        'status': status,
        'bio': bio,
        'hourlyRate': hourlyRate,
        'skills': skills,
        'locationLabel': locationLabel,
        'yearsExperience': yearsExperience,
        'availabilityType': availabilityType,
        'isAvailable': isAvailable,
        'availability': availability.map((slot) => slot.toJson()).toList(),
        'blockedDates': blockedDates,
        'categories': categories,
        'averageRating': averageRating,
        'reviewCount': reviewCount,
        'isVerified': isVerified,
        'completedJobs': completedJobs,
        'createdAt': createdAt?.toIso8601String(),
        'idFrontUrl': idFrontUrl,
        'idFrontName': idFrontName,
        'idBackUrl': idBackUrl,
        'idBackName': idBackName,
        'idSelfieUrl': idSelfieUrl,
        'idSelfieName': idSelfieName,
        'cvUrl': cvUrl,
        'cvName': cvName,
        'portfolioFiles': portfolioFiles,
        'verificationRejectionReason': verificationRejectionReason,
        'verificationSubmittedAt': verificationSubmittedAt?.toIso8601String(),
        'verificationReviewedAt': verificationReviewedAt?.toIso8601String(),
        'services': serviceIds,
        'pendingCategories': pendingCategories,
        'minFee': minFee,
        'travelFee': travelFee,
        'emergencyMultiplier': emergencyMultiplier,
        'acceptCash': acceptCash,
        'acceptCard': acceptCard,
        'acceptInstapay': acceptInstapay,
        'acceptWallet': acceptWallet,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.customer,
        ),
        city: (json['city'] as String?) ?? 'Cairo',
        avatarInitials: (json['avatarInitials'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'active',
        bio: (json['bio'] as String?) ?? '',
        hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toDouble(),
        skills: List<String>.from((json['skills'] as List<dynamic>?) ?? []),
        locationLabel: (json['locationLabel'] as String?) ?? '',
        yearsExperience: ((json['yearsExperience'] as num?) ?? 0).toInt(),
        availabilityType: (json['availabilityType'] as String?) ?? '',
        isAvailable: (json['isAvailable'] as bool?) ?? false,
        availability: _availabilityFromJson(json['availability']),
        blockedDates:
            List<String>.from((json['blockedDates'] as List<dynamic>?) ?? []),
        categories:
            List<String>.from((json['categories'] as List<dynamic>?) ?? []),
        averageRating: ((json['averageRating'] as num?) ?? 0.0).toDouble(),
        reviewCount: ((json['reviewCount'] as num?) ?? 0).toInt(),
        isVerified: (json['isVerified'] as bool?) ?? false,
        completedJobs: ((json['completedJobs'] as num?) ?? 0).toInt(),
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
        idFrontUrl: (json['idFrontUrl'] as String?) ?? '',
        idFrontName: (json['idFrontName'] as String?) ?? '',
        idBackUrl: (json['idBackUrl'] as String?) ?? '',
        idBackName: (json['idBackName'] as String?) ?? '',
        idSelfieUrl: (json['idSelfieUrl'] as String?) ?? '',
        idSelfieName: (json['idSelfieName'] as String?) ?? '',
        cvUrl: (json['cvUrl'] as String?) ?? '',
        cvName: (json['cvName'] as String?) ?? '',
        portfolioFiles: _portfolioFromJson(json['portfolioFiles']),
        verificationRejectionReason: (json['verificationRejectionReason'] as String?) ?? '',
        verificationSubmittedAt: DateTime.tryParse((json['verificationSubmittedAt'] as String?) ?? ''),
        verificationReviewedAt: DateTime.tryParse((json['verificationReviewedAt'] as String?) ?? ''),
      );

  // Maps backend API response (uses _id, role: 'user'|'worker', nested address)
  factory UserAccount.fromBackend(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    final rawRole = (json['role'] as String?) ?? 'user';
    return UserAccount(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      role: rawRole == 'worker' ? UserRole.technician : UserRole.customer,
      city: (address?['city'] as String?) ?? 'Cairo',
      status: (json['verificationStatus'] as String?) ??
          (json['status'] as String?) ??
          'active',
      bio: (json['bio'] as String?) ?? '',
      hourlyRate: ((json['hourlyRate'] as num?) ?? 0).toDouble(),
      skills: List<String>.from((json['skills'] as List<dynamic>?) ?? []),
      locationLabel: (json['locationLabel'] as String?) ?? '',
      yearsExperience: ((json['yearsExperience'] as num?) ?? 0).toInt(),
      availabilityType: (json['availabilityType'] as String?) ?? '',
      isAvailable: (json['isAvailable'] as bool?) ?? false,
      availability: _availabilityFromJson(json['availability']),
      blockedDates:
          List<String>.from((json['blockedDates'] as List<dynamic>?) ?? []),
      categories:
          List<String>.from((json['categories'] as List<dynamic>?) ?? []),
      averageRating: ((json['averageRating'] as num?) ?? 0.0).toDouble(),
      reviewCount: ((json['reviewCount'] as num?) ?? 0).toInt(),
      isVerified: (json['isVerified'] as bool?) ?? false,
      completedJobs: ((json['completedJobs'] as num?) ?? 0).toInt(),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
      idFrontUrl: (json['idFrontUrl'] as String?) ?? '',
      idFrontName: (json['idFrontName'] as String?) ?? '',
      idBackUrl: (json['idBackUrl'] as String?) ?? '',
      idBackName: (json['idBackName'] as String?) ?? '',
      idSelfieUrl: (json['idSelfieUrl'] as String?) ?? '',
      idSelfieName: (json['idSelfieName'] as String?) ?? '',
      cvUrl: (json['cvUrl'] as String?) ?? '',
      cvName: (json['cvName'] as String?) ?? '',
      portfolioFiles: _portfolioFromJson(json['portfolioFiles']),
      verificationRejectionReason:
          (json['verificationRejectionReason'] as String?) ?? '',
      verificationSubmittedAt: DateTime.tryParse(
          (json['verificationSubmittedAt'] as String?) ?? ''),
      verificationReviewedAt: DateTime.tryParse(
          (json['verificationReviewedAt'] as String?) ?? ''),
      // services may be populated objects {_id, title} OR plain ID strings
      serviceIds: _stringListFromJson(json['services']),
      // pendingCategories is always a plain string array in the backend schema
      pendingCategories: List<String>.from(
          (json['pendingCategories'] as List<dynamic>?) ?? []),
      minFee: ((json['minFee'] as num?) ?? 0).toDouble(),
      travelFee: ((json['travelFee'] as num?) ?? 0).toDouble(),
      emergencyMultiplier:
          ((json['emergencyMultiplier'] as num?) ?? 1.0).toDouble(),
      acceptCash: (json['acceptCash'] as bool?) ?? false,
      acceptCard: (json['acceptCard'] as bool?) ?? false,
      acceptInstapay: (json['acceptInstapay'] as bool?) ?? false,
      acceptWallet: (json['acceptWallet'] as bool?) ?? false,
    );
  }
}

List<AvailabilitySlot> _availabilityFromJson(dynamic value) {
  if (value is! List<dynamic>) return const <AvailabilitySlot>[];
  return value
      .whereType<Map<String, dynamic>>()
      .map(AvailabilitySlot.fromJson)
      .where((slot) => slot.day.isNotEmpty)
      .toList();
}

List<Map<String, String>> _portfolioFromJson(dynamic value) {
  if (value is! List<dynamic>) return const <Map<String, String>>[];
  return value.whereType<Map<String, dynamic>>().map((m) {
    return <String, String>{
      'url': (m['url'] as String?) ?? '',
      'name': (m['name'] as String?) ?? '',
    };
  }).toList();
}

List<String> _stringListFromJson(dynamic value) {
  if (value is! List<dynamic>) return const <String>[];
  return value
      .map((e) => e is Map ? (e['_id'] as String?) ?? '' : (e as String?) ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}
