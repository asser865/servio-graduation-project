enum UserRole { customer, technician }

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
    this.categories = const [],
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
  final List<String> categories;

  String get initials {
    if (avatarInitials.isNotEmpty) return avatarInitials;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
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
    List<String>? categories,
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
        categories: categories ?? this.categories,
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
        'categories': categories,
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
        categories:
            List<String>.from((json['categories'] as List<dynamic>?) ?? []),
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
      categories:
          List<String>.from((json['categories'] as List<dynamic>?) ?? []),
    );
  }
}
